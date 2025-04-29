//
//  ScoreView.swift
//  Whoosh
//
//  Created by Robert Pierce on 4/22/25.
//

import SwiftUI



enum Distance: String {
    case good, long, short
}

enum Aim: String {
    case straight, right, left
}

struct Score {
    
    var putt: DetectionCollection
    var distance: Distance?
    var aim: Aim?
    var read: Aim?
    var value: Int = 0
    
    init(putt: DetectionCollection) {
        self.putt = putt
        self.distance = putt.ballStopDistance()
        self.aim = putt.aim()
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
        if read == .straight {
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
        ScrollView {
            VSStack {
                Text("Game State: \(gameModel.state.statusText)")
                    .padding(.bottom, 5)
                Text("Aim: \(score?.aim?.rawValue ?? "None")")
                    .padding(.bottom, 5)
                Text("Distance: \(score?.distance?.rawValue ?? "None")")
                    .padding(.bottom, 5)
                Text("Read: \(score?.read?.rawValue ?? "None")")
                    .padding(.bottom, 5)
                Text("Score: \(score?.value ?? 0)/4")
                    .padding(.bottom, 40)
                ZStack {
                    if let image = gameModel.finalImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            //.border(Color.white, width: 1)
                            .background {
                                BackgroundRectReader { rect in
                                    print("$$$ Image \(rect)")
                                }
                            }
                    }
                    if let putt = score?.putt {
                        TrajectoryView(collection: putt, contentMode: .fit)
                            //.border(Color.yellow, width: 1)
                            .background {
                                BackgroundRectReader { rect in
                                    print("$$$ Traj \(rect)")
                                }
                            }
                    }
                }
                .clipped()
                .frame(height: 270)
                .cornerRadius(10)
                .padding(.bottom, 40)
                
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
            .padding(.horizontal, 40)
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
}
