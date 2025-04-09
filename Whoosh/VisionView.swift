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


struct VisionView: View {
    
    @StateObject var cameraModel = CameraModel()
    //@StateObject var visionModel = VisionModel()
    @StateObject var detectorModel = DetectorModel()
    @StateObject var gameModel = GameModel()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreview(frame: CGRect(origin: .zero, size: geo.size))
                /*
                ForEach(visionModel.collections) { col in
                    TrajectoryView(collection: col)
                }
                 */
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
                if let col = gameModel.collection {
                    DetectionTrajectoryView(collection: col)
                }
            }
        }
        .onAppear {
            //cameraModel.visionDelegate = visionModel
            cameraModel.detectorDelegate = detectorModel
            detectorModel.ballChangeDelegate = gameModel
        }
        .environmentObject(cameraModel)
        //.environmentObject(visionModel)
        .environmentObject(detectorModel)
        .environmentObject(gameModel)
    }
}


enum GameState {
    case initial, ready, recording, done
    
    var statusText: String {
        switch self {
        case .initial:
            return "Searching for ball"
        case .ready:
            return "Ready to record!"
        case .recording:
            return "Recording..."
        case .done:
            return "Done!"
        }
    }
}

class GameModel: ObservableObject {
    
    @Published var state: GameState = .initial
    @Published var collection: DetectionCollection?
    
    //Normalized lines
    let circle: (CGPoint, CGFloat) = (CGPoint(x: 0.5, y: 0.85), 0.04)
    let vLine: (CGPoint, CGPoint) = (CGPoint(x: 0.5, y: 0.81), CGPoint(x: 0.5, y: 0.15))
    let crossV: (CGPoint, CGPoint) = (CGPoint(x: 0.5, y: 0.84), CGPoint(x: 0.5, y: 0.86))
    let crossH: (CGPoint, CGPoint) = (CGPoint(x: 0.48, y: 0.85), CGPoint(x: 0.52, y: 0.85))

    func record() {
        state = .recording
        collection = DetectionCollection()
    }
    
    func finish() {
        state = .done
    }
    
    func reset() {
        state = .initial
        collection = nil
    }
    
    func ballInCircle(_ ball: Detection?) -> Bool {
        guard let b = ball else { return false }
        let convertedBallCenter = CGPoint(x: 1 - b.box.center.y, y: b.box.center.x)
        let dx = abs(circle.0.x - convertedBallCenter.x)
        let dy = abs(circle.0.y - convertedBallCenter.y)
        return dx < 0.02 && dy < 0.02
    }
}

extension GameModel: BallChangeDelegate {
    
    func ballDidChange(_ ball: Detection?) {
        guard let b = ball else {
            if state == .recording {
                state = .done
            }
            return
        }
        
        if state == .initial, ballInCircle(ball) {
            state = .ready
        } else if state == .ready, !ballInCircle(ball) {
            state = .initial
        }
        
        guard let col = collection else { return }
        var newCol = col
        newCol.detections.append(b)
        collection = newCol
    }
}


struct DetectionCollection: Identifiable {
    var id: UUID = UUID()
    var detections: [Detection] = []
    
    var color: Color {
        if let first = detections.first {
            return first.color
        }
        return .blue
    }
}


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
                case .done:
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
        }
    }
}

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

struct Circle: Shape {
    
    var point: CGPoint
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let circle = UIBezierPath(arcCenter: point, radius: radius, startAngle: Double.pi * 3/2, endAngle: Double.pi * 7/2, clockwise: true)
        return Path(circle.cgPath)
    }
}

struct Line: Shape {
    
    var start: CGPoint
    var end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
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


//MARK: -
class VisionModel: NSObject, ObservableObject {

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

extension CMTimeRange {
    
    func overlaps(_ timeRange: CMTimeRange) -> Bool {
        return !self.intersection(timeRange).isEmpty
    }
}

extension VNPoint {
    
    func isNear(_ point: VNPoint, max: Double = MaxLocationComparison) -> Bool {
        let distance = self.distance(point)
        return distance < max
    }
}


extension VisionModel: CameraOutputDelegate {
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




