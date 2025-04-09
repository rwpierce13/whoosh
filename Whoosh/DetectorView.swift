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

protocol BallChangeDelegate {
    func ballDidChange(_ ball: Detection?)
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
    func processTrackingResults(_ results: [VNDetectedObjectObservation]) {
        guard let result = results.first, result.confidence > 0.8 else {
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
                        DispatchQueue.main.async {
                            self.processTrackingResults(results)
                        }
                        if let first = results.first, first.confidence > 0.2 {
                            self.ballTrackingRequest?.inputObservation = first
                        } else {
                            throw NSError.errorWithMessage("Ball tracking ended")
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
                    print(err)
                }
            }
        }
    }
}


struct DetectionView: View {
    
    @EnvironmentObject var detectorModel: DetectorModel
    @EnvironmentObject var cameraModel: CameraModel
    var detection: Detection
    
    func convertedRect() -> CGRect {
        return cameraModel.convertVisionRectToCameraRect(detection.box)
    }
    
    var body: some View {
        BoundingBox(box: convertedRect())
            .stroke(detection.color, style: StrokeStyle(lineWidth: 3, lineCap: .square))
    }
}


struct BoundingBox: Shape {
    
    var box: CGRect
    
    func path(in rect: CGRect) -> Path {
        let box = UIBezierPath(rect: box)
        return Path(box.cgPath)
    }
    
}
