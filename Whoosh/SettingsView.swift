
//
//  Settings.swift
//  Whoosh
//
//  Created by Robert Pierce on 4/29/25.
//

import SwiftUI
import Foundation


struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Keys.UseTestHole.rawValue) var useTestHole = false
    @AppStorage(Keys.UseTestTee.rawValue) var useTestTee = false
    
    var body: some View {
        ScrollView {
            VSStack {
                Toggle(isOn: $useTestHole) {
                    Text("Use Test Hole")
                        .font(Font.system(size: 16, weight: .regular))
                }
                .padding(.vertical, 5)
                Divider().padding(.bottom, 10)
                Toggle(isOn: $useTestTee) {
                    Text("Use Test Tee")
                        .font(Font.system(size: 16, weight: .regular))

                }
                .padding(.vertical, 5)
                Divider().padding(.bottom, 10)
            }
            .padding(.horizontal, 20)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(Font.system(size: 19, weight: .semibold))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "x.circle.fill")
                        .fitTo(height: 32)
                }
            }
        }
        .toolbarTitleDisplayMode(.inline)
    }
}


enum Keys: String {
    
    case UseTestHole = "useTestHole"
    case UseTestTee = "useTestTee"
    
    
}
