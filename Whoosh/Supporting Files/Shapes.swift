//
//  Shapes.swift
//  Whoosh
//
//  Created by Robert Pierce on 4/21/25.
//

import SwiftUI
import Foundation


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


struct Trajectory: Shape {
    
    var points: [CGPoint] = []
    
    func path(in rect: CGRect) -> Path {
        let trajectory = UIBezierPath.smoothPath(points)
        return Path(trajectory.cgPath)
    }
    
}
