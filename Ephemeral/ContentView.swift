//
//  ContentView.swift
//  Ephemeral
//
//  Created by Federica Ziaco on 23/09/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var zoom: Double = 1.0
    @State private var rotationX: Double = 0.0
    @State private var rotationY: Double = 0.0
    @State private var isSunny: Bool = true
    @State private var isDaytime: Bool = true
    @State private var immersiveEnabled: Bool = true

    var body: some View {
        ZStack {
            SpaceBackground()
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Shape that zooms and rotates on X & Y axis
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isDaytime
                        ? LinearGradient(colors: [Color.blue.opacity(0.85), Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.indigo, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 150 * zoom, height: 150 * zoom)
                    .overlay {
                        ZStack {
                            if !isDaytime {
                                NightStars()
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            if !isSunny {
                                RainOverlay()
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                        }
                    }
                    .compositingGroup()
                    .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .shadow(color: isSunny ? Color.yellow.opacity(0.6) : Color.clear, radius: 25)
                    .shadow(radius: 20)
                    .animation(.easeInOut, value: zoom)
                    .animation(.easeInOut, value: rotationX)
                    .animation(.easeInOut, value: rotationY)
            }
        }
        // The ornament floats over the immersive space
        .ornament(attachmentAnchor: .scene(.leading)){
            VStack(spacing: 20) {
                
                // Immersive Toggle (two mountains icon)
                Toggle(isOn: $immersiveEnabled) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(immersiveEnabled ? .white : .gray)
                        .accessibilityLabel("Immersive")
                }
                .frame(width: 200)

                // Zoom Slider
                VStack {
                    Text("Zoom")
                        .font(.headline)
                    Slider(value: $zoom, in: 0.5...2.0)
                        .frame(width: 200)
                }

                // Rotation X Slider
                VStack {
                    Text("Rotate X")
                        .font(.headline)
                    Slider(value: $rotationX, in: -180...180)
                        .frame(width: 200)
                }

                // Rotation Y Slider
                VStack {
                    Text("Rotate Y")
                        .font(.headline)
                    Slider(value: $rotationY, in: -180...180)
                        .frame(width: 200)
                }

                // Sunny / Rainy Buttons
                HStack(spacing: 30) {
                    Button(action: { isSunny = true }) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 28))
                            .foregroundColor(isSunny ? .yellow : .gray)
                    }
                    Button(action: { isSunny = false }) {
                        Image(systemName: "cloud.rain.fill")
                            .font(.system(size: 28))
                            .foregroundColor(!isSunny ? .blue : .gray)
                    }
                }

                // Day/Night Toggle (Sun/Moon with switch in the middle)
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(isDaytime ? .gray : .yellow)
                    Toggle("", isOn: $isDaytime)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Day or Night")
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(isDaytime ? .yellow : .gray)
                }
                .frame(width: 220)
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(25)
            .shadow(radius: 10)
        }
        .onChange(of: immersiveEnabled) { _, newValue in
            Task { @MainActor in
                if newValue {
                    _ = await openImmersiveSpace(id: "Immersive")
                } else {
                    await dismissImmersiveSpace()
                }
            }
        }
        .task { @MainActor in
            if immersiveEnabled {
                _ = await openImmersiveSpace(id: "Immersive")
            }
        }
    }
}

private struct SpaceBackground: View {
    private struct Star {
        let position: CGPoint   // normalized 0...1
        let size: CGFloat       // point size of the star
        let twinkleSpeed: Double
        let phase: Double
    }

    @State private var stars: [Star] = []
    private let starCount = 250

    var body: some View {
        ZStack {
            Color.black
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    if stars.isEmpty {
                        generateStars()
                    }

                    for star in stars {
                        let x = star.position.x * size.width
                        let y = star.position.y * size.height
                        let rect = CGRect(x: x, y: y, width: star.size, height: star.size)
                        var alpha = 0.4 + 0.6 * sin(t * star.twinkleSpeed + star.phase)
                        alpha = max(0.1, min(1.0, alpha))
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                    }
                }
            }
        }
    }

    private func generateStars() {
        var newStars: [Star] = []
        newStars.reserveCapacity(starCount)
        for _ in 0..<starCount {
            let position = CGPoint(x: .random(in: 0...1), y: .random(in: 0...1))
            let size = CGFloat.random(in: 0.5...2.5)
            let speed = Double.random(in: 0.5...2.0)
            let phase = Double.random(in: 0...(2 * .pi))
            newStars.append(Star(position: position, size: size, twinkleSpeed: speed, phase: phase))
        }
        stars = newStars
    }
}

private struct NightStars: View {
    private struct Star { let p: CGPoint; let s: CGFloat; let phase: Double; let speed: Double }
    @State private var stars: [Star] = []
    private let count = 60

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                if stars.isEmpty { generate(in: size) }
                for star in stars {
                    let rect = CGRect(x: star.p.x * size.width, y: star.p.y * size.height, width: star.s, height: star.s)
                    var a = 0.3 + 0.7 * sin(t * star.speed + star.phase)
                    a = max(0.1, min(1.0, a))
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
                }
            }
        }
    }

    private func generate(in _: CGSize) {
        var arr: [Star] = []
        arr.reserveCapacity(count)
        for _ in 0..<count {
            arr.append(Star(p: CGPoint(x: .random(in: 0...1), y: .random(in: 0...1)), s: CGFloat.random(in: 0.8...2.0), phase: Double.random(in: 0...(2 * .pi)), speed: Double.random(in: 0.5...1.5)))
        }
        stars = arr
    }
}

private struct RainOverlay: View {
    private struct Drop { var x: CGFloat; var y: CGFloat; var len: CGFloat; var speed: CGFloat }
    @State private var drops: [Drop] = []
    private let count = 80

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                if drops.isEmpty { generate(in: size) }
                var path = Path()
                for i in 0..<drops.count {
                    let d0 = drops[i]
                    let y = (d0.y + CGFloat(t).truncatingRemainder(dividingBy: 1) * d0.speed * size.height).truncatingRemainder(dividingBy: size.height + d0.len)
                    let start = CGPoint(x: d0.x * size.width, y: y)
                    let end = CGPoint(x: start.x, y: y + d0.len)
                    path.move(to: start)
                    path.addLine(to: end)
                }
                ctx.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
            }
        }
    }

    private func generate(in _: CGSize) {
        var arr: [Drop] = []
        arr.reserveCapacity(count)
        for _ in 0..<count {
            arr.append(Drop(x: .random(in: 0...1), y: .random(in: 0...1), len: .random(in: 6...18), speed: .random(in: 0.4...1.0)))
        }
        drops = arr
    }
}

#Preview {
    ContentView()
}
