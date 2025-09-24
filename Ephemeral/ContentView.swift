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
    // MARK: - Environment
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    // MARK: - State
    @State private var zoom: Double = 1.0
    @State private var rotationX: Double = 0.0
    @State private var rotationY: Double = 0.0
    @State private var isSunny: Bool = true
    @State private var isDaytime: Bool = true
    @State private var immersiveEnabled: Bool = false  // Controls immersive background toggle

    // RealityKit content and current loaded entity
    @State private var realityContent: RealityViewContent?
    @State private var currentEntity: Entity?

    var body: some View {
        ZStack {
            // 🌌 Immersive space background (starfield)
            if immersiveEnabled {
                ImmersiveBlackSpace()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // 🌍 Main model view
            VStack(spacing: 40) {
                RealityView { content in
                    realityContent = content
                    loadSceneDirectly(into: content)
                }
                .frame(width: 400, height: 400)
                .shadow(color: isSunny ? Color.yellow.opacity(0.6) : .clear, radius: 25)
            }
        }
        // Floating control panel
        .ornament(attachmentAnchor: .scene(.leading)) {
            controlPanel
        }

        // Toggle immersive starfield when mountain icon is tapped
        .onChange(of: immersiveEnabled) { _, newValue in
            Task { @MainActor in
                if newValue {
                    // Enter immersive space
                    _ = await openImmersiveSpace(id: "Immersive")
                } else {
                    // Exit immersive space
                    await dismissImmersiveSpace()
                }
            }
        }
        .task { @MainActor in
            // Launch in non-immersive mode by default
            if immersiveEnabled {
                _ = await openImmersiveSpace(id: "Immersive")
            }
        }

        // Swap model when day/night toggle changes
        .onChange(of: isDaytime) { _, _ in
            guard let content = realityContent else { return }

            if let entity = currentEntity {
                entity.removeFromParent()
            }
            loadSceneDirectly(into: content)
        }

        // Update transforms dynamically when sliders move
        .onChange(of: zoom) { _, _ in updateEntityTransform() }
        .onChange(of: rotationX) { _, _ in updateEntityTransform() }
        .onChange(of: rotationY) { _, _ in updateEntityTransform() }
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 20) {
            // Immersive Background Toggle
            Toggle(isOn: $immersiveEnabled) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(immersiveEnabled ? .white : .gray)
                    .accessibilityLabel("Immersive Starfield")
            }
            .frame(width: 200)

            Divider().padding(.vertical, 8)

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

            // Sunny / Rainy toggle
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
                    .foregroundStyle(!isDaytime ? .yellow : .gray)
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
        .shadow(radius: 50)
    }

    // MARK: - Load Scene
    private func loadSceneDirectly(into content: RealityViewContent) {
        let sceneName = isDaytime ? "daytimeworld" : "nighttimeworld"
        print("Loading scene:", sceneName)

        Task {
            do {
                let modelEntity = try await Entity(named: sceneName, in: realityKitContentBundle)

                await MainActor.run {
                    // Create a container to center the model
                    let container = Entity()

                    // Calculate the center pivot of the model
                    let bounds = modelEntity.visualBounds(relativeTo: nil)
                    let center = bounds.center
                    modelEntity.position = -center // Ensure pivot is centered

                    // Add model to container
                    container.addChild(modelEntity)
                    
                    // Position of the container
                    container.position = [-0.1, 0, -0.1] // x, y, z

                    // Save and add container
                    currentEntity = container
                    content.add(container)

                    // Basic directional light
                    let light = DirectionalLight()
                    light.light.intensity = 1000
                    light.position = [0, 2, 1]
                    light.look(at: [0, 0, 0], from: light.position, relativeTo: nil)
                    content.add(light)

                    print("Added entity:", sceneName)
                }
            } catch {
                print("Error loading scene '\(sceneName)':", error.localizedDescription)
            }
        }
    }

    // MARK: - Update Transform
    private func updateEntityTransform() {
        guard let entity = currentEntity else { return }

        // Apply zoom (scaling)
        let zoomScale = Float(zoom)
        entity.scale = [zoomScale, zoomScale, zoomScale]

        // Convert degrees to radians
        let rotationXRad = Float(rotationX * .pi / 180)
        let rotationYRad = Float(rotationY * .pi / 180)

        // Combine rotations
        let rotation = simd_mul(
            simd_quatf(angle: rotationXRad, axis: [1, 0, 0]),
            simd_quatf(angle: rotationYRad, axis: [0, 1, 0])
        )

        entity.orientation = rotation
    }
}

// Optional preview
#Preview {
    ContentView()
}
