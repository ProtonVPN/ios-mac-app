//
//  Created on 04/08/2026.
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

import Accelerate
import Foundation

/// How far the drawn map sits from true geography, measured against Natural Earth reference data during the
/// bake and subtracted while unprojecting.
///
/// The world SVG is traced by hand, and its geography lands a few kilometers away from where it belongs, by
/// different amounts in different regions. The correction is a displacement field: how far north and how far
/// east the map is wrong, stored at each node of a spherical grid and interpolated between nodes. The field is
/// fitted to thousands of measured reference-versus-drawn offsets by least squares, with two stabilizers. A
/// smoothness term ties each node to its neighbors, so lightly sampled regions blend with their surroundings
/// instead of inventing corrections, and a faint pull toward zero leaves regions with no data at all (open
/// ocean, the poles) uncorrected. Because the grid is coarse, the field cannot noticeably bend the shape of
/// anything smaller than a few hundred kilometers. Cartographers call this rubber-sheeting. The fit runs fresh
/// on every bake, so swapping the map or the reference data needs no hand tuning.
struct MapCalibration {
    /// The two displacement grids in kilometers, row-major over `Grid.rows x Grid.columns` nodes: how far north
    /// (latitude) and east (longitude) the drawn map sits from truth at each node. Empty when uncalibrated.
    let latitudeErrorKm: [Double]
    let longitudeErrorKm: [Double]

    /// No correction: what `fitted` degrades to when the north-south fit fails.
    static let identity = MapCalibration(latitudeErrorKm: [], longitudeErrorKm: [])

    enum Grid {
        /// Latitude rows run every five degrees from -90 to 90 inclusive; longitude columns run every fifteen
        /// degrees from -180, wrapping. The rows are finer than the columns because the drawn map's error
        /// changes quickly from north to south and slowly from east to west, so the grid spends its nodes
        /// where they resolve real detail.
        static let rowSpacingDegrees = 5.0
        static let columnSpacingDegrees = 15.0
        static let rows = 37
        static let columns = 24
        static let nodeCount = rows * columns
    }

    /// The true coordinate for a drawn one, both in degrees. Longitude wraps back into -180 ..< 180.
    func corrected(latitudeDegrees: Double, longitudeDegrees: Double) -> (latitude: Double, longitude: Double) {
        guard !latitudeErrorKm.isEmpty else { return (latitudeDegrees, longitudeDegrees) }
        let latKm = Self.interpolate(latitudeErrorKm, latitudeDegrees, longitudeDegrees)
        let lonKm = Self.interpolate(longitudeErrorKm, latitudeDegrees, longitudeDegrees)
        let latitude = latitudeDegrees - latKm / Constants.kmPerDegree
        // The longitude error is stored in ground kilometers. Dividing by the length of one degree at this
        // latitude turns it back into degrees. The cosine is kept away from zero so the division stays finite at
        // the poles, where the field is zero anyway.
        let stretch = max(0.1, cos(latitude * .pi / 180))
        var longitude = longitudeDegrees - lonKm / (Constants.kmPerDegree * stretch)
        if longitude >= 180 {
            longitude -= 360
        }
        if longitude < -180 {
            longitude += 360
        }
        return (latitude, longitude)
    }

    /// Bilinear interpolation over the grid, with longitude wrapping across the antimeridian.
    private static func interpolate(_ grid: [Double], _ latitude: Double, _ longitude: Double) -> Double {
        let row = (min(max(latitude, -90), 90) + 90) / Grid.rowSpacingDegrees
        var column = (longitude + 180) / Grid.columnSpacingDegrees
        if column < 0 {
            column += Double(Grid.columns)
        }
        let row0 = min(Int(row), Grid.rows - 2)
        let column0 = Int(column) % Grid.columns
        let rowFraction = row - Double(row0)
        let columnFraction = column - Double(Int(column))
        let column1 = (column0 + 1) % Grid.columns

        let bottom = grid[row0 * Grid.columns + column0] * (1 - columnFraction)
            + grid[row0 * Grid.columns + column1] * columnFraction
        let top = grid[(row0 + 1) * Grid.columns + column0] * (1 - columnFraction)
            + grid[(row0 + 1) * Grid.columns + column1] * columnFraction
        return bottom * (1 - rowFraction) + top * rowFraction
    }
}

extension MapCalibration {
    /// Which direction of error a sample measures. A stretch of coast or border that runs east-west can only
    /// show how far north or south the map drew it, and a north-south stretch can only show how far east or
    /// west.
    enum Component {
        case latitude
        case longitude
    }

    /// One measured offset between the reference and the drawn map: where the reference vertex sits, and how far
    /// from it, along the direction `component` names, the drawn outline passed. Matching already refuses pairs
    /// that are far apart in the other direction, so both points describe the same stretch of coast or border.
    struct Sample {
        let latitude: Double
        let longitude: Double
        let deltaKm: Double
        let component: Component
    }

    /// How one direction's fit came out, for the bake's log.
    struct ComponentReport {
        var samples = 0
        var dropped = 0
        var rmsBeforeKm = 0.0
        var rmsAfterKm = 0.0
        var peakCorrectionKm = 0.0
    }

    /// The fit's outcome for the bake log: one report per direction, and whether calibration was abandoned.
    struct FitReport {
        var latitude = ComponentReport()
        var longitude = ComponentReport()
        var degradedToIdentity = false

        func printSummary() {
            if degradedToIdentity {
                print("MapBaker: calibration: too few usable correspondences, applying no correction")
                return
            }
            print(summary(of: latitude, named: "north-south"))
            print(summary(of: longitude, named: "east-west"))
        }

        /// One line per direction, since the two are fitted from different samples and come out at different
        /// accuracies. Reporting a single number for both would hide whichever fit went worse.
        private func summary(of report: ComponentReport, named name: String) -> String {
            guard report.samples > 0 else {
                return "MapBaker: calibration: no \(name) field, leaving that direction uncorrected"
            }
            return String(
                format: "MapBaker: calibration: %@ field from %d samples (%d dropped), rms %.1f km down to %.1f, peak correction %.1f km",
                name, report.samples, report.dropped, report.rmsBeforeKm, report.rmsAfterKm, report.peakCorrectionKm
            )
        }
    }

    private enum Constants {
        static let kmPerDegree = 111.19
        /// After a first fit, samples whose residual exceeds this multiple of the rms are dropped and the field is
        /// refitted once.
        static let residualTrimFactor = 2.5
        /// Below this many surviving samples a direction's fit is not trusted. Without a north-south fit the bake
        /// runs uncorrected. Without an east-west one it corrects north-south alone.
        static let minimumSamples = 200
        /// Weight of the smoothness term tying neighboring nodes together, relative to a single sample. High
        /// enough that a handful of noisy matches cannot bend the field locally, low enough that a well-sampled
        /// region reaches its measured displacement.
        static let smoothness = 25.0
        /// A faint pull toward zero on every node, so regions with no data at all (open ocean, the poles) come
        /// out uncorrected instead of inheriting whatever their nearest sampled neighbors say.
        static let ridge = 0.05
        /// Whether the east-west field is applied. A sparse reference has too few north-south segments to measure
        /// east-west error reliably. The bundled 50m country outlines measure it well.
        static let appliesLongitude = true
    }

    /// Fits the north-south field, and the east-west one when `appliesLongitude` is true. Each direction is
    /// fitted twice, with the first fit's outliers dropped before the second, as `residualTrimFactor` describes.
    static func fitted(from samples: [Sample]) -> (MapCalibration, FitReport) {
        var report = FitReport()

        func fitComponent(_ component: Component, into componentReport: inout ComponentReport) -> [Double]? {
            let mine = samples.filter { $0.component == component }
            guard mine.count >= Constants.minimumSamples, let first = solve(mine) else { return nil }
            let residuals = mine.map { $0.deltaKm - interpolate(first, $0.latitude, $0.longitude) }
            let firstRms = rms(residuals)
            let kept = zip(mine, residuals).filter { abs($0.1) < Constants.residualTrimFactor * firstRms }.map(\.0)
            guard kept.count >= Constants.minimumSamples, let field = solve(kept) else { return nil }
            componentReport.samples = kept.count
            componentReport.dropped = mine.count - kept.count
            componentReport.rmsBeforeKm = rms(kept.map(\.deltaKm))
            componentReport.rmsAfterKm = rms(kept.map { $0.deltaKm - interpolate(field, $0.latitude, $0.longitude) })
            componentReport.peakCorrectionKm = field.map(abs).max() ?? 0
            return field
        }

        // North-south is the direction the map is most wrong in, and the one every east-west reference segment
        // measures. When even it cannot be fitted, the whole calibration is abandoned.
        guard let latitudeField = fitComponent(.latitude, into: &report.latitude) else {
            report.degradedToIdentity = true
            return (.identity, report)
        }
        // East-west may fail without aborting, since a reference with few north-south segments cannot measure it.
        // Leaving that direction uncorrected beats discarding a good north-south field with it.
        let longitudeField = Constants.appliesLongitude
            ? fitComponent(.longitude, into: &report.longitude)
            : nil
        return (
            MapCalibration(
                latitudeErrorKm: latitudeField,
                longitudeErrorKm: longitudeField ?? [Double](repeating: 0, count: Grid.nodeCount)
            ),
            report
        )
    }

    /// The node values that best fit the samples by least squares, with the `smoothness` and `ridge` terms
    /// added, or nil when the solver fails. The ridge keeps the matrix positive definite, which the Cholesky
    /// routine `dposv_` requires.
    private static func solve(_ samples: [Sample]) -> [Double]? {
        let n = Grid.nodeCount
        var normal = [Double](repeating: 0, count: n * n)
        var rhs = [Double](repeating: 0, count: n)

        for sample in samples {
            let row = (min(max(sample.latitude, -90), 90) + 90) / Grid.rowSpacingDegrees
            var column = (sample.longitude + 180) / Grid.columnSpacingDegrees
            if column < 0 {
                column += Double(Grid.columns)
            }
            let row0 = min(Int(row), Grid.rows - 2)
            let column0 = Int(column) % Grid.columns
            let rowFraction = row - Double(row0)
            let columnFraction = column - Double(Int(column))
            let column1 = (column0 + 1) % Grid.columns
            let nodes = [
                (row0 * Grid.columns + column0, (1 - rowFraction) * (1 - columnFraction)),
                (row0 * Grid.columns + column1, (1 - rowFraction) * columnFraction),
                ((row0 + 1) * Grid.columns + column0, rowFraction * (1 - columnFraction)),
                ((row0 + 1) * Grid.columns + column1, rowFraction * columnFraction),
            ]
            for (i, wi) in nodes {
                rhs[i] += wi * sample.deltaKm
                for (j, wj) in nodes {
                    normal[i * n + j] += wi * wj
                }
            }
        }

        // One smoothness term per pair of neighboring nodes. Longitude neighbors wrap around the globe, while
        // latitude rows stop at the poles.
        for row in 0 ..< Grid.rows {
            for column in 0 ..< Grid.columns {
                let node = row * Grid.columns + column
                let east = row * Grid.columns + (column + 1) % Grid.columns
                addDifferencePenalty(&normal, n, node, east, Constants.smoothness)
                if row + 1 < Grid.rows {
                    let north = (row + 1) * Grid.columns + column
                    addDifferencePenalty(&normal, n, node, north, Constants.smoothness)
                }
                normal[node * n + node] += Constants.ridge
            }
        }

        // LAPACK expects column-major storage, which for a symmetric matrix is the same as row-major.
        var uplo = Int8(UInt8(ascii: "L"))
        var order = __CLPK_integer(n)
        var oneColumn = __CLPK_integer(1)
        var matrixLeading = __CLPK_integer(n)
        var solutionLeading = __CLPK_integer(n)
        var status = __CLPK_integer(0)
        var solution = rhs
        dposv_(&uplo, &order, &oneColumn, &normal, &matrixLeading, &solution, &solutionLeading, &status)
        return status == 0 ? solution : nil
    }

    private static func addDifferencePenalty(_ normal: inout [Double], _ n: Int, _ i: Int, _ j: Int, _ weight: Double) {
        normal[i * n + i] += weight
        normal[j * n + j] += weight
        normal[i * n + j] -= weight
        normal[j * n + i] -= weight
    }

    private static func rms(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return (values.reduce(0) { $0 + $1 * $1 } / Double(values.count)).squareRoot()
    }
}
