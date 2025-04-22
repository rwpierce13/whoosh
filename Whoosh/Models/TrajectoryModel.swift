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


