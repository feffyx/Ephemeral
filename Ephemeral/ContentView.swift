//
//  ContentView.swift
//  Ephemeral
//
//  Created by Federica Ziaco on 23/09/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    // MARK: - State
    @State private var zoom: Double = 1.0
    @State private var rotationX: Double = 0.0
    @State private var rotationY: Double = 0.0
    @State private var isSunny: Bool = true
    @State private var isDaytime: Bool = true
    @State private var immersiveEnabled: Bool = true

    var body: some View {
        ZStack {
            // Optional background — uncomment if you want it
            // SpaceBackground().ignoresSafeArea()
            
            Model3D(named:"lowpoly",bundle: realityKitContentBundle)
            VStack(spacing: 40) {
                // RealityKit view with proper update pattern
                RealityView { content in
                    // Initial load
                    loadSceneDirectly(into: content)
                } update: { content in
                    // Update when state changes
                    content.entities.removeAll()
                    loadSceneDirectly(into: content)
                }
                .frame(width: 400, height: 400)
                .scaleEffect(zoom)
                .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .shadow(color: isSunny ? Color.yellow.opacity(0.6) : .clear, radius: 25)
                .animation(.easeInOut, value: zoom)
                .animation(.easeInOut, value: rotationX)
                .animation(.easeInOut, value: rotationY)
            }
        }
        // Ornament (floating controls)
        .ornament(attachmentAnchor: .scene(.leading)) {
            controlPanel
        }
        // Immersive space handlers
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

    // MARK: - Control Panel View
    private var controlPanel: some View {
        VStack(spacing: 20) {
            // Immersive Toggle
            Toggle(isOn: $immersiveEnabled) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(immersiveEnabled ? .white : .gray)
                    .accessibilityLabel("Immersive")
            }
            .frame(width: 200)

            // Zoom
            VStack {
                Text("Zoom").font(.headline)
                Slider(value: $zoom, in: 0.5...2.0)
                    .frame(width: 200)
            }

            // Rotate X
            VStack {
                Text("Rotate X").font(.headline)
                Slider(value: $rotationX, in: -180...180)
                    .frame(width: 200)
            }

            // Rotate Y
            VStack {
                Text("Rotate Y").font(.headline)
                Slider(value: $rotationY, in: -180...180)
                    .frame(width: 200)
            }

            // Sunny / Rainy
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

            // Day / Night toggle
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

    // MARK: - Scene loading
    private func loadSceneDirectly(into content: RealityViewContent) {
        let sceneName = isDaytime ? "daytimeworld" : "nighttimeworld"
        print("🌍 Loading scene:", sceneName)
        print("📦 Bundle:", realityKitContentBundle)
        
        Task {
            do {
                let entity = try await Entity(named: sceneName, in: realityKitContentBundle)
                print("📏 Entity bounds:", entity.visualBounds(relativeTo: nil))
                print("📍 Entity position:", entity.position)
                print("📐 Entity scale:", entity.scale)
                
                // Adjust position and scale for better visibility
                entity.position = [0, 0, -0.5] // Move back from camera
                entity.scale = [1, 1, 1] // Try full size first
                
                // Add basic lighting
                let light = DirectionalLight()
                light.light.intensity = 1000
                light.position = [0, 2, 1]
                light.look(at: [0, 0, 0], from: light.position, relativeTo: nil)
                
                await MainActor.run {
                    content.add(entity)
                    content.add(light)
                    print("✅ Added to content. Total entities:", content.entities.count)
                }
                
            } catch {
                print("❌ Error loading scene '\(sceneName)':", error.localizedDescription)
            }
        }
    }
}

// Optional preview
#Preview {
    ContentView()
}
