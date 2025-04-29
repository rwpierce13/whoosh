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


struct BackgroundRectReader: View {
    var coordinateSpaceName: String?
    var onChange: (CGRect)->()
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    if let name = coordinateSpaceName {
                        onChange(geo.frame(in: .named(name)))
                    } else {
                        onChange(geo.frame(in: .global))
                    }
                }
                .onChange(of: geo.size) {
                    if let name = coordinateSpaceName {
                        onChange(geo.frame(in: .named(name)))
                    } else {
                        onChange(geo.frame(in: .global))
                    }
                }
                .onChange(of: geo.frame(in: .global)) {
                    if let name = coordinateSpaceName {
                        onChange(geo.frame(in: .named(name)))
                    } else {
                        onChange(geo.frame(in: .global))
                    }
                }
        }
    }
}


struct VSpacer: View {
    
    @State var height: CGFloat
    
    init(_ height: CGFloat) {
        self.height = height
    }
    
    var body: some View {
        Spacer().frame(height: height)
    }
    
}

struct HSpacer: View {
    
    @State var width: CGFloat
    
    init(_ width: CGFloat) {
        self.width = width
    }
    
    var body: some View {
        Spacer().frame(width: width)
    }
    
}
