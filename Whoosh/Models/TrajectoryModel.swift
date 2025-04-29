//
//  VIsionModel.swift
//  Whoosh
//
//  Created by Robert Pierce on 4/21/25.
//

import SwiftUI
import Vision


class TrajectoryModel: NSObject, ObservableObject {
    
    @Published var collections: [PointCollection] = []
    @Published var error: Error?
    
    private let minConfidence: VNConfidence = 0.95
    private let trajectoryQueue = DispatchQueue(label: "com.Whoosh.TrajectoryQueue", qos: .userInteractive)
    private lazy var detectTrajectoryRequest: VNDetectTrajectoriesRequest! = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: 6)
    
    func processTrajectoryResults(_ results: [VNTrajectoryObservation]) {
        for path in results where path.confidence > minConfidence {
            let new = PointCollection(path)
            var up: PointCollection?
            var index: Int?
            for col in collections {
                if path.uuid.uuidString == col.id {
                    up = updatedPointCollection(col, with: path)
                    index = collections.firstIndex(where: { $0.id == up!.id })
                    //print("$$$ UP ID \(up!)")
                    break
                }
                if col.similarEndpoints(new) { //}&& col.similarAngle(new) {
                    up = updatedPointCollection(col, with: path)
                    index = collections.firstIndex(where: { $0.id == up!.id })
                    //print("$$$ UP END \(up!)")
                    break
                }
                if col.similarTimes(new) && col.similarLocation(new) {
                    up = updatedPointCollection(col, with: path)
                    index = collections.firstIndex(where: { $0.id == up!.id })
                    //print("$$$ UP TIMES \(up!)")
                    break
                }
            }
            if let i = index {
                collections.remove(at: i)
                collections.append(up!)
            } else {
                collections.append(new)
                //print("$$$ NEW \(new)")
            }
        }
        //print("$$$ \(collections.count)")
    }
    
    func updatedPointCollection(_ collection: PointCollection, with path: VNTrajectoryObservation) -> PointCollection {
        var col = collection
        let oldPoints = col.points
        let newPoints = path.detectedPoints
        var appending = [VNPoint]()
        
        //Check the last new points, 2 just in case
        let pre = newPoints.suffix(newPoints.count > 6 ? 2 : 1)
        for new in pre {
            if !col.overlapsPath(new.location) {
                appending.append(new)
            }
        }
        
        col.points = oldPoints + appending
        let newTimeRange = col.timeRange.union(path.timeRange)
        //print("$$$ CHANGES \(appending.count)")
        col.timeRange = newTimeRange
        return col
    }
    
    func analyze(_ points: [VNPoint]) {
        for (i, point) in points.enumerated() {
            if i < points.count - 2 {
                let dist = point.distance(points[i + 1])
                print(dist)
            }
        }
    }
    
    func reset() {
        collections = []
    }
}



extension TrajectoryModel: CameraOutputDelegate {
    func cameraModel(_ cameraModel: CameraModel, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        
        trajectoryQueue.async {
            do {
                try visionHandler.perform([self.detectTrajectoryRequest])
                if let results = self.detectTrajectoryRequest.results, !results.isEmpty {
                    DispatchQueue.main.async {
                        self.processTrajectoryResults(results)
                    }
                }
            } catch (let err) {
                DispatchQueue.main.async {
                    self.error = err
                    print(err)
                }
            }
        }
    }
}




let MaxLocationComparison: Double = 0.04
let MaxTimeComparison: Double = 0.1
let MaxAngleComparison: Double = 10

struct PointCollection: Identifiable, CustomStringConvertible {
    
    let id: String
    var points: [VNPoint] = []
    var color: Color = Color.randomColor()
    var timeRange: CMTimeRange
    var cgPoints: [CGPoint] = []
    
    init(_ path: VNTrajectoryObservation) {
        self.id = path.uuid.uuidString
        self.points = path.detectedPoints
        self.timeRange = path.timeRange
    }
    
    var startSeconds: Double {
        return timeRange.start.seconds
    }
    
    var endSeconds: Double {
        return timeRange.end.seconds
    }
    
    var description: String {
        return "PointCollection \(id)\n\t\(points.count) points\n\t\(startSeconds) \(endSeconds)"
    }
    
    func similarTimes(_ col: PointCollection, maxTime: Double = MaxTimeComparison) -> Bool {
        if self.timeRange.overlaps(col.timeRange) {
            return true
        }
        let diff = abs(self.endSeconds - col.startSeconds)
        if diff < maxTime {
            return true
        }
        
        //print("$$$ NOT TIME \(diff)")
        return false
    }
    
    func similarAngle(_ col: PointCollection, maxAngle: Double = MaxAngleComparison) -> Bool {
        guard self.points.count > 1, col.points.count > 1 else { return false }
        let count = self.points.count
        let dx = self.points[count - 1].x - self.points[count - 2].x
        let dy = self.points[0].y - self.points[1].y
        let angle = atanl(dx / dy) * 180 / Double.pi
        
        let colDx = col.points[0].x - col.points[1].x
        let colDy = col.points[0].y - col.points[1].y
        let colAngle = atanl(colDx / colDy) * 180 / Double.pi
        
        //print("$$$ ANGLES \(angle) \(colAngle)")
        
        return fabs(angle - colAngle) < maxAngle
    }
    
    func similarLocation(_ col: PointCollection, max: Double = MaxLocationComparison) -> Bool {
        for p in self.points {
            for c in col.points {
                if p.isNear(c, max: max) {
                    return true;
                }
            }
        }
        
        return false
    }
    
    func similarEndpoints(_ col: PointCollection, max: Double = MaxLocationComparison) -> Bool {
        guard !self.points.isEmpty, !col.points.isEmpty else { return false }
        guard let end = self.points.last, let startCol = col.points.first else { return false }
        
        //print("$$$ ENDPOINTS \(end) \(startCol)")
        return end.isNear(startCol, max: max)
    }
    
    func overlapsPath(_ point: CGPoint) -> Bool {
        let cg1 = self.points.map { $0.location }
        let line = UIBezierPath.line(for: cg1)
        return line.overlapsPath(point, toleranceWidth: 8.0)
    }
}
