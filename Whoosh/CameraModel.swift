//
//  CameraModel.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/25/25.
//

import SwiftUI
import UIKit
import AVKit
import Vision


protocol CameraOutputDelegate: AnyObject {
    func cameraModel(_ cameraModel: CameraModel, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation)
}

class CameraModel: NSObject, ObservableObject {
    
    weak var detectorDelegate: CameraOutputDelegate?
    weak var visionDelegate: CameraOutputDelegate?
    
    private let videoDataOutputQueue = DispatchQueue(label: "com.Woosh.VideoDataOutput", qos: .userInitiated,
                                                     attributes: [], autoreleaseFrequency: .workItem)
    private let sessionQueue = DispatchQueue(label: "com.Woosh.SessionQueue")
    var cameraSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override init() {
        super.init()
        try! setupAVSession()
        setupPreviewLayer()
    }
    
    func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoRotationAngle = 90
    }
    
    func setupAVSession() throws {
        // Create device discovery session for a wide angle camera
        let wideAngle = AVCaptureDevice.DeviceType.builtInWideAngleCamera
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [wideAngle], mediaType: .video, position: .unspecified)
        
        // Select a video device, make an input
        guard let videoDevice = discoverySession.devices.first else {
            throw AppError.captureSessionSetup(reason: "Could not find a wide angle camera device.")
        }
                
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        // We prefer a 1080p video capture but if camera cannot provide it then fall back to highest possible quality
        if videoDevice.supportsSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }
        
        try videoDevice.lockForConfiguration()
        var frameRates = Set<Double>()
        for format in videoDevice.formats {
            let ranges = format.videoSupportedFrameRateRanges
            for range in ranges {
                frameRates.insert(range.maxFrameRate)
            }
        }
        let targetFrameRate = Double(120)
        if let frameRate = frameRates.sorted().last, let format = videoDevice.formats.first(where: { $0.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= targetFrameRate } }) {
            videoDevice.activeFormat = format
            videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
            videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
        }
        videoDevice.unlockForConfiguration()
                
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        let captureConnection = dataOutput.connection(with: .video)
        captureConnection?.preferredVideoStabilizationMode = .standard
        // Always process the frames
        captureConnection?.isEnabled = true
        session.commitConfiguration()
        cameraSession = session
        
        sessionQueue.async {
            self.cameraSession?.startRunning()
        }
    }
    
    func convertVisionPointsToCameraPoint(_ points: [CGPoint]) -> [CGPoint] {
        //Flip y then convert to layerSpace
        let new = points.map { CGPoint(x: $0.x, y: 1 - $0.y) }
        return new.map { previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
    }
        
    func convertVisionRectToCameraRect(_ rect: CGRect) -> CGRect {
        //Flip y then convert to layerSpace
        let flip = CGRect(x: rect.minX,
                          y: 1 - rect.minY,
                          width: rect.width,
                          height: rect.height)
        let start = previewLayer.layerPointConverted(fromCaptureDevicePoint: flip.origin)
        let end = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: flip.maxX, y: flip.maxY))
        let size = CGSize(width: abs(end.x - start.x), height: abs(end.y - start.y))
        let new = CGRect(origin: start, size: size)
        return new
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        detectorDelegate?.cameraModel(self, didReceiveBuffer: sampleBuffer, orientation: .up)
        visionDelegate?.cameraModel(self, didReceiveBuffer: sampleBuffer, orientation: .up)
    }
}



struct CameraPreview: UIViewRepresentable {
    @EnvironmentObject var cameraModel: CameraModel
    let frame: CGRect
    //let captureBlock: ()->()
    
    func makeUIView(context: Context) -> UIView {
        let view = UIViewType(frame: frame)
        cameraModel.previewLayer.frame = frame
        view.layer.addSublayer(cameraModel.previewLayer)
        
        if #available(iOS 17.2, *) {
            let inter = AVCaptureEventInteraction { event in
                switch event.phase {
                case .ended:
                    break //captureBlock()
                default:
                    break
                }
            }
            view.addInteraction(inter)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        guard let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.frame = frame
    }
}

