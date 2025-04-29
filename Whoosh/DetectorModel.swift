//
//  DetectorView.swift
//  Whoosh
//
//  Created by Robert Pierce on 3/19/25.
//

import SwiftUI
import Vision

enum DetectionType {
    case ball, hole, tee
    
    init(label: String) {
        switch label {
        case "ball":
            self = .ball
        case "hole":
            self = .hole
        case "tee":
            self = .tee
        default:
            self = .ball
        }
    }
    
    func color() -> Color {
        switch self {
        case .ball:
            return .blue
        case .hole:
            return .green
        case .tee:
            return .red
        }
    }
}

struct Detection: Identifiable {
    
    var id = UUID().uuidString
    var box: CGRect
    var labels: [String] = []
    var observation: VNDetectedObjectObservation
    var type: DetectionType
    var color: Color = Color.randomColor()
    
    init(observation: VNRecognizedObjectObservation) {
        self.id = observation.uuid.uuidString
        self.box = Detection.convertBox(observation.boundingBox)
        self.labels = observation.labels.map { $0.identifier }
        self.observation = observation
        self.type = DetectionType(label: labels.first ?? "ball")
        self.color = type.color()
    }
    
    static func convertBox(_ box: CGRect) -> CGRect {
        //Original boundingBox are landscape video detections
        //Flip x/y to convert to portrait video
        let converted = CGRect(x: box.minY,
                               y: box.minX,
                               width: box.height,
                               height: box.width)
        return converted
    }
    
        
    //MARK: Debugging
    private init(box: CGRect, label: String) {
        self.id = UUID().uuidString
        self.box = box //not converted rect
        self.labels = [label]
        self.observation = VNDetectedObjectObservation(boundingBox: box)
        self.type = DetectionType(label: labels.first ?? "ball")
        self.color = type.color()
    }
    
    static func hole() -> Detection {
        let rect = CGRect(x: 0.25, y: 0.37, width: 0.1, height: 0.03)
        return Detection(box: rect, label: "hole")
    }
    
    static func tee() -> Detection {
        let rect = CGRect(x: 0.485, y: 0.35, width: 0.03, height: 0.03)
        return Detection(box: rect, label: "tee")
    }
}


//MARK: -
struct DetectionCollection: Identifiable {
    var conversionRect: CGRect
    var id: UUID = UUID()
    var ballDetections: [Detection] = []
    var ballVelocities: [CGFloat] = []
    var holeDetection: Detection?
    var teeDetection: Detection?
    
    private let MinimumMovingVelocity = 2e-3
    private let StationaryCount = 8
    private let MinumumDistanceMoved = 10e-4
    private let DistanceNoiseFilter = 1e-2

    var color: Color {
        if let first = ballDetections.first {
            return first.color
        }
        return .blue
    }
    
    
    //MARK: - Coordinate Conversion
    func convertedPoints(to rect: CGRect) -> [CGPoint] {
        let points = ballDetections.map { $0.box.center }
        let new = GameModel.convert(points, to: rect, with: conversionRect)
        return new
    }
    
    
    //MARK: - Score
    func endIsStationary() -> Bool {
        guard ballVelocities.count > StationaryCount else { return false }
        let endVelocities = ballVelocities.suffix(StationaryCount)
        let stationary = endVelocities.allSatisfy { abs($0) < MinimumMovingVelocity }
        return stationary
    }
    
    func calcLastVelocity() -> CGFloat? {
        let lastIndex = ballDetections.count - 1
        let secondLastIndex = ballDetections.count - 2
        guard lastIndex > 0, secondLastIndex >= 0 else { return nil }
        let lastDet = ballDetections[lastIndex]
        let secondLastDet = ballDetections[secondLastIndex]
        let dt = lastDet.observation.timeRange.start.seconds - secondLastDet.observation.timeRange.start.seconds
        let distance = lastDet.box.center.distance(to: secondLastDet.box.center)
        if distance <= MinumumDistanceMoved {
            //print("$$$ Filter distance \(distance)")
            return 0
        }
        let velocity = distance / CGFloat(dt)
        return velocity
    }
    
    func didStart() -> Bool {
        return ballVelocities.filter { $0 > MinimumMovingVelocity }.count >= StationaryCount
    }
    
    func didEnd() -> Bool {
        return didStart() && endIsStationary()
    }
    
    func ballStopDistance() -> Distance? {
        guard endIsStationary() else { return nil }
        guard let lastDet = ballDetections.last else { return nil }
        guard let holeDet = holeDetection else { return nil }
        let dy = lastDet.box.center.y - holeDet.box.center.y
        if abs(dy) < DistanceNoiseFilter {
            return .good
        }
        return dy > 0 ? .short : .long
    }
    
    func firstMovingDetections(_ count: Int = 10, skipping: Int = 10) -> [Detection]? {
        var velocities = ballVelocities
        var startIndex = 0
        while true {
            let suffix = velocities.prefix(count)
            if suffix.allSatisfy( { abs($0) > MinimumMovingVelocity } ) {
                break
            }
            startIndex += 1
            velocities = Array(velocities.dropFirst())
        }
        if ballDetections.count <= startIndex + skipping + count {
            return nil
        }
        let detections = Array(ballDetections[startIndex+skipping...startIndex+skipping+count])
        return detections
    }
    
    func aim() -> Aim? {
        guard let movingDetections = firstMovingDetections() else { return nil }
        let aims = movingDetections.compactMap { aim(for: $0) }
        let equal = aims.dropFirst().allSatisfy { $0 == aims.first }
        return equal ? aims.first : nil
    }
    
    func read() -> Read? {
        return nil
    }
    
    func aim(for detection: Detection) -> Aim {
        let x = detection.box.center.x
        let dx = abs(x - 0.5) //0.5 is the vertical center line
        if dx < DistanceNoiseFilter { return .straight }
        return x > 0.5 ? .right : .left
    }

}



//MARK: -
protocol BallChangeDelegate {
    func ballDidChange(_ ball: Detection?)
    func ballError(_ error: Error?)
    func holeDidChange(_ hole: Detection?)
    func teeDidChange(_ tee: Detection?)
}

class DetectorModel: NSObject, ObservableObject {
    
    var puttChangeDelegate: BallChangeDelegate?
    var detections: [Detection] = []
    @Published var ball: Detection?
    @Published var hole: Detection?
    @Published var tee: Detection?
    @Published var error: Error?
    
    private var detecting = false
    
    private let minConfidence: VNConfidence = 0.95
    private var sequenceHandler = VNSequenceRequestHandler()
    private var objectDetectionRequest: VNCoreMLRequest!
    private var ballTrackingRequest: VNTrackingRequest?
    
    private let detectionQueue = DispatchQueue(label: "com.Whoosh.DetectionQueue", qos: .userInteractive)
    
    override init() {
        super.init()
        
        // Create Vision request based on CoreML model
        let config = MLModelConfiguration()
        let whoosh = try! WhooshML2(configuration: config)
        let model = try! VNCoreMLModel(for: whoosh.model)
        objectDetectionRequest = VNCoreMLRequest(model: model)
        objectDetectionRequest.imageCropAndScaleOption = .scaleFit
    }
    
    @MainActor
    func processDetectionResults(_ results: [VNRecognizedObjectObservation]) {
        var newDetections: [Detection] = []
        for result in results { //where result.confidence > minConfidence {
            if var det = detections.first(where: { $0.id == result.uuid.uuidString }) {
                det.box = Detection.convertBox(result.boundingBox)
                newDetections.append(det)
            } else {
                newDetections.append(Detection(observation: result))
            }
        }
        detections = newDetections
        
        let balls = detections.filter { $0.type == .ball }
        ball = balls.first
        /*
        let holes = detections.filter { $0.type == .hole }
        hole = holes.first
        let tees = detections.filter { $0.type == .tee }
        tee = tees.first
         */
        
        if UserDefaults.standard.bool(forKey: Keys.UseTestHole.rawValue) {
            hole = Detection.hole()
        }
        if UserDefaults.standard.bool(forKey: Keys.UseTestTee.rawValue) {
            tee = Detection.tee()
        }
        
        puttChangeDelegate?.ballDidChange(ball)
        puttChangeDelegate?.holeDidChange(hole)
        puttChangeDelegate?.teeDidChange(tee)
    }
    
    @MainActor
    func processTrackingResults(_ results: [VNDetectedObjectObservation]?) {
        guard let result = results?.first, result.confidence > 0.1 else {
            puttChangeDelegate?.ballDidChange(nil)
            return
        }
        ball?.box = Detection.convertBox(result.boundingBox)
        ball?.observation = result
        puttChangeDelegate?.ballDidChange(ball)
    }
            
    @MainActor
    func reset() {
        detections = []
        ball = nil
        hole = nil
        tee = nil
        ballTrackingRequest?.isLastFrame = true
        ballTrackingRequest = nil
    }
    
    @MainActor
    func start() {
        detecting = true
    }
    
    @MainActor
    func stop() {
        detecting = false
    }

}

extension DetectorModel: CameraOutputDelegate {

    func cameraModel(_ cameraModel: CameraModel, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        guard detecting else { return }
        
        detectionQueue.async {
            do {
                if let ball = self.ball {
                    self.ballTrackingRequest = self.ballTrackingRequest ?? VNTrackObjectRequest(detectedObjectObservation: ball.observation)
                    try self.sequenceHandler.perform([self.ballTrackingRequest!],
                                                     on: buffer,
                                                     orientation: orientation)
                    if let results = self.ballTrackingRequest?.results as? [VNDetectedObjectObservation] {
                        if let first = results.first, first.confidence > 0 {
                            self.ballTrackingRequest?.inputObservation = first
                            DispatchQueue.main.async {
                                self.processTrackingResults(results)
                            }
                        } else {
                            //print("$$$ Lost \(results)")
                        }
                    }
                } else {
                    let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer,
                                                              orientation: orientation,
                                                              options: [:])
                    try visionHandler.perform([self.objectDetectionRequest])
                    if let results = self.objectDetectionRequest.results as? [VNRecognizedObjectObservation] {
                        DispatchQueue.main.async {
                            self.processDetectionResults(results)
                        }
                    }
                }
            } catch (let err) {
                try? self.ballTrackingRequest?.completeTracking(with: self.sequenceHandler, on: buffer)
                self.ballTrackingRequest = nil
                DispatchQueue.main.async {
                    self.ball = nil
                    self.error = err
                    self.processTrackingResults(nil)
                    self.puttChangeDelegate?.ballError(err)
                    print("$$$ Error \(err)")
                }
            }
        }
    }
}
