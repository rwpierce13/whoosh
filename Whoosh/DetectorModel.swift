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
    
    var color: Color = Color.randomColor()
    var type: DetectionType {
        .init(label: labels.first ?? "")
    }
    
    init(observation: VNRecognizedObjectObservation) {
        self.id = observation.uuid.uuidString
        self.box = observation.boundingBox
        self.labels = observation.labels.map { $0.identifier }
        self.observation = observation
        self.color = type.color()
    }
}


//MARK: -
struct DetectionCollection: Identifiable {
    var id: UUID = UUID()
    var detections: [Detection] = []
    var velocities: [CGFloat] = []
    
    private let MinimumMovingVelocity = 1e-3
    private let StationaryCount = 4
    private let MinumumDistance = 5e-4

    var color: Color {
        if let first = detections.first {
            return first.color
        }
        return .blue
    }
    
    func endIsStationary() -> Bool {
        guard velocities.count > StationaryCount else { return false }
        let endVelocities = velocities.suffix(StationaryCount)
        if endVelocities.contains(where: { abs($0) > MinimumMovingVelocity }) {
            return false
        }
        return true
    }
    
    func calcLastVelocity() -> CGFloat? {
        let lastIndex = detections.count - 1
        let secondLastIndex = detections.count - 2
        guard lastIndex > 0, secondLastIndex >= 0 else { return nil }
        let lastDet = detections[lastIndex]
        let secondLastDet = detections[secondLastIndex]
        let dt = lastDet.observation.timeRange.start.seconds - secondLastDet.observation.timeRange.start.seconds
        let distance = lastDet.box.center.distance(to: secondLastDet.box.center)
        if distance <= MinumumDistance {
            return 0
        }
        let velocity = distance / CGFloat(dt)
        return velocity
    }
    
    func didStart() -> Bool {
        return velocities.filter { $0 > MinimumMovingVelocity }.count >= StationaryCount
    }
    
    func didEnd() -> Bool {
        return didStart() && endIsStationary()
    }
}



//MARK: -
protocol BallChangeDelegate {
    func ballDidChange(_ ball: Detection?)
    func ballError(_ error: Error?)
}

class DetectorModel: NSObject, ObservableObject {
    
    var ballChangeDelegate: BallChangeDelegate?
    var detections: [Detection] = []
    @Published var ball: Detection?
    @Published var hole: Detection?
    @Published var tee: Detection?
    @Published var error: Error?
    
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
        // Since board is close to the side of a landscape image,
        // we need to set crop and scale option to scaleFit.
        // By default vision request will run on centerCrop.
        objectDetectionRequest.imageCropAndScaleOption = .scaleFit
    }
    
    @MainActor
    func processDetectionResults(_ results: [VNRecognizedObjectObservation]) {
        var newDetections: [Detection] = []
        for result in results { //where result.confidence > minConfidence {
            if var det = detections.first(where: { $0.id == result.uuid.uuidString }) {
                det.box = result.boundingBox
                newDetections.append(det)
            } else {
                newDetections.append(Detection(observation: result))
            }
        }
        detections = newDetections
        
        let balls = detections.filter { $0.type == .ball }
        ball = balls.first
        let holes = detections.filter { $0.type == .hole }
        hole = holes.first
        let tees = detections.filter { $0.type == .tee }
        tee = tees.first
    }
    
    @MainActor
    func processTrackingResults(_ results: [VNDetectedObjectObservation]?) {
        guard let result = results?.first, result.confidence > 0.1 else {
            ballChangeDelegate?.ballDidChange(nil)
            return
        }
        ball?.box = result.boundingBox
        ball?.observation = result
        ballChangeDelegate?.ballDidChange(ball)
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

}

extension DetectorModel: CameraOutputDelegate {

    func cameraModel(_ cameraModel: CameraModel, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        
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
                            print("$$$ Lost \(results)")
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
                    self.ballChangeDelegate?.ballError(err)
                    print("$$$ Error \(err)")
                }
            }
        }
    }
}
