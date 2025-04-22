//
//  Views.swift
//  Whoosh
//
//  Created by Robert Pierce on 4/21/25.
//

import SwiftUI
import Foundation


struct VSStack<Content>: View where Content: View {
    private var content: Content
    private var alignment: HorizontalAlignment
    private var spacing: Double
    
    init(alignment: HorizontalAlignment = .center, spacing: Double = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
        self.spacing = spacing
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
    }
}


struct HSStack<Content>: View where Content : View {
    private var content: Content
    private var alignment: VerticalAlignment
    private var spacing: Double
    
    init(alignment: VerticalAlignment = .center, spacing: Double = 0, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
    }
}

struct SSpacer: View {
    var body: some View {
        Spacer(minLength: 0)
    }
}

struct Center<Content>: View where Content : View {
    private var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VSStack {
            SSpacer()
            HSStack {
                SSpacer()
                content
                SSpacer()
            }
            SSpacer()
        }
    }
}
