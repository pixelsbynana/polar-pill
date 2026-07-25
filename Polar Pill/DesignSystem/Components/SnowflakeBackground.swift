import SwiftUI

// A subtle, static, NON-OVERLAPPING snowflake layer.
struct SnowflakeBackground: View {
    private let flakes: [Flake]

    // Positions are placed ONCE via a seeded RNG using rejection sampling:
    // a candidate is discarded if it lands too close to an already-placed
    // flake, so none overlap. Stable across redraws and launches.
    init(count: Int = 34,
         seed: UInt64 = 45,
         referenceWidth: CGFloat = 393,      // iPhone 14 Pro point width
         referenceAspect: CGFloat = 2.168) { // 852 / 393
        var rng = SeededGenerator(seed: seed)
        var placed: [Flake] = []
        var attempts = 0
        let maxAttempts = count * 400

        while placed.count < count && attempts < maxAttempts {
            attempts += 1
            // pow() biases toward the small end: mostly small flakes,
            // a few large ones for variety
            let size = 14 + CGFloat(pow(Double.random(in: 0...1, using: &rng), 1.9)) * 76
            let x = CGFloat.random(in: 0...1, using: &rng)
            let y = CGFloat.random(in: 0...1, using: &rng)

            // normalized radius (in width units); 0.55 ≈ half the glyph + a small gap
            let r = (size / referenceWidth) * 0.55

            // reject if it collides with any flake already placed
            let collides = placed.contains { other in
                let otherR = (other.size / referenceWidth) * 0.55
                let dx = x - other.x
                let dy = (y - other.y) * referenceAspect   // scale y into width units
                return (dx * dx + dy * dy).squareRoot() < (r + otherR)
            }
            if collides { continue }

            placed.append(Flake(
                x: x, y: y, size: size,
                opacity: Double.random(in: 0.025...0.08, using: &rng),   // more transparent
                rotation: Double.random(in: 0...360, using: &rng),
                blur: Bool.random(using: &rng) ? CGFloat.random(in: 0...1.5, using: &rng) : 0
            ))
        }
        flakes = placed   // if it couldn't fit all `count`, it uses what fit
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(flakes) { flake in
                    Image(systemName: "snowflake")
                        .font(.system(size: flake.size))
                        .foregroundStyle(.white)
                        .opacity(flake.opacity)
                        .rotationEffect(.degrees(flake.rotation))
                        .blur(radius: flake.blur)
                        .position(x: flake.x * geo.size.width,
                                  y: flake.y * geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)   // never intercept taps meant for your buttons
        .ignoresSafeArea()
    }

    private struct Flake: Identifiable {
        let id = UUID()
        let x, y, size: CGFloat
        let opacity: Double
        let rotation: Double
        let blur: CGFloat
    }
}

// Deterministic generator (SplitMix64) so the scatter is stable, not random each launch.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
