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
    var lineWidth: CGFloat = 5
    
    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .local)
            let points = collection.convertedPoints(to: frame)
            Trajectory(points: points)
                .stroke(
                    collection.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
        }
    }
}


struct DetectionView: View {
    
    @EnvironmentObject var gameModel: GameModel
    var detection: Detection
    var lineWidth: CGFloat = 3
    @State var xOffset: CGFloat = 0
    
    func convertedRect(to rect: CGRect) -> CGRect {
        guard let convert = gameModel.visionConversionRect else { return .zero }
        return GameModel.convert(detection.box, to: rect, with: convert)
    }
    
    var body: some View {
        GeometryReader { geo in
            let rect = convertedRect(to: geo.frame(in: .local))
            BoundingBox(box: convertedRect(to: geo.frame(in: .local)))
                .stroke(detection.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
                .overlay {
                    Text(detection.labels.first?.capitalized ?? "Unknown")
                        .regularFont(13)
                        .foregroundStyle(.white)
                        .padding(1)
                        .background(detection.color)
                        .background {
                            BackgroundRectReader { rect in
                                xOffset = (rect.width - lineWidth) / 2
                            }
                        }
                        .position(x: rect.minX, y: rect.minY)
                        .offset(x: xOffset, y: -8)
                }
        }
    }
}

