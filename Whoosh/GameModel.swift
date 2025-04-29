//
//  GameModel.swift
//  Whoosh
//
//  Created by Robert Pierce on 4/22/25.
//

import SwiftUI
import Foundation


enum GameState {
    case initial, ready, recording, done, error
    
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
        case .error:
            return "Error"
        }
    }
}


//MARK: -
class GameModel: ObservableObject {
    
    @Published var state: GameState = .initial
    @Published var putt: DetectionCollection?
    @Published var showSuccess = false
    @Published var finalImage: UIImage?
    var visionConversionRect: CGRect?
    var hole: Detection?
    var tee: Detection?
    
    //Normalized points
    let circle: (CGPoint, CGFloat) = (CGPoint(x: 0.5, y: 0.85), 0.05)
    let vLine: (CGPoint, CGPoint) = (CGPoint(x: 0.5, y: 0.81), CGPoint(x: 0.5, y: 0.15))
    let crossV: (CGPoint, CGPoint) = (CGPoint(x: 0.5, y: 0.84), CGPoint(x: 0.5, y: 0.86))
    let crossH: (CGPoint, CGPoint) = (CGPoint(x: 0.48, y: 0.85), CGPoint(x: 0.52, y: 0.85))
    
    func record() {
        guard let conversionRect = visionConversionRect else {
            state = .error
            return
        }
        state = .recording
        putt = DetectionCollection(conversionRect: conversionRect,
                                   holeDetection: hole,
                                   teeDetection: tee)
    }
    
    func finish() {
        state = .done
    }
    
    func reset() {
        state = .initial
        putt = nil
    }
    
    func ballInCircle(_ ball: Detection) -> Bool {
        return ball.box.center.isNear(circle.0, tolerance: 0.02)
    }
    
    func puttDidEnd() -> Bool {
        return putt?.didEnd() ?? false
    }
    
    func puttDidStart() -> Bool {
        return putt?.didStart() ?? false
    }
}


//MARK: - Coordinate Conversion
extension GameModel {
    static func convert(_ points: [CGPoint], to viewRect: CGRect, with conversionRect: CGRect) -> [CGPoint] {
        return points.map { convert($0, to: viewRect, with: conversionRect) }
    }
    
    static func convert(_ point: CGPoint, to viewRect: CGRect, with conversionRect: CGRect) -> CGPoint {
        //De-normalize points to values that we know are correct
        var x = point.x * conversionRect.width
        var y = point.y * conversionRect.height
                
        if conversionRect.aspectRatio > viewRect.aspectRatio {
            //Fit to height
            //Find ratio to resize
            let ratio = viewRect.height / conversionRect.height
            x *= ratio
            y *= ratio
            
            //Center new view inside conversionRect
            let convertedRect = conversionRect.scale(by: ratio)
            let shift = (convertedRect.width - viewRect.width) / 2
            if ratio >= 1 {
                x -= shift
            } else {
                x += shift
            }
        } else {
            //Fit to width
            //Find ratio to resize
            let ratio = viewRect.width / conversionRect.width
            x *= ratio
            y *= ratio
            
            //Center new view inside conversionRect
            let convertedRect = conversionRect.scale(by: ratio)
            let shift = (convertedRect.height - viewRect.height) / 2
            if ratio >= 1 {
                y -= shift
            } else {
                y += shift
            }
        }
            
        return CGPoint(x: x, y: y)
    }
    
    static func convert(_ rect: CGRect, to viewRect: CGRect, with conversionRect: CGRect) -> CGRect {
        let origin = convert(rect.origin, to: viewRect, with: conversionRect)
        let max = convert(rect.maxPoint, to: viewRect, with: conversionRect)
        return CGRect(origin: origin, size: CGSize(width: max.x - origin.x, height: max.y - origin.y))
    }
    
    static func convert(_ rects: [CGRect], to viewRect: CGRect, with conversionRect: CGRect) -> [CGRect] {
        return rects.map { convert($0, to: viewRect, with: conversionRect) }
    }
}


//MARK: - BallChangeDelegate
extension GameModel: BallChangeDelegate {
    
    func ballDidChange(_ ball: Detection?) {
        guard let b = ball else {
            if state == .recording {
                state = .done
            }
            return
        }
        
        switch state {
        case .initial:
            if ballInCircle(b) {
                state = .ready
            }
        case .ready:
            if !ballInCircle(b) {
                state = .initial
            }
        case .recording:
            if puttDidEnd() {
                state = .done
            }
        case .done, .error:
            return
        }
        
        guard var new = putt else { return }
        new.ballDetections.append(b)
        if let vel = new.calcLastVelocity() {
            new.ballVelocities.append(vel)
        }
        putt = new
    }
    
    func ballError(_ error: (any Error)?) {
        state = .error
    }
    
    func holeDidChange(_ hole: Detection?) {
        self.hole = hole
        guard var new = putt else { return }
        new.holeDetection = hole
        putt = new
    }
    
    func teeDidChange(_ tee: Detection?) {
        self.tee = tee
        guard var new = putt else { return }
        new.teeDetection = tee
        putt = new
    }
}
