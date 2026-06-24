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
import MapShaderTypes
import MetalKit
import simd
import Triangulation

/// Draws the globe: a base ocean sphere, then each country's fill and border in document order, back to
/// front. Hemisphere occlusion is back-face culling, so no depth buffer is needed, and the draw order keeps
/// neighbouring borders from doubling up where they overlap. MSAA for antialiasing.
final class GlobeRenderer: NSObject, MTKViewDelegate {
    /// Camera matrix and border width, set by the view each frame.
    var uniforms = MapUniforms(mvp: matrix_identity_float4x4, borderHalfWidth: 0)
    /// Direction the camera faces in model space, for culling whole back-hemisphere paths.
    var cameraTarget = SIMD3<Float>(0, 0, 1)
    var highlight = MapHighlight.none

    /// City-point positions (unit-sphere directions). The instance buffer is rebuilt only when they change.
    var pinPositions: [SIMD3<Float>] = [] {
        didSet {
            guard pinPositions != oldValue else { return }
            pinBuffer = Self.buffer(commandQueue.device, pinPositions)
            pinCount = pinPositions.count
        }
    }

    /// Overall opacity of the city points, following the open/close dissolve and dropping to 0 once the
    /// settled clusters take over. At 0 the pass is skipped.
    var pinFade: Float = 0
    /// Fill color of the city points.
    var pinColor = SIMD4<Float>(0.5, 0.5, 0.5, 1)
    /// Camera distance from the globe centre. Drives the points' horizon cull and the whole-path
    /// back-hemisphere cull, whose visible rim widens as the camera pulls out.
    var cameraDistance: Float = 2

    /// Starfield instances: direction plus per-star radius and brightness. The buffer is rebuilt only when
    /// they change.
    var starInstances: [StarInstance] = [] {
        didSet {
            guard starInstances != oldValue else { return }
            starBuffer = Self.buffer(commandQueue.device, starInstances)
            starCount = starInstances.count
        }
    }

    /// Overall star opacity: the open/close dissolve times the zoom-out ramp. At 0 the starfield pass is
    /// skipped.
    var starFade: Float = 0

    private enum Constants {
        /// The largest angular radius any single baked path can have. Russia's mainland is the biggest at
        /// about 30 degrees, and 45 adds slack. The whole-path cull hides a path only when its centroid is
        /// more than the visible-rim angle plus this margin from the camera direction, so it can never cull
        /// a path whose nearest edge could still peek past the limb, at any camera distance.
        static let maxPathCapAngle: Float = .pi / 4
        /// Land triangles and the base sphere are both wound counter-clockwise seen from outside, so a
        /// single back-cull setting hides the far hemisphere of both.
        static let frontFacing: MTLWinding = .counterClockwise
        static let cullMode: MTLCullMode = .back
        /// Base ocean sphere tessellation: latitude bands and longitude segments.
        static let baseSphereStacks = 48
        static let baseSphereSlices = 96
        /// Fades at or below this skip their pass entirely.
        static let minVisibleFade: Float = 0.001
        /// How strongly the sunlight color tints the land and the sea. The continents carry the connection
        /// color while the ocean stays close to neutral. Concentrating the tint on the landmasses keeps the
        /// large sea areas from washing the whole view in color.
        static let landTintStrength: Float = 0.16
        static let seaTintStrength: Float = 0.04
        /// The Moon's albedo, a light cool grey. The fragment shader lights it into phases.
        static let moonColor = SIMD4<Float>(0.80, 0.80, 0.84, 1)
    }

    private enum Dimensions {
        /// Fill diameter of the in-motion city dots, in points, scaled to pixels per draw. Smaller than the
        /// settled discs they crossfade into, so the moving field reads lighter. The size step happens
        /// inside the settle dissolve.
        static let pinDiameterPoints: Float = 7
        /// Sun-glow radius in points, scaled to pixels per draw.
        static let sunRadiusPoints: Float = 46
        #if DEBUG
            /// Metal's guaranteed maximum 2D texture dimension. The offscreen render is clamped to it so an
            /// over-large layout proposal degrades to a low-res image rather than trapping in texture
            /// validation.
            static let maxTextureDimension = 8192
        #endif
    }

    private let model: MapGlobeModel
    /// Color of the base ocean sphere. A `var` set through `MapGlobeView.apply(to:)`, so a changed value
    /// takes effect on the next frame instead of being silently ignored for the life of the view.
    var oceanColor: SIMD4<Float>
    private let commandQueue: MTLCommandQueue
    private let fillPipeline: MTLRenderPipelineState
    private let borderPipeline: MTLRenderPipelineState
    private let moonPipeline: MTLRenderPipelineState
    private let pinPipeline: MTLRenderPipelineState
    private let starPipeline: MTLRenderPipelineState
    private let sunPipeline: MTLRenderPipelineState

    /// City-point and starfield instance buffers, rebuilt on change, and their counts. `viewportSizePixels`
    /// and `contentScale` are refreshed each live frame from the drawable, for constant-pixel dot sizing.
    private var pinBuffer: MTLBuffer?
    private var pinCount = 0
    private var starBuffer: MTLBuffer?
    private var starCount = 0
    private var viewportSizePixels = SIMD2<Float>(0, 0)
    private var contentScale: Float = 1
    private var pinDiameterPixels: Float = 0

    private let fillVertexBuffer: MTLBuffer
    private let fillIndexBuffer: MTLBuffer
    private let borderSegmentBuffer: MTLBuffer?
    private let baseVertexBuffer: MTLBuffer
    private let baseIndexBuffer: MTLBuffer
    private let baseIndexCount: Int
    #if DEBUG
        /// Color format and MSAA count the pipelines were built with, so the DEBUG-only offscreen render
        /// path can build matching textures.
        private let colorFormat: MTLPixelFormat
        private let sampleCount: Int
    #endif

    init?(device: MTLDevice, model: MapGlobeModel, oceanColor: SIMD4<Float>, colorFormat: MTLPixelFormat, sampleCount: Int) {
        guard let commandQueue = device.makeCommandQueue(),
              let library = try? device.makeDefaultLibrary(bundle: .module),
              let fillVertexBuffer = Self.buffer(device, model.fillVertices),
              let fillIndexBuffer = Self.buffer(device, model.fillIndices)
        else {
            log.error("Globe renderer setup failed: no command queue, shader library, or fill buffers")
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
            do {
                return try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                log.error("Globe renderer setup failed: \(vertex)/\(fragment) pipeline: \(error)")
                return nil
            }
        }

        guard let fillPipeline = pipeline(vertex: "vertex_globe_fill", fragment: "fragment_solid"),
              let borderPipeline = pipeline(vertex: "vertex_globe_border", fragment: "fragment_globe_border"),
              let moonPipeline = pipeline(vertex: "vertex_globe_fill", fragment: "fragment_moon"),
              let pinPipeline = pipeline(vertex: "vertex_pin", fragment: "fragment_pin"),
              let starPipeline = pipeline(vertex: "vertex_star", fragment: "fragment_star"),
              let sunPipeline = pipeline(vertex: "vertex_sun", fragment: "fragment_sun")
        else {
            return nil
        }

        let base = UVSphere.mesh(stacks: Constants.baseSphereStacks, slices: Constants.baseSphereSlices)
        guard let baseVertexBuffer = Self.buffer(device, base.vertices),
              let baseIndexBuffer = Self.buffer(device, base.indices)
        else {
            log.error("Globe renderer setup failed: could not allocate the base sphere buffers")
            return nil
        }

        self.model = model
        self.oceanColor = oceanColor
        self.commandQueue = commandQueue
        self.fillPipeline = fillPipeline
        self.borderPipeline = borderPipeline
        self.moonPipeline = moonPipeline
        self.pinPipeline = pinPipeline
        self.starPipeline = starPipeline
        self.sunPipeline = sunPipeline
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
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }
        // Points/stars size to a constant on-screen diameter, so derive pixels from the live drawable scale.
        let scale = Float(view.drawableSize.width / max(view.bounds.width, 1))
        viewportSizePixels = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        contentScale = scale
        pinDiameterPixels = Dimensions.pinDiameterPoints * scale

        encode(into: descriptor, commandBuffer: commandBuffer)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Main render loop

    /// Encodes the whole globe, base ocean sphere then each country's fill and border in draw order, into
    /// one render pass. Shared by the live `MTKView` path and the offscreen `makeImage` path. The caller
    /// owns the pass descriptor's attachments and the command buffer's present and commit.
    private func encode(into descriptor: MTLRenderPassDescriptor, commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setFrontFacing(Constants.frontFacing)
        encoder.setCullMode(Constants.cullMode)

        // The uniform block the fill and border passes bind. Patched per draw below (tint strength,
        // border width) and passed inout so each draw reuses it without copying. The billboard passes read
        // the renderer's own state instead.
        var uniforms = uniforms

        // With no depth buffer, everything is drawn farthest first. Stars first of all, out at the
        // celestial radius, so the Moon and the opaque Earth drawn after cover the ones behind them.
        drawStars(into: encoder)

        // The sun glow next: in front of the stars, still behind the Moon and Earth, so the opaque sphere
        // occludes it and it shows only once it has swung past the limb to the night side.
        drawSun(into: encoder)

        // The Moon next, so the opaque Earth drawn after occludes it wherever they overlap. The Moon is
        // always farther than the Earth's near surface, so draw order alone gives correct occlusion.
        drawMoon(into: encoder)

        // Base ocean sphere, so the globe reads as solid. The back hemisphere is culled away. The sea
        // barely takes the sunlight tint, staying near neutral.
        uniforms.tintStrength = Constants.seaTintStrength
        drawFill(
            vertices: baseVertexBuffer,
            indices: baseIndexBuffer,
            range: 0 ..< baseIndexCount,
            color: oceanColor,
            uniforms: &uniforms,
            into: encoder
        )

        // Countries in document order: fill then border. Whole back-hemisphere paths are skipped up front,
        // saving the GPU from back-face culling their triangles one by one. The land carries the connection
        // color.
        uniforms.tintStrength = Constants.landTintStrength
        let cullDot = pathCullDot
        for unit in model.drawOrder {
            if simd_dot(unit.centroid, cameraTarget) < cullDot { continue } // provably behind the visible rim

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
                uniforms.borderHalfWidth = unit.borderHalfWidth
                drawBorder(
                    range: unit.borderRange,
                    color: model.borderColor,
                    uniforms: &uniforms,
                    segments: borderSegmentBuffer,
                    into: encoder
                )
            }
        }

        // City points last, so they sit on top of the globe.
        drawPoints(into: encoder)

        encoder.endEncoding()
    }

    // MARK: - Passes

    /// Draws the Moon: the base sphere translated to `moonCenter` and scaled to `moonRadius` in Earth
    /// radii, lit into phases by the Sun and faded by `lightFade`. The model offset is folded into the MVP,
    /// while the fragment keeps `moonCenter` and `moonRadius` to reconstruct each pixel's world position
    /// for the lunar eclipse. Skipped when there is no Moon (radius 0) or the map is closed.
    private func drawMoon(into encoder: MTLRenderCommandEncoder) {
        guard uniforms.moonRadius > 0, uniforms.lightFade > Constants.minVisibleFade else { return }
        var moonUniforms = uniforms
        let model = simd_float4x4.placing(at: uniforms.moonCenter, radius: uniforms.moonRadius)
        moonUniforms.mvp = uniforms.mvp * model
        var color = Constants.moonColor
        encoder.setRenderPipelineState(moonPipeline)
        encoder.setVertexBuffer(baseVertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&moonUniforms, length: MemoryLayout<MapUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setFragmentBytes(&moonUniforms, length: MemoryLayout<MapUniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: baseIndexCount,
            indexType: .uint32,
            indexBuffer: baseIndexBuffer,
            indexBufferOffset: 0
        )
    }

    /// Draws a sub-range of an indexed triangle mesh in a solid color. The base ocean sphere passes its
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
        color: SIMD4<Float>,
        uniforms: inout MapUniforms,
        segments segmentBuffer: MTLBuffer,
        into encoder: MTLRenderCommandEncoder
    ) {
        var color = color
        encoder.setRenderPipelineState(borderPipeline)
        encoder.setVertexBuffer(segmentBuffer, offset: range.lowerBound * MemoryLayout<MapGlobeSegment>.stride, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<MapUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MapUniforms>.stride, index: 1) // sun/lighting
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: range.count)
    }

    /// Draws the city points as instanced screen-facing billboards in the globe's own pass, so they track
    /// the sphere exactly. Constant pixel size, horizon-culled in the vertex shader. Skipped when faded
    /// out, empty, or before the drawable size is known.
    private func drawPoints(into encoder: MTLRenderCommandEncoder) {
        guard pinFade > Constants.minVisibleFade, pinCount > 0, let pinBuffer, viewportSizePixels.x > 0 else { return }
        var u = PinUniforms(
            mvp: uniforms.mvp,
            cameraTarget: cameraTarget,
            horizonCosThreshold: HorizonCap(facing: cameraTarget, distance: cameraDistance).cosThreshold,
            viewportSize: viewportSizePixels,
            diameter: pinDiameterPixels,
            fade: pinFade,
            fillColor: pinColor
        )
        encoder.setCullMode(.none) // billboards face the camera; horizon visibility is handled in the shader
        encoder.setRenderPipelineState(pinPipeline)
        encoder.setVertexBuffer(pinBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&u, length: MemoryLayout<PinUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&u, length: MemoryLayout<PinUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: pinCount)
        encoder.setCullMode(Constants.cullMode) // restore, like the other billboard passes, so a pass added after can't inherit .none
    }

    /// Draws the starfield as instanced screen-facing billboards far out at the celestial radius, projected
    /// by the same MVP so the field turns with the camera. Called first, so the Moon and globe drawn later
    /// cover the stars behind them. Skipped when faded out or empty.
    private func drawStars(into encoder: MTLRenderCommandEncoder) {
        guard starFade > Constants.minVisibleFade, starCount > 0, let starBuffer, viewportSizePixels.x > 0 else { return }
        var u = StarUniforms(mvp: uniforms.mvp, viewportSize: viewportSizePixels, scale: contentScale, fade: starFade)
        encoder.setCullMode(.none) // screen-facing billboards
        encoder.setRenderPipelineState(starPipeline)
        encoder.setVertexBuffer(starBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&u, length: MemoryLayout<StarUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: starCount)
        encoder.setCullMode(Constants.cullMode) // restore back-culling for the Moon and globe passes that follow
    }

    /// Draws the sun as a single soft-glow billboard at the sub-solar direction, taking its color from the
    /// globe uniforms, far out so it turns with the camera. Drawn between the stars and the Moon so the
    /// opaque sphere occludes it. Fades with `lightFade`, like the rest of the lighting, and is skipped
    /// while the map is unlit.
    private func drawSun(into encoder: MTLRenderCommandEncoder) {
        guard uniforms.lightFade > Constants.minVisibleFade, viewportSizePixels.x > 0 else { return }
        var u = SunUniforms(
            mvp: uniforms.mvp,
            sunDirection: uniforms.sunDirection,
            viewportSize: viewportSizePixels,
            radiusPixels: Dimensions.sunRadiusPoints * contentScale,
            fade: uniforms.lightFade,
            color: uniforms.sunTint
        )
        encoder.setCullMode(.none) // screen-facing billboard
        encoder.setRenderPipelineState(sunPipeline)
        encoder.setVertexBytes(&u, length: MemoryLayout<SunUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&u, length: MemoryLayout<SunUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.setCullMode(Constants.cullMode) // restore back-culling for the Moon and globe passes that follow
    }

    /// Centroid-dot threshold for skipping whole back-hemisphere paths. The visible rim sits
    /// `acos(1/distance)` from the camera direction and widens as the camera pulls out, so the cutoff
    /// follows the distance rather than being fixed. A path can reach past the rim by at most its own
    /// angular radius, so anything beyond the rim plus `maxPathCapAngle` is provably invisible.
    private var pathCullDot: Float {
        let rim = acos(1 / max(cameraDistance, 1.001))
        return cos(min(rim + Constants.maxPathCapAngle, .pi))
    }

    private func contained(_ range: Range<Int>, in ranges: [Range<Int>]) -> Bool {
        ranges.contains { $0.lowerBound <= range.lowerBound && range.upperBound <= $0.upperBound }
    }

    // `BitwiseCopyable` so a non-trivial element type (anything holding a reference) is a compile error
    // rather than a blitted dangling pointer.
    private static func buffer(_ device: MTLDevice, _ array: [some BitwiseCopyable]) -> MTLBuffer? {
        array.withUnsafeBytes { raw in
            guard let base = raw.baseAddress, !raw.isEmpty else { return nil }
            return device.makeBuffer(bytes: base, length: raw.count, options: .storageModeShared)
        }
    }

    // MARK: - Debug + UI test support

    #if DEBUG
        /// Renders the current renderer state synchronously to an off-screen `CGImage` of `size * scale`
        /// pixels. This is the snapshot-test path: a live `CAMetalLayer` can't be captured by
        /// `layer.render(in:)`, so tests render the globe to a bounded texture and read it back. Blocks on
        /// `waitUntilCompleted`, so the pixels are ready on return.
        func makeImage(size: CGSize, scale: CGFloat) -> CGImage? {
            let rawWidth = max(size.width, 0) * scale
            let rawHeight = max(size.height, 0) * scale
            let fit = min(1, CGFloat(Dimensions.maxTextureDimension) / max(rawWidth, rawHeight, 1)) // keep aspect
            let width = Int((rawWidth * fit).rounded())
            let height = Int((rawHeight * fit).rounded())
            guard width > 0, height > 0 else { return nil }

            // Points and stars, when a test sets them, size to the offscreen texture as they do to the
            // live drawable.
            viewportSizePixels = SIMD2<Float>(Float(width), Float(height))
            contentScale = Float(scale)
            pinDiameterPixels = Dimensions.pinDiameterPoints * Float(scale)

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
            color.clearColor = GlobeSurface.clearColor
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
}

#if DEBUG
    extension GlobeRenderer {
        /// Reads a `.shared` BGRA texture back into a premultiplied `CGImage` (the fragment shader already
        /// outputs premultiplied color).
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
    }
#endif
