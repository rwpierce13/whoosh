//
//  VisionView.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/25/25.
//

import SwiftUI
import AVKit
import Vision
import VisionKit


struct GameView: View {
    
    @StateObject var cameraModel = CameraModel()
    @StateObject var detectorModel = DetectorModel()
    @StateObject var gameModel = GameModel()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreview(frame: CGRect(origin: .zero, size: geo.size))

                ControlsView()
                if let tee = detectorModel.tee {
                    DetectionView(detection: tee)
                }
                if let hole = detectorModel.hole {
                    DetectionView(detection: hole)
                }
                if let ball = detectorModel.ball {
                    DetectionView(detection: ball)
                }
                if let putt = gameModel.putt {
                    TrajectoryView(collection: putt)
                }
            }
        }
        .onAppear {
            cameraModel.detectorDelegate = detectorModel
            detectorModel.ballChangeDelegate = gameModel
        }
        .environmentObject(cameraModel)
        .environmentObject(detectorModel)
        .environmentObject(gameModel)
    }
}




//MARK: -
struct ControlsView: View {
    
    @EnvironmentObject var detectorModel: DetectorModel
    @EnvironmentObject var gameModel: GameModel
    
    var body: some View {
        Center {
            Button {
                switch gameModel.state {
                case .initial:
                    break
                case .ready:
                    gameModel.record()
                case .recording:
                    gameModel.finish()
                case .done, .error:
                    gameModel.reset()
                    detectorModel.reset()
                }
            } label: {
                buttonView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinesOverlay()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(gameModel.state.statusText)
                    .font(Font.system(size: 16))
                    .foregroundStyle(.white)
            }
            
        }
    }
    
    @ViewBuilder
    func buttonView() -> some View {
        switch gameModel.state {
        case .initial:
            EmptyView()
        case .ready:
            HSStack {
                Image(systemName: "record.circle.fill")
                    .fitTo(width: 32)
                    .foregroundStyle(.white)
                    .padding(.trailing, 20)
                Text("RECORD")
                    .font(Font.system(size: 20))
                    .foregroundStyle(.white)
            }
            .padding(20)
            .background(.red)
            .cornerRadius(10)
        case .recording:
            EmptyView()
        case .done:
            HSStack {
                Image(systemName: "checkmark.circle.fill")
                    .fitTo(width: 32)
                    .foregroundStyle(.green)
                    .padding(.trailing, 20)
                Text("DONE")
                    .font(Font.system(size: 20))
                    .foregroundStyle(.green)
            }
            .padding(20)
            .background(.white)
            .cornerRadius(10)
        case .error:
            HSStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .fitTo(width: 32)
                    .foregroundStyle(.yellow)
                    .padding(.trailing, 20)
                Text("ERROR")
                    .font(Font.system(size: 20))
                    .foregroundStyle(.green)
            }
            .padding(20)
            .background(.white)
            .cornerRadius(10)
        }
    }
}


//MARK: -
struct LinesOverlay: View {
        
    @EnvironmentObject var gameModel: GameModel
    
    @State var circle: (CGPoint, CGFloat) = (.zero, 0)
    @State var vLine: (CGPoint, CGPoint) = (.zero, .zero)
    @State var crossV: (CGPoint, CGPoint) = (.zero, .zero)
    @State var crossH: (CGPoint, CGPoint) = (.zero, .zero)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle(point: circle.0, radius: circle.1)
                    .stroke(style: .init(dash: [4, 10]))
                    .glow(color: gameModel.state != .initial ? .green : .clear, radius: 5)
                Line(start: vLine.0, end: vLine.1)
                    .stroke(style: .init(dash: [4, 10]))
                    .glow(color: gameModel.state != .initial ? .green : .clear, radius: 5)
                Line(start: crossV.0, end: crossV.1)
                    .stroke(.white)
                Line(start: crossH.0, end: crossH.1)
                    .stroke(.white)
            }
            .onAppear {
                calcPoints(from: geo.size)
            }
        }
    }
    
    private func calcPoints(from size: CGSize) {
        circle.0 = convertPoint(gameModel.circle.0, with: size)
        circle.1 = gameModel.circle.1 * size.height
        vLine.0 = convertPoint(gameModel.vLine.0, with: size)
        vLine.1 = convertPoint(gameModel.vLine.1, with: size)
        crossV.0 = convertPoint(gameModel.crossV.0, with: size)
        crossV.1 = convertPoint(gameModel.crossV.1, with: size)
        crossH.0 = convertPoint(gameModel.crossH.0, with: size)
        crossH.1 = convertPoint(gameModel.crossH.1, with: size)
    }
    
    private func convertPoint(_ point: CGPoint, with size: CGSize) -> CGPoint {
        return CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
