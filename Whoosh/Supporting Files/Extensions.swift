//
//  Extensions.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/25/25.
//

import SwiftUI
import Foundation
import Vision


extension VNTrackingRequest {
    
    func completeTracking(with handler: VNSequenceRequestHandler, on sampleBuffer: CMSampleBuffer) throws {
        isLastFrame = true
        try handler.perform([self], on: sampleBuffer)
    }
}


extension NSError {
    class func errorWithMessage(_ message: String, domain: String = "", code: Int = 0) -> Error {
        return NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey : message]) as Error
    }
    
    class func errorForErrors(_ errors: [Error]) -> Error {
        var msg = ""
        for err in errors {
            msg += "\(err.localizedDescription)\n"
        }
        return NSError.errorWithMessage(msg)
    }
}


extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}


extension Color {
    
    static func randomColor() -> Color {
        let r = Double(arc4random_uniform(256)) / 255.0
        let b = Double(arc4random_uniform(256)) / 255.0
        let g = Double(arc4random_uniform(256)) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}


extension UIBezierPath {
    
    static func line(for points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard points.count > 1 else { return path }
        path.move(to: points.first!)
        for p in points {
            path.addLine(to: p)
        }
        return path
    }
    
    static func quadCurvedPath(_ points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard var p0 = points.first else {
            return path
        }
        path.move(to: p0)
        
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        
        for p1 in points {
            let mid = midPointFor(p0, p1)
            path.addQuadCurve(to: mid, controlPoint: controlPointFor(mid, p0))
            path.addQuadCurve(to: p1, controlPoint: controlPointFor(mid, p1))
            p0 = p1
        }
        return path;
    }
    
    static func midPointFor(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2);
    }

    static func controlPointFor(_ p1: CGPoint,_ p2: CGPoint) -> CGPoint {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.x
        let angle = atanl(dy / dx)
        
        var controlPoint = midPointFor(p1, p2)
        let dist = p1.distance(to: p2)

        if p1.y < p2.y {
            controlPoint.x += dist * cosl(angle)
            controlPoint.y += dist * sinl(angle)
        } else {
            controlPoint.x -= dist * cosl(angle)
            controlPoint.y -= dist * sinl(angle)
        }
        return controlPoint;
    }
    
    static func smoothPath(_ points: [CGPoint]) -> UIBezierPath {
        let config = BezierConfiguration()
        let controlPoints = config.configureControlPoints(data: points)
        let path = UIBezierPath()
        for (i, point) in points.enumerated() {
            if i == 0 {
                path.move(to: point)
            } else {
                let segment = controlPoints[i - 1]
                path.addCurve(to: point, controlPoint1: segment.firstControlPoint, controlPoint2: segment.secondControlPoint)
            }
        }
        return path
    }
    
    func overlapsPath(_ pos: CGPoint, toleranceWidth: CGFloat = 2.0) -> Bool {
        let pathRef = cgPath.copy(strokingWithWidth: toleranceWidth, lineCap: CGLineCap.butt, lineJoin: CGLineJoin.round, miterLimit: 0)
        let pathRefMutable = pathRef.mutableCopy()
        if let p = pathRefMutable {
            p.closeSubpath()
            return p.contains(pos)
        }
        return false
    }
    
}
