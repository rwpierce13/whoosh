//
//  ScannerView.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/25/25.
//

import ARKit
import SwiftUI
import RealityKit


struct ScannerView: UIViewRepresentable {
    
    typealias UIViewType = ScanningARView
    
    var onSave: ()->()

    func makeUIView(context: Context) -> ScanningARView {
        let arView = ScanningARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: true)
        arView.setupForTesting()
        arView.delegate = context.coordinator
        return arView
    }
    
    func updateUIView(_ uiView: ScanningARView, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, ScanningARViewDelegate {
        var parent: ScannerView
        
        init(parent: ScannerView) {
            self.parent = parent
        }
    }
}


protocol ScanningARViewDelegate: AnyObject {
    
}
class ScanningARView: ARView {
    
    var delegate: ScanningARViewDelegate?
    var anchorEntity = AnchorEntity()
    var turtle: Turtle?
    
    func setupForTesting() {
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "Whoosh", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        configuration.detectionObjects = referenceObjects
        session.run(configuration)
        session.delegate = self
    }
        
    override func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        print("$$$ UPDATE \(anchors)")
        
        for anchor in anchors {
            if let obj = anchor as? ARObjectAnchor {
                if let turt = turtle {
                    turt.update(with: obj)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        //print("$$$ FRAME \(frame)")
        switch(frame.camera.trackingState) {
        case .normal:
            break
        case .limited(let reason):
            break
        case .notAvailable:
            break
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        print("$$$ ADD \(anchors)")
        for anchor in anchors {
            if let obj = anchor as? ARObjectAnchor {
                turtle = Turtle(obj)
                anchorEntity.addChild(turtle!)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        print("$$$ REMOVE \(anchors)")
    }
    
    
        
}


class Turtle: Entity {
    
    var children: [Entity] = []
    
    required init(_ anchor: ARObjectAnchor) {
        super.init()
        
        let child = self.createOriginEntity(radius: 0.1)
        children.append(child)
        self.addChild(child)
        self.update(with: anchor)
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    func update(with anchor: ARObjectAnchor) {
        self.setTransformMatrix(anchor.transform, relativeTo: nil)
    }
    
    private func createOriginEntity(radius: Float, color: UIColor = .white) -> Entity {
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        return entity
    }
    
}
