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

    @State private var isDaytime: Bool = true     // day/night
    @State private var immersiveEnabled: Bool = false // immersive background
    @State private var rainyWorldEnabled: Bool = false // rain
    
    // timer state
    @State private var destructionTimerActive: Bool = false
    @State private var destructionCountdown: Int = 180  // countdown
    @State private var showDestroyWorld: Bool = false   // destruction scene (used to show Restart)

    // realityKit content and current loaded entity
    @State private var realityContent: RealityViewContent?
    @State private var currentEntity: Entity?

    // to prevent race conditions when switching models
    @State private var loadCounter: Int = 0

    // animation/settings
    private let transitionDuration: TimeInterval = 0.36

    // MARK: - Body
    var body: some View {
        ZStack {
            // immersive background
            if immersiveEnabled {
                ImmersiveBlackSpace()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // main 3D Model View
            VStack(spacing: 20) {
                RealityView { content in
                    realityContent = content
                    requestLoadModel(into: content)
                }
                .frame(width: 400, height: 400)

                // restart button shows only after disappearance effect finished
                if showDestroyWorld {
                    Button(action: {
                        restartExperience()
                    }) {
                        Text("Restart Experience")
                            .font(.headline)
                            .padding()
                            .frame(width: 200)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .shadow(radius: 8)
                    }
                    .transition(.scale)
                }
            }
        }
        // Floating control panel WITH TIMER underneath
        .ornament(attachmentAnchor: .scene(.leading)) {
            VStack(spacing: 16) {
                // Control panel
                controlPanel

                // Timer display (MM:SS only)
                if destructionTimerActive && !showDestroyWorld {
                    Text(formatTime(destructionCountdown))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .transition(.opacity)
                }
            }
            .padding(.top, 8)
        }

        // toggle immersive background
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
            // start 2-minute delay before the destruction timer kicks in
            startInitialDelayTimer()
        }

        // reload models when toggles change
        .onChange(of: isDaytime) { _, _ in requestReload() }
        .onChange(of: rainyWorldEnabled) { _, _ in requestReload() }

        // update transforms dynamically
        .onChange(of: zoom) { _, _ in updateEntityTransform() }
        .onChange(of: rotationX) { _, _ in updateEntityTransform() }
        .onChange(of: rotationY) { _, _ in updateEntityTransform() }
    }

    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 25) {
            // immersive Toggle
            Toggle(isOn: $immersiveEnabled) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(immersiveEnabled ? .white : .gray)
                    .accessibilityLabel("Immersive Starfield")
            }
            .frame(width: 200)

            Divider().padding(.vertical, 8)

            // zoom
            VStack(alignment: .leading, spacing: 4) {
                Text("Zoom").font(.headline)
                Slider(value: $zoom, in: 0.5...2.0).frame(width: 200)
            }

            // rotate X
            VStack(alignment: .leading, spacing: 4) {
                Text("Rotate X").font(.headline)
                Slider(value: $rotationX, in: -180...180).frame(width: 200)
            }

            // rotate Y
            VStack(alignment: .leading, spacing: 4) {
                Text("Rotate Y").font(.headline)
                Slider(value: $rotationY, in: -180...180).frame(width: 200)
            }

            Divider().padding(.vertical, 8)

            // Day / Night Buttons
            HStack(spacing: 30) {
                Button(action: {
                    isDaytime = true
                    requestReload()
                }) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isDaytime ? .yellow : .gray)
                }

                Button(action: {
                    isDaytime = false
                    requestReload()
                }) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 32))
                        .foregroundColor(!isDaytime ? .yellow : .gray)
                }
            }

            // Rain Toggle
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

    // MARK: - Timer Logic
    private func startInitialDelayTimer() {
        // Wait 2 minutes before starting the destruction countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
            startDestructionCountdown()
        }
    }

    private func startDestructionCountdown() {
        destructionTimerActive = true
        destructionCountdown = 60 // Now 1 minute countdown

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if destructionCountdown > 0 {
                destructionCountdown -= 1
            } else {
                timer.invalidate()
                destructionTimerActive = false
                triggerDisappearanceEffect()
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    // MARK: - Disappearance Effect (shrink + sparkles)
    private func triggerDisappearanceEffect() {
        // If there's no current entity, just show restart button
        guard let container = currentEntity, let content = realityContent else {
            withAnimation(.spring()) { showDestroyWorld = true }
            return
        }

        // Keep original scale so shrink is relative to it
        let origScale = container.scale.x
        let fadeDuration: TimeInterval = 1.6
        let steps = 32
        let stepDelay = UInt64((fadeDuration / Double(steps)) * 1_000_000_000)

        // Spawn sparkles around the model
        addSparkles(into: content, at: container.position, count: 28)

        // Animate shrinking over time on a background task
        Task {
            for i in 0...steps {
                let t = 1.0 - Float(i) / Float(steps) // 1 -> 0
                let newScale = SIMD3<Float>(repeating: origScale * t)
                await MainActor.run {
                    container.scale = newScale
                }
                try? await Task.sleep(nanoseconds: stepDelay)
            }

            // remove model and reveal Restart button
            await MainActor.run {
                container.removeFromParent()
                currentEntity = nil
                withAnimation(.spring()) {
                    showDestroyWorld = true
                }
            }
        }
    }

    // Create many small spheres that fly outward/up and then get removed
    private func addSparkles(into content: RealityViewContent, at position: SIMD3<Float>, count: Int = 20) {
        for _ in 0..<count {
            // Create a tiny sphere
            let mesh = MeshResource.generateSphere(radius: 0.007)
            let material = SimpleMaterial(color: .init(.white), isMetallic: false)
            let spark = ModelEntity(mesh: mesh, materials: [material])

            // Random offset around the object
            let angle = Float.random(in: 0..<(2 * .pi))
            let radius = Float.random(in: 0.02...0.08)
            let height = Float.random(in: 0.03...0.12)
            let offset = SIMD3<Float>(cos(angle) * radius, Float.random(in: -0.01...0.01), sin(angle) * radius)
            spark.position = position + offset

            // start tiny
            spark.scale = SIMD3<Float>(repeating: 0.001)

            // Add to the scene
            content.add(spark)

            // Animate each spark: grow and move outward/up, then remove
            let targetScale = Float.random(in: 0.012...0.035)
            let targetPos = spark.position + SIMD3<Float>(offset.x * 1.5, height, offset.z * 1.5)
            let moveDuration: TimeInterval = Double.random(in: 0.9...1.4)

            Task { @MainActor in
                // move to target transform (position + scale)
                let targetTransform = Transform(scale: SIMD3<Float>(repeating: targetScale),
                                                rotation: simd_quatf(),
                                                translation: targetPos)
                spark.move(to: targetTransform,
                           relativeTo: nil,
                           duration: moveDuration,
                           timingFunction: .easeOut)

                // wait a bit longer than the animation before removing
                try? await Task.sleep(nanoseconds: UInt64((moveDuration + 0.15) * 1_000_000_000))
                spark.removeFromParent()
            }
        }
    }

    // MARK: - Restart Logic
    private func restartExperience() {
        showDestroyWorld = false
        rainyWorldEnabled = false
        isDaytime = true
        destructionTimerActive = false
        destructionCountdown = 180

        guard let content = realityContent else { return }
        requestLoadModel(into: content)

        // start the whole cycle again
        startInitialDelayTimer()
    }

    // MARK: - Reload Logic
    private func requestReload() {
        guard let content = realityContent else { return }
        requestLoadModel(into: content)
    }

    private func requestLoadModel(into content: RealityViewContent) {
        Task { @MainActor in
            loadCounter += 1
            let token = loadCounter

            if let old = currentEntity {
                old.removeFromParent()
                currentEntity = nil
            }

            Task {
                await loadSceneDirectly(into: content, token: token)
            }
        }
    }

    // MARK: - Load Scene
    private func loadSceneDirectly(into content: RealityViewContent, token: Int) async {
        guard !showDestroyWorld else { return }

        let sceneName: String
        if rainyWorldEnabled {
            sceneName = isDaytime ? "rainyworld" : "rainyworldnight"
        } else {
            sceneName = isDaytime ? "daytimeworld" : "nighttimeworld"
        }

        do {
            let modelEntity = try await Entity(named: sceneName, in: realityKitContentBundle)

            await MainActor.run {
                guard token == loadCounter else { return }

                let container = Entity()

                let bounds = modelEntity.visualBounds(relativeTo: nil)
                modelEntity.position = -bounds.center

                container.addChild(modelEntity)

                let light = DirectionalLight()
                light.light.intensity = 1000
                light.position = [0, 2, 1]
                light.look(at: [0, 0, 0], from: light.position, relativeTo: nil)
                container.addChild(light)

                container.position = [-0.1, 0, -0.1]
                container.scale = [Float(zoom), Float(zoom), Float(zoom)]
                container.orientation = simd_mul(
                    simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0]),
                    simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                )

                currentEntity = container
                content.add(container)
            }
        } catch {
            print("Error loading scene:", error.localizedDescription)
        }
    }

    // MARK: - Update Transform
    private func updateEntityTransform() {
        guard let entity = currentEntity else { return }

        // Zoom
        let zoomScale = Float(zoom)
        entity.scale = [zoomScale, zoomScale, zoomScale]

        // Rotation
        let rotationXRad = Float(rotationX * .pi / 180)
        let rotationYRad = Float(rotationY * .pi / 180)
        let rotation = simd_mul(
            simd_quatf(angle: rotationXRad, axis: [1, 0, 0]),
            simd_quatf(angle: rotationYRad, axis: [0, 1, 0])
        )
        entity.orientation = rotation
    }
}

#Preview {
    ContentView()
}

