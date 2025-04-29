//
//  ScoreView.swift
//  Whoosh
//
//  Created by Robert Pierce on 4/22/25.
//

import SwiftUI


enum Distance: String {
    case good, long, short
    
    var readable: String {
        return rawValue.capitalized
    }
}

enum Aim: String {
    case straight, right, left
    
    var readable: String {
        return rawValue.capitalized
    }
}

enum Read: String {
    case good, right, left
    
    var readable: String {
        return rawValue.capitalized
    }
}

struct Score {
    
    var putt: DetectionCollection
    var distance: Distance?
    var aim: Aim?
    var read: Read?
    var value: Int = 0
    var maxValue: Int = 4
    
    init(putt: DetectionCollection) {
        self.putt = putt
        self.distance = putt.ballStopDistance()
        self.aim = putt.aim()
        self.read = putt.read()
        self.value = calcValue()
    }
    
    func calcValue() -> Int {
        var value = 0
        if distance == .good {
            value += 1
        }
        if aim == .straight {
            value += 1
        }
        if read == .good {
            value += 1
        }
        if value == maxValue - 1 {
            value += 1
        }
        return value
    }
}


struct ScoreView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gameModel: GameModel
    @State var score: Score?
    
    var body: some View {
        VSStack {
            ScrollView {
                VSStack {
                    HSStack(alignment: .top) {
                        Spacer()
                        VSStack {
                            Text("Score")
                                .semiBoldFont(24)
                                .padding(.bottom, 20)
                            HSStack {
                                Text("Aim")
                                    .regularFont(16)
                                Spacer(minLength: 40)
                                Text("\(score?.aim?.readable ?? "None")")
                                    .foregroundStyle(.green)
                                    .semiBoldFont(20)
                            }
                            .padding(.bottom, 10)
                            HSStack {
                                Text("Dist.")
                                    .regularFont(16)
                                Spacer(minLength: 40)
                                Text("\(score?.distance?.readable ?? "None")")
                                    .foregroundStyle(.green)
                                    .semiBoldFont(20)
                            }
                            .padding(.bottom, 10)
                            HSStack {
                                Text("Read")
                                    .regularFont(16)
                                Spacer(minLength: 40)
                                Text("\(score?.read?.readable ?? "None")")
                                    .foregroundStyle(.green)
                                    .semiBoldFont(20)
                            }
                            .padding(.bottom, 10)
                            HSStack {
                                Text("Score")
                                    .regularFont(16)
                                Spacer(minLength: 40)
                                Text("\(score?.value ?? 0) / \(score?.maxValue ?? 0)")
                                    .foregroundStyle(.green)
                                    .semiBoldFont(20)
                            }
                            Spacer()
                        }
                        .fixedSize()
                        
                        Spacer(minLength: 20)
                        
                        VSStack {
                            if let image = gameModel.finalImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .overlay {
                                        if let putt = score?.putt {
                                            TrajectoryView(collection: putt)
                                        }
                                    }
                                    .clipped()
                                    .frame(height: 350)
                                    .cornerRadius(10)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(20)
            }
            
            Spacer()
            bottomButtons()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "x.circle.fill")
                        .fitTo(height: 32)
                }
            }
        }
        .onAppear {
            if let putt = gameModel.putt {
                score = Score(putt: putt)
            }
        }
    }
    
    @ViewBuilder
    func bottomButtons() -> some View {
        Button {
            gameModel.reset()
            dismiss()
        } label: {
            HSStack {
                Image(systemName: "mappin.and.ellipse")
                    .fitTo(height: 24)
                    .foregroundStyle(.white)
                    .padding(.trailing, 20)
                Text("Putt Again")
                    .font(Font.system(size: 20))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(.green)
            .cornerRadius(10)
        }
        .padding(.bottom, 20)
        Button {
            if let putt = gameModel.putt {
                score = Score(putt: putt)
            }
        } label: {
            Text("Recalculate")
        }
        .padding(.bottom, 40)
    }
}
