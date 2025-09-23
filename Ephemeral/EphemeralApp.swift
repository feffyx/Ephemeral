//
//  EphemeralApp.swift
//  Ephemeral
//
//  Created by Federica Ziaco on 23/09/25.
//

import SwiftUI

@main
struct EphemeralApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 600, height: 400)
#if os(visionOS)
        ImmersiveSpace(id: "Immersive") {
            ImmersiveBlackSpace()
        }
        .immersionStyle(selection: .constant(.full), in: .mixed, .full)
#endif
    }
}
