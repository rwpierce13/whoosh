//
//  MainApp.swift
//  Whoosh
//
//  Created by Robert Pierce on 2/24/25.
//

import SwiftUI

@main
struct MainApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
