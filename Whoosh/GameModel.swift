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
    
    //Normalized points
    let circle: (CGPoint, CGFloat) = (CGPoint(x: 0.5, y: 0.85), 0.05)
    let vLine: (CGPoint, CGPoint) = (CGPoint(x: 0.5, y: 0.81), CGPoint(x: 0.5, y: 0.15))
    let crossV: (CGPoint, CGPoint) = (CGPoint(x: 0.5, y: 0.84), CGPoint(x: 0.5, y: 0.86))
    let crossH: (CGPoint, CGPoint) = (CGPoint(x: 0.48, y: 0.85), CGPoint(x: 0.52, y: 0.85))
    
    func record() {
        state = .recording
        putt = DetectionCollection()
    }
    
    func finish() {
        state = .done
    }
    
    func reset() {
        state = .initial
        putt = nil
    }
    
    func ballInCircle(_ ball: Detection) -> Bool {
        let convertedBallCenter = CGPoint(x: 1 - ball.box.center.y, y: ball.box.center.x)
        return convertedBallCenter.isNear(circle.0, tolerance: 0.02)
    }
    
    func puttDidEnd() -> Bool {
        return putt?.didEnd() ?? false
    }
    
    func puttDidStart() -> Bool {
        return putt?.didStart() ?? false
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
        
        guard let col = putt else { return }
        var newCol = col
        newCol.detections.append(b)
        if let vel = newCol.calcLastVelocity() {
            newCol.velocities.append(vel)
        }
        putt = newCol
    }
    
    func ballError(_ error: (any Error)?) {
        state = .error
    }
}
