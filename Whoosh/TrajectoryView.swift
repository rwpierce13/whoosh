//
//  TrajectoryView.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/25/25.
//

import SwiftUI
import Vision


struct TrajectoryView: View {
    
    @EnvironmentObject var cameraModel: CameraModel
    var collection: PointCollection
    
    func convertedPoints() -> [CGPoint] {
        let points = collection.points.map { $0.location }
        return cameraModel.convertVisionPointsToCameraPoint(points)
    }
    
    var body: some View {
        Trajectory(points: convertedPoints())
            .stroke(collection.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }
}


struct DetectionTrajectoryView: View {
    
    @EnvironmentObject var cameraModel: CameraModel
    var collection: DetectionCollection
    
    func convertedPoints() -> [CGPoint] {
        let points = collection.detections.map { $0.box.center }
        return cameraModel.convertVisionPointsToCameraPoint(points)
    }
    
    var body: some View {
        Trajectory(points: convertedPoints())
            .stroke(collection.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }
    
}
