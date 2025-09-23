import SwiftUI

#if os(visionOS)
struct ImmersiveBlackSpace: View {
    var body: some View {
        ImmersiveStarField()
            .ignoresSafeArea()
    }
}

private struct ImmersiveStarField: View {
    private struct Star {
        let position: CGPoint   // normalized 0...1
        let size: CGFloat       // point size of the star
        let twinkleSpeed: Double
        let phase: Double
    }

    @State private var stars: [Star] = []
    private let starCount = 800

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
                        var alpha = 0.3 + 0.7 * sin(t * star.twinkleSpeed + star.phase)
                        alpha = max(0.08, min(1.0, alpha))
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
            let size = CGFloat.random(in: 0.4...2.0)
            let speed = Double.random(in: 0.4...1.8)
            let phase = Double.random(in: 0...(2 * .pi))
            newStars.append(Star(position: position, size: size, twinkleSpeed: speed, phase: phase))
        }
        stars = newStars
    }
}
#endif
