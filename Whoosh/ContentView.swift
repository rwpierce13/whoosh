//
//  ContentView.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/24/25.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    
    var body: some View {
        NavigationView {
            VisionView()
                .edgesIgnoringSafeArea(.all)
        }
    }
}
