import SwiftUI

/// "ADDIT" as extruded chrome — the app's wordmark wherever it appears at
/// full size.
///
/// Drawn in two places: the sign-in screen and the launch splash. It lives here
/// so those two can't drift apart, for the same reason `LoadingSplashView` does
/// — the splash's own wordmark used to be a plain `Text` and the two marks
/// showed the app under two different names' worth of styling within a second
/// of each other.
///
/// Three things stacked, which is what separates chrome from a grey gradient:
/// an extrusion of offset dark copies giving the letters depth, a face carrying
/// the classic chrome ramp — bright sky at the top, a hard dark horizon across
/// the middle, ground light bouncing up underneath — and the drop shadow that
/// sits the whole slab on the surface behind it. `lift` is how much light the
/// face is under; `size` scales all three together.
///
/// The face is Hoefler Text Black: iOS ships no blackletter at all (Druk and
/// Bebas are on the device but private to system UI), and of what's actually
/// available a heavy gothic serif is nearest to a metal logo. A real black
/// metal face would have to be bundled like Geist and Departure Mono are.
struct ChromeWordmark: View {
    /// Cap height of the face, in points. Everything else is derived from it,
    /// so the mark scales as one object rather than as a large word with a
    /// small extrusion stuck to it.
    var size: CGFloat = 52

    /// How much extra light falls on the face, 0…1 — the splash uses it, the
    /// sign-in screen doesn't.
    ///
    /// Applied to the *face only*, never the extrusion: the slabs behind it
    /// stay dark, so this reads as a brighter light on the metal rather than as
    /// the whole mark being turned up. Turning up the group would flatten the
    /// depth, which is the one thing separating this from a silver word.
    var lift: Double = 0

    /// The chrome ramp: sky, horizon, bounce. `liftShare` is how much of `lift`
    /// each stop takes — the darks take a fraction of it, because lifting the
    /// horizon evenly with the highlights turns the ramp into a light grey wash
    /// and the hard dark band is the single most recognisable feature of chrome.
    private static let faceStops: [(color: Color, location: Double, liftShare: Double)] = [
        (Color(red: 0.17, green: 0.18, blue: 0.20), 0.00, 0.55),
        (Color(red: 0.95, green: 0.97, blue: 1.00), 0.30, 1.00),
        (Color(red: 0.54, green: 0.57, blue: 0.61), 0.47, 0.85),
        (Color(red: 0.11, green: 0.13, blue: 0.16), 0.52, 0.30),
        (Color(red: 0.81, green: 0.85, blue: 0.90), 0.72, 1.00),
        (Color(red: 0.43, green: 0.46, blue: 0.50), 0.88, 0.75),
        (Color(red: 0.91, green: 0.94, blue: 0.98), 1.00, 1.00),
    ]

    /// Slabs behind the face. A count, not a depth — the distance each one
    /// travels scales with `size`.
    private static let slabs = 6

    /// The reference size the hand-tuned offsets were chosen at.
    private static let referenceSize: CGFloat = 52

    var body: some View {
        let face = Font.custom("HoeflerText-Black", size: size)
        let unit = size / Self.referenceSize

        ZStack {
            // Extrusion. Drawn back-to-front so the nearest slab is brightest —
            // a flat-coloured extrusion reads as a drop shadow, not as depth.
            ForEach((1...Self.slabs).reversed(), id: \.self) { depth in
                Text("ADDIT")
                    .font(face)
                    .tracking(2 * unit)
                    .foregroundStyle(
                        Color(white: 0.10 + 0.035 * Double(Self.slabs - depth))
                    )
                    .offset(y: CGFloat(depth) * unit)
            }

            Text("ADDIT")
                .font(face)
                .tracking(2 * unit)
                .foregroundStyle(
                    LinearGradient(
                        stops: Self.faceStops.map { stop in
                            .init(
                                color: stop.color.mix(with: .white, by: lift * stop.liftShare),
                                location: stop.location
                            )
                        },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.45), radius: 6 * unit, y: 4 * unit)
        }
        // So a caller's own shadow lands under the whole mark rather than
        // separately under each slab of the extrusion.
        .compositingGroup()
        .accessibilityLabel("Addit")
    }
}

#Preview {
    ChromeWordmark()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.015, green: 0.010, blue: 0.055))
}
