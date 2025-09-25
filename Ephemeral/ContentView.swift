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

    @State private var isDaytime: Bool = true       // Day vs night toggle
    @State private var immersiveEnabled: Bool = false // Immersive background toggle
    @State private var rainyWorldEnabled: Bool = false // Rainy world toggle

    // RealityKit content and current loaded entity
    @State private var realityContent: RealityViewContent?
    @State private var currentEntity: Entity?

    // To prevent overlap if loads happen too quickly
    @State private var loadCounter: Int = 0

    var body: some View {
        ZStack {
            // Immersive space background
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
            }
        }
        // Floating control panel
        .ornament(attachmentAnchor: .scene(.leading)) {
            controlPanel
        }

        // Toggle immersive background
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

        // Reload model when any relevant state changes
        .onChange(of: isDaytime) { _, _ in reloadModel() }
        .onChange(of: rainyWorldEnabled) { _, _ in reloadModel() }

        // Update transforms dynamically
        .onChange(of: zoom) { _, _ in updateEntityTransform() }
        .onChange(of: rotationX) { _, _ in updateEntityTransform() }
        .onChange(of: rotationY) { _, _ in updateEntityTransform() }
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 25) {
            // Immersive Background Toggle
            Toggle(isOn: $immersiveEnabled) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(immersiveEnabled ? .white : .gray)
                    .accessibilityLabel("Immersive Starfield")
            }
            .frame(width: 200)

            Divider().padding(.vertical, 8)

            // Zoom Slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Zoom")
                    .font(.headline)
                Slider(value: $zoom, in: 0.5...2.0)
                    .frame(width: 200)
            }

            // Rotate X Slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Rotate X")
                    .font(.headline)
                Slider(value: $rotationX, in: -180...180)
                    .frame(width: 200)
            }

            // Rotate Y Slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Rotate Y")
                    .font(.headline)
                Slider(value: $rotationY, in: -180...180)
                    .frame(width: 200)
            }

            Divider().padding(.vertical, 8)

            // Day / Night Buttons
            HStack(spacing: 30) {
                Button(action: {
                    isDaytime = true
                    reloadModel()
                }) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isDaytime ? .yellow : .gray)
                }

                Button(action: {
                    isDaytime = false
                    reloadModel()
                }) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 32))
                        .foregroundColor(!isDaytime ? .yellow : .gray)
                }
            }

            // Rain Toggle (icon on the left)
            HStack(spacing: 12) {
                Image(systemName: "cloud.rain.fill")
                    .font(.system(size: 28))
                    .foregroundColor(rainyWorldEnabled ? .blue : .gray)

                Toggle("", isOn: $rainyWorldEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("Rainy World")
            }
            .frame(width: 180, alignment: .leading)
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(25)
        .shadow(radius: 50)
    }

    // MARK: - Reload Model Logic
    private func reloadModel() {
        guard let content = realityContent else { return }

        // Remove current model immediately
        if let entity = currentEntity {
            entity.removeFromParent()
            currentEntity = nil
        }

        // Increment load counter to invalidate any previous async loads
        loadCounter += 1
        loadSceneDirectly(into: content)
    }

    // MARK: - Load Scene
    private func loadSceneDirectly(into content: RealityViewContent) {
        // Capture the current load ID
        let currentLoadID = loadCounter

        // Decide which model to load
        let sceneName: String
        if rainyWorldEnabled {
            sceneName = isDaytime ? "rainyworld" : "rainyworldnight"
        } else {
            sceneName = isDaytime ? "daytimeworld" : "nighttimeworld"
        }

        print("Loading scene:", sceneName)

        Task {
            do {
                let modelEntity = try await Entity(named: sceneName, in: realityKitContentBundle)

                await MainActor.run {
                    // Ignore if another load started in the meantime
                    guard currentLoadID == loadCounter else { return }

                    // Clear any remaining entities
                    if let entity = currentEntity {
                        entity.removeFromParent()
                    }

                    // Create container
                    let container = Entity()

                    // Center model pivot
                    let bounds = modelEntity.visualBounds(relativeTo: nil)
                    let center = bounds.center
                    modelEntity.position = -center

                    // Add model to container
                    container.addChild(modelEntity)

                    // Adjust container position
                    container.position = [-0.1, 0, -0.1] // x, y, z

                    // Save reference & add to RealityView
                    currentEntity = container
                    content.add(container)

                    // Lighting
                    let light = DirectionalLight()
                    light.light.intensity = 1000
                    light.position = [0, 2, 1]
                    light.look(at: [0, 0, 0], from: light.position, relativeTo: nil)
                    content.add(light)

                    // 🔹 Apply current zoom & rotation to new model immediately
                    updateEntityTransform()

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

        // Apply zoom (scale)
        let zoomScale = Float(zoom)
        entity.scale = [zoomScale, zoomScale, zoomScale]

        // Convert degrees → radians
        let rotationXRad = Float(rotationX * .pi / 180)
        let rotationYRad = Float(rotationY * .pi / 180)

        // Combine X & Y rotations
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
