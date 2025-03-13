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
        var points = collection.points.map { $0.location }
        points = points.map { CGPoint(x: $0.x, y: 1 - $0.y) }
        return cameraModel.convertVisionPointsToCameraPoint(points)
    }
    
    var body: some View {
        Trajectory(points: convertedPoints())
            .stroke(collection.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }
}

struct Trajectory: Shape {
    
    var points: [CGPoint] = []
    
    func path(in rect: CGRect) -> Path {
        let trajectory = UIBezierPath.smoothPath(points)
        return Path(trajectory.cgPath)
    }
    
}
