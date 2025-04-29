//
//  Extensions.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/25/25.
//

import SwiftUI
import Foundation
import Vision
import CoreGraphics


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
    
    func isNear(_ rect: CGRect, tolerance: CGFloat = 0.1) -> Bool {
        return center.isNear(rect.center, tolerance: tolerance)
    }
    
    var aspectRatio: CGFloat {
        return width / height
    }
    
    var maxPoint: CGPoint {
        return CGPoint(x: maxX, y: maxY)
    }
    
    func scale(by factor: CGFloat) -> CGRect {
        return CGRect(x: minX * factor, y: minY * factor, width: width * factor, height: height * factor)
    }
}

extension CGPoint {
    
    func isNear(_ point: CGPoint, tolerance: CGFloat = 0.1) -> Bool {
        return distance(to: point) < tolerance
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


extension Image {
    
    func fitTo(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
    }
    
    func fillTo(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
    }
    
}


extension View {

    public var bottomSafeArea: CGFloat {
        let window = UIApplication.shared.windows.first
        let bottomPadding = window?.safeAreaInsets.bottom ?? 0
        return bottomPadding
    }
    
    public var topSafeArea: CGFloat {
        let window = UIApplication.shared.windows.first
        let topPadding = window?.safeAreaInsets.top ?? 0
        return topPadding
    }
    
    func glow(color: Color = .green, radius: CGFloat = 10) -> some View {
        self
            .shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
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


extension Color {
    
    // MARK: - Text Colors
    static let lightText = Color(UIColor.lightText)
    static let darkText = Color(UIColor.darkText)
    static let placeholderText = Color(UIColor.placeholderText)
    
    // MARK: - Label Colors
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    static let quaternaryLabel = Color(UIColor.quaternaryLabel)
    
    // MARK: - Background Colors
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)
    
    // MARK: - Fill Colors
    static let systemFill = Color(UIColor.systemFill)
    static let secondarySystemFill = Color(UIColor.secondarySystemFill)
    static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)
    static let quaternarySystemFill = Color(UIColor.quaternarySystemFill)
    
    // MARK: - Grouped Background Colors
    static let systemGroupedBackground = Color(UIColor.systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground = Color(UIColor.tertiarySystemGroupedBackground)
    
    // MARK: - Gray Colors
    static let systemGray = Color(UIColor.systemGray)
    static let systemGray2 = Color(UIColor.systemGray2)
    static let systemGray3 = Color(UIColor.systemGray3)
    static let systemGray4 = Color(UIColor.systemGray4)
    static let systemGray5 = Color(UIColor.systemGray5)
    static let systemGray6 = Color(UIColor.systemGray6)
    
    // MARK: - Other Colors
    static let separator = Color(UIColor.separator)
    static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    static let link = Color(UIColor.link)
    
    // MARK: System Colors
    static let systemBlue = Color(UIColor.systemBlue)
    static let systemPurple = Color(UIColor.systemPurple)
    static let systemGreen = Color(UIColor.systemGreen)
    static let systemYellow = Color(UIColor.systemYellow)
    static let systemOrange = Color(UIColor.systemOrange)
    static let systemPink = Color(UIColor.systemPink)
    static let systemRed = Color(UIColor.systemRed)
    static let systemTeal = Color(UIColor.systemTeal)
    static let systemIndigo = Color(UIColor.systemIndigo)
    
}


extension Font {
    
    static func regular(_ size: CGFloat) -> Font {
        return Font.system(size: size, weight: .regular)
    }
    
    static func semiBold(_ size: CGFloat) -> Font {
        return Font.system(size: size, weight: .semibold)
    }
    
    static func bold(_ size: CGFloat) -> Font {
        return Font.system(size: size, weight: .bold)
    }

}


extension Text {
    
    func regularFont(_ size: CGFloat) -> Text {
        return self.font(Font.regular(size))
    }
    
    func semiBoldFont(_ size: CGFloat) -> Text {
        return self.font(Font.semiBold(size))
    }
    
    func boldFont(_ size: CGFloat) -> Text {
        return self.font(Font.bold(size))
    }
    
}
