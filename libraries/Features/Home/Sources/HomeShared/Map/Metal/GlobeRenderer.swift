//
//  Created on 20/06/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import CoreGraphics
import Foundation
import MapModel
import MetalKit
import simd

/// Draws the globe: a base ocean sphere, then each country's fill and border in document (painter)
/// order. Hemisphere occlusion is back-face culling (no depth buffer needed); painter order keeps the
/// offset neighbour borders from doubling, exactly as on the flat map. MSAA for antialiasing.
final class GlobeRenderer: NSObject, MTKViewDelegate {
    /// Camera matrix + border width, set by the view each frame.
    var uniforms = MapUniforms(mvp: matrix_identity_float4x4, borderHalfWidth: 0)
    /// Direction the camera faces (model space) — for culling whole back-hemisphere paths.
    var cameraTarget = SIMD3<Float>(0, 0, 1)
    var highlight = MapHighlight.none

    /// A whole path is skipped when its centroid is at least this far behind the camera direction
    /// (`dot < this`); its triangles would be back-face-culled anyway. Slightly past the silhouette so
    /// paths straddling the limb still draw.
    private static let backHemisphereCullDot: Float = -0.35
    /// Land triangles and the base sphere are wound CCW-from-outside (enforced in the baker and
    /// `makeBaseSphere`), so a single back-cull pass hides the far hemisphere of both.
    private static let frontFacing: MTLWinding = .counterClockwise
    private static let cullMode: MTLCullMode = .back
    /// Base ocean sphere tessellation (latitude bands × longitude segments).
    private static let baseSphereStacks = 48
    private static let baseSphereSlices = 96
    /// Transparent clear — the globe composites over whatever is behind it (the app background).
    private static let clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    /// How strongly the sunlight colour tints the land vs the sea. The continents carry the connection
    /// colour while the ocean stays close to neutral-dark — concentrating the tint on the landmasses keeps
    /// the large sea areas from washing the whole view in colour.
    private static let landTintStrength: Float = 0.16
    private static let seaTintStrength: Float = 0.04
    #if DEBUG
        /// Metal's guaranteed max 2-D texture dimension; the offscreen render is clamped to it so an
        /// over-large layout proposal degrades to a low-res image rather than trapping in texture validation.
        private static let maxTextureDimension = 8192
    #endif

    private let model: MapGlobeModel
    private let oceanColor: SIMD4<Float>
    private let commandQueue: MTLCommandQueue
    private let fillPipeline: MTLRenderPipelineState
    private let borderPipeline: MTLRenderPipelineState

    private let fillVertexBuffer: MTLBuffer
    private let fillIndexBuffer: MTLBuffer
    private let borderSegmentBuffer: MTLBuffer?
    private let baseVertexBuffer: MTLBuffer
    private let baseIndexBuffer: MTLBuffer
    private let baseIndexCount: Int
    #if DEBUG
        /// Colour format + MSAA count the pipelines were built with — the DEBUG-only offscreen render path
        /// builds matching textures (`makeImage`).
        private let colorFormat: MTLPixelFormat
        private let sampleCount: Int
    #endif

    init?(device: MTLDevice, model: MapGlobeModel, oceanColor: SIMD4<Float>, colorFormat: MTLPixelFormat, sampleCount: Int) {
        guard
            let commandQueue = device.makeCommandQueue(),
            let library = try? device.makeDefaultLibrary(bundle: .module),
            let fillVertexBuffer = Self.buffer(device, model.fillVertices),
            let fillIndexBuffer = Self.buffer(device, model.fillIndices)
        else {
            return nil
        }

        func pipeline(vertex: String, fragment: String) -> MTLRenderPipelineState? {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            descriptor.rasterSampleCount = sampleCount
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = colorFormat
            color.isBlendingEnabled = true
            color.rgbBlendOperation = .add
            color.alphaBlendOperation = .add
            color.sourceRGBBlendFactor = .one // premultiplied
            color.sourceAlphaBlendFactor = .one
            color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        guard
            let fillPipeline = pipeline(vertex: "vertex_globe_fill", fragment: "fragment_solid"),
            let borderPipeline = pipeline(vertex: "vertex_globe_border", fragment: "fragment_solid")
        else {
            return nil
        }

        let base = Self.makeBaseSphere(stacks: Self.baseSphereStacks, slices: Self.baseSphereSlices)
        guard
            let baseVertexBuffer = Self.buffer(device, base.vertices),
            let baseIndexBuffer = Self.buffer(device, base.indices)
        else {
            return nil
        }

        self.model = model
        self.oceanColor = oceanColor
        self.commandQueue = commandQueue
        self.fillPipeline = fillPipeline
        self.borderPipeline = borderPipeline
        self.fillVertexBuffer = fillVertexBuffer
        self.fillIndexBuffer = fillIndexBuffer
        self.borderSegmentBuffer = Self.buffer(device, model.borderSegments)
        self.baseVertexBuffer = baseVertexBuffer
        self.baseIndexBuffer = baseIndexBuffer
        self.baseIndexCount = base.indices.count
        #if DEBUG
            self.colorFormat = colorFormat
            self.sampleCount = sampleCount
        #endif
        super.init()
    }

    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = Self.clearColor
        if view.sampleCount > 1 { descriptor.colorAttachments[0].storeAction = .multisampleResolve }

        encode(into: descriptor, commandBuffer: commandBuffer)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    #if DEBUG
        /// Renders the current `uniforms`/`cameraTarget`/`highlight` synchronously to an off-screen
        /// `CGImage` of `size * scale` pixels. The snapshot-test path: a live `CAMetalLayer` can't be
        /// captured by `layer.render(in:)` (and a `.sizeThatFits` layout asks the on-screen view for a
        /// drawable taller than Metal's 8192 limit, which traps), so tests render the globe to a bounded
        /// texture and read it back. Blocks on `waitUntilCompleted`, so the pixels are ready on return.
        func makeImage(size: CGSize, scale: CGFloat) -> CGImage? {
            let rawWidth = max(size.width, 0) * scale
            let rawHeight = max(size.height, 0) * scale
            let fit = min(1, CGFloat(Self.maxTextureDimension) / max(rawWidth, rawHeight, 1)) // keep aspect
            let width = Int((rawWidth * fit).rounded())
            let height = Int((rawHeight * fit).rounded())
            guard width > 0, height > 0 else { return nil }

            let device = commandQueue.device
            let resolveDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: colorFormat, width: width, height: height, mipmapped: false
            )
            resolveDescriptor.usage = [.renderTarget, .shaderRead]
            resolveDescriptor.storageMode = .shared // CPU-readable for the byte read-back below
            guard let resolveTexture = device.makeTexture(descriptor: resolveDescriptor) else { return nil }

            let descriptor = MTLRenderPassDescriptor()
            let color = descriptor.colorAttachments[0]!
            color.loadAction = .clear
            color.clearColor = Self.clearColor
            if sampleCount > 1 {
                let msaaDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: colorFormat, width: width, height: height, mipmapped: false
                )
                msaaDescriptor.textureType = .type2DMultisample
                msaaDescriptor.sampleCount = sampleCount
                msaaDescriptor.usage = .renderTarget
                msaaDescriptor.storageMode = .private
                guard let msaaTexture = device.makeTexture(descriptor: msaaDescriptor) else { return nil }
                color.texture = msaaTexture
                color.resolveTexture = resolveTexture
                color.storeAction = .multisampleResolve
            } else {
                color.texture = resolveTexture
                color.storeAction = .store
            }

            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
            encode(into: descriptor, commandBuffer: commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            return Self.cgImage(from: resolveTexture)
        }
    #endif

    /// Encodes the whole globe (base ocean sphere, then each country's fill and border in painter order)
    /// into one render pass. Shared by the live `MTKView` path and the offscreen `makeImage` path; the
    /// caller owns the pass descriptor's attachments and the command buffer's present/commit.
    private func encode(into descriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setFrontFacing(Self.frontFacing)
        encoder.setCullMode(Self.cullMode)

        var uniforms = uniforms

        // Base ocean sphere (so the globe reads as solid; the back hemisphere is culled away). The sea barely
        // takes the sunlight tint, staying near neutral-dark.
        uniforms.tintStrength = Self.seaTintStrength
        drawFill(
            vertices: baseVertexBuffer,
            indices: baseIndexBuffer,
            range: 0 ..< baseIndexCount,
            color: oceanColor,
            uniforms: &uniforms,
            into: encoder
        )

        // Countries in document/painter order: fill then border. Whole back-hemisphere paths are
        // skipped up front (the GPU would back-face-cull their triangles anyway). The land carries the
        // connection colour.
        uniforms.tintStrength = Self.landTintStrength
        for unit in model.drawOrder {
            if simd_dot(unit.centroid, cameraTarget) < Self.backHemisphereCullDot { continue } // clearly back-facing path

            if !unit.fillRange.isEmpty {
                let color = contained(unit.fillRange, in: highlight.fillRanges) ? MapStyle.highlightColor : unit.color
                drawFill(
                    vertices: fillVertexBuffer,
                    indices: fillIndexBuffer,
                    range: unit.fillRange,
                    color: color,
                    uniforms: &uniforms,
                    into: encoder
                )
            }
            if !unit.borderRange.isEmpty,
               let borderSegmentBuffer,
               !contained(unit.borderRange, in: highlight.hiddenBorderRanges) {
                drawBorder(
                    range: unit.borderRange,
                    halfWidth: unit.borderHalfWidth,
                    color: model.borderColor,
                    uniforms: &uniforms,
                    segments: borderSegmentBuffer,
                    into: encoder
                )
            }
        }

        encoder.endEncoding()
    }

    #if DEBUG
        /// Reads a `.shared` BGRA texture back into a premultiplied `CGImage` (the fragment shader already
        /// outputs premultiplied colour).
        private static func cgImage(from texture: MTLTexture) -> CGImage? {
            let width = texture.width
            let height = texture.height
            let bytesPerRow = width * 4
            var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
            bytes.withUnsafeMutableBytes { raw in
                texture.getBytes(
                    raw.baseAddress!,
                    bytesPerRow: bytesPerRow,
                    from: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0
                )
            }
            // bgra8Unorm bytes are B,G,R,A; `byteOrder32Little | premultipliedFirst` reads that back as ARGB.
            let bitmapInfo = CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
            guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    #endif

    // MARK: - Passes

    /// Draws a sub-range of an indexed triangle mesh in a solid colour. The base ocean sphere passes its
    /// whole index range; each country passes its slice of the shared fill index buffer.
    private func drawFill(
        vertices: MTLBuffer,
        indices: MTLBuffer,
        range: Range<Int>,
        color: SIMD4<Float>,
        uniforms: inout MapUniforms,
        into encoder: MTLRenderCommandEncoder
    ) {
        var color = color
        encoder.setRenderPipelineState(fillPipeline)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<MapUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MapUniforms>.stride, index: 1) // sun/lighting
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: range.count,
            indexType: .uint32,
            indexBuffer: indices,
            indexBufferOffset: range.lowerBound * MemoryLayout<UInt32>.stride
        )
    }

    private func drawBorder(
        range: Range<Int>,
        halfWidth: Float,
        color: SIMD4<Float>,
        uniforms: inout MapUniforms,
        segments segmentBuffer: MTLBuffer,
        into encoder: MTLRenderCommandEncoder
    ) {
        uniforms.borderHalfWidth = halfWidth
        var color = color
        encoder.setRenderPipelineState(borderPipeline)
        encoder.setVertexBuffer(segmentBuffer, offset: range.lowerBound * MemoryLayout<MapGlobeSegment>.stride, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<MapUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MapUniforms>.stride, index: 1) // sun/lighting
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: range.count)
    }

    private func contained(_ range: Range<Int>, in ranges: [Range<Int>]) -> Bool {
        ranges.contains { $0.lowerBound <= range.lowerBound && range.upperBound <= $0.upperBound }
    }

    // MARK: - Base sphere

    /// A UV sphere with outward-facing (CCW-from-outside) winding, matching the land triangles so one
    /// cull mode covers both.
    private static func makeBaseSphere(stacks: Int, slices: Int) -> (vertices: [SIMD3<Float>], indices: [UInt32]) {
        var vertices: [SIMD3<Float>] = []
        for stack in 0 ... stacks {
            let phi = Float.pi / 2 - Float(stack) / Float(stacks) * Float.pi // +90°…−90°
            let cphi = cos(phi), sphi = sin(phi)
            for slice in 0 ... slices {
                let theta = Float(slice) / Float(slices) * 2 * Float.pi
                vertices.append(SIMD3<Float>(cphi * cos(theta), sphi, cphi * sin(theta)))
            }
        }
        let stride = slices + 1
        var indices: [UInt32] = []
        for stack in 0 ..< stacks {
            for slice in 0 ..< slices {
                let i0 = UInt32(stack * stride + slice)
                let i1 = UInt32(stack * stride + slice + 1)
                let i2 = UInt32((stack + 1) * stride + slice)
                let i3 = UInt32((stack + 1) * stride + slice + 1)
                appendOutward(&indices, i0, i2, i1, vertices)
                appendOutward(&indices, i1, i2, i3, vertices)
            }
        }
        return (vertices, indices)
    }

    /// Appends a triangle, swapping the last two indices if its normal points inward, so winding is
    /// consistently outward (matching the land).
    private static func appendOutward(
        _ indices: inout [UInt32],
        _ a: UInt32,
        _ b: UInt32,
        _ c: UInt32,
        _ verts: [SIMD3<Float>]
    ) {
        let va = verts[Int(a)], vb = verts[Int(b)], vc = verts[Int(c)]
        let normal = simd_cross(vb - va, vc - va)
        if simd_dot(normal, va) >= 0 {
            indices.append(contentsOf: [a, b, c])
        } else {
            indices.append(contentsOf: [a, c, b])
        }
    }

    private static func buffer(_ device: MTLDevice, _ array: [some Any]) -> MTLBuffer? {
        array.withUnsafeBytes { raw in
            guard let base = raw.baseAddress, !raw.isEmpty else { return nil }
            return device.makeBuffer(bytes: base, length: raw.count, options: .storageModeShared)
        }
    }
}
