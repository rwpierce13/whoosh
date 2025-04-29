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


class UIModel: ObservableObject {
    @Published var showSettings: Bool = false
}


struct GameView: View {
    
    @StateObject var cameraModel = CameraModel()
    @StateObject var detectorModel = DetectorModel()
    @StateObject var gameModel = GameModel()
    @StateObject var uiModel = UIModel()
    
    var body: some View {
        ZStack {
            ZStack {
                CameraView()
                
                LinesOverlay()
                
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
            .ignoresSafeArea(.all)
            
            TopControl()
        }
        .onChange(of: cameraModel.visionConversionRect) { _, new in
            gameModel.visionConversionRect = new
        }
        .onAppear {
            cameraModel.detectorDelegate = detectorModel
            detectorModel.puttChangeDelegate = gameModel
            detectorModel.start()
        }
        .fullScreenCover(isPresented: $gameModel.showSuccess) {
            NavigationStack {
                ScoreView()
                    .onDisappear {
                        detectorModel.start()
                    }
            }
        }
        .sheet(isPresented: $uiModel.showSettings) {
            NavigationStack {
                SettingsView()
                    .onDisappear {
                        gameModel.reset()
                        detectorModel.reset()
                    }
            }
        }
        .environmentObject(cameraModel)
        .environmentObject(detectorModel)
        .environmentObject(gameModel)
        .environmentObject(uiModel)
    }
}


//MARK: -
struct TopControl: View {
    
    @EnvironmentObject var cameraModel: CameraModel
    @EnvironmentObject var detectorModel: DetectorModel
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var uiModel: UIModel
    
    var body: some View {
        GeometryReader { geo in
            VSStack {
                Color.clear
                    .frame(height: geo.safeAreaInsets.top)
                HSStack {
                    GameButton()
                    Spacer()
                    Button {
                        gameModel.reset()
                        detectorModel.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .fitTo(height: 30)
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 20)
                    Button {
                        uiModel.showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .fitTo(height: 30)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(.black.opacity(0.3))
                
                Spacer()
            }
            .ignoresSafeArea(.all)
        }
    }
}


//MARK: -
struct GameButton: View {
    
    @EnvironmentObject var cameraModel: CameraModel
    @EnvironmentObject var detectorModel: DetectorModel
    @EnvironmentObject var gameModel: GameModel
    
    var body: some View {
        Button {
            switch gameModel.state {
            case .initial:
                break
            case .ready:
                gameModel.record()
            case .recording:
                gameModel.finish()
            case .done:
                detectorModel.stop()
                gameModel.finalImage = cameraModel.finalImage()
                gameModel.showSuccess.toggle()
            case .error:
                gameModel.reset()
                detectorModel.reset()
            }
        } label: {
            buttonView()
        }
    }
    
    @ViewBuilder
    func buttonView() -> some View {
        switch gameModel.state {
        case .initial:
            Text(gameModel.state.statusText)
                .font(Font.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 10)
        case .ready:
            HSStack {
                Image(systemName: "record.circle.fill")
                    .fitTo(width: 24)
                    .foregroundStyle(.white)
                    .padding(.trailing, 20)
                Text("RECORD")
                    .font(Font.system(size: 20))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.red)
            .cornerRadius(10)
        case .recording:
            EmptyView()
        case .done:
            HSStack {
                Image(systemName: "checkmark.circle.fill")
                    .fitTo(width: 24)
                    .foregroundStyle(.green)
                    .padding(.trailing, 20)
                Text("DONE")
                    .font(Font.system(size: 20))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.white)
            .cornerRadius(10)
        case .error:
            HSStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .fitTo(width: 24)
                    .foregroundStyle(.yellow)
                    .padding(.trailing, 20)
                Text("ERROR")
                    .font(Font.system(size: 20))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
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
            .onChange(of: geo.size) { _, new in
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
