//
//  TrajectoryView.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/25/25.
//

import SwiftUI
import Vision


struct TrajectoryView: View {
    
    var collection: DetectionCollection
    var contentMode: ContentMode = .fill
    
    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .local)
            let points = collection.convertedPoints(to: frame, contentMode: contentMode)
            Trajectory(points: points)
                .stroke(collection.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }
}


struct DetectionView: View {
    
    @EnvironmentObject var gameModel: GameModel
    var detection: Detection
    
    func convertedRect(to rect: CGRect) -> CGRect {
        guard let convert = gameModel.visionConversionRect else { return .zero }
        return GameModel.convert(detection.box, to: rect, with: convert)
    }
    
    var body: some View {
        GeometryReader { geo in
            BoundingBox(box: convertedRect(to: geo.frame(in: .local)))
                .stroke(detection.color, style: StrokeStyle(lineWidth: 3, lineCap: .square))
        }
    }
}

