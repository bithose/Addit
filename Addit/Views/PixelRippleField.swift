import SwiftUI

/// A screen-filling grid of round pixels rippling like struck water, each dot
/// sized by how lit it is.
///
/// Every bit of the shape and colour comes from `PixelRipple.metal`; this view
/// only decides how big a pixel is and supplies the clock.
///
/// The dots grow and shrink with the water — see the note at the top of the
/// shader. `PixelEQGrid` is the app's other pixel grid and keeps its cells a
/// fixed size, because that one is a readout you're meant to count and this one
/// is a display you're meant to read through.
struct PixelRippleField: View {
    /// Roughly how big one cell should be, in points — the dot inside it is
    /// this at its brightest and a speck at its darkest. Rounded per-device by
    /// `fittedCell` so a whole number of columns spans the width.
    var pixelSize: CGFloat = 12

    /// `TimelineView(.animation)` for the same reason `SpinningPlasmaOrb` uses
    /// it — the motion is continuous and unbounded, so there's no keyframe pair
    /// to animate between, just elapsed time.
    ///
    /// Measured from here rather than the reference date for the precision
    /// reason spelled out in `DiscoHouse`: that's ~7.7e8, and the `float` the
    /// shader receives carries about seven significant digits, so the
    /// fractional part would quantise to steps coarser than a frame.
    @State private var start = Date()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The frame Reduce Motion holds. Late in the fill, where most slots have
    /// fired, so the still shows a full field rather than the single drop that
    /// exists at zero.
    private static let heldFrame: Double = 2.1

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cell = Self.fittedCell(target: pixelSize, width: size.width)

            if reduceMotion {
                // No `TimelineView` at all rather than a frozen one: this is a
                // full-screen fragment shader, and there's no reason to keep
                // paying for it every frame to redraw the same square.
                field(size: size, cell: cell, time: Self.heldFrame)
            } else {
                TimelineView(.animation) { timeline in
                    field(size: size, cell: cell, time: timeline.date.timeIntervalSince(start))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func field(size: CGSize, cell: CGFloat, time: Double) -> some View {
        Rectangle()
            .fill(.white)
            .colorEffect(
                ShaderLibrary.pixelRipple(
                    .float2(size.width, size.height),
                    .float(cell),
                    .float(time)
                )
            )
    }

    /// The pixel size nearest `target` that divides `width` evenly.
    ///
    /// Only the width is squared up. Cells have to stay square, so one axis has
    /// to be the one that ends in a partial row — and it should be the vertical
    /// one, because a half-width column against the side of the screen is
    /// plainly visible where a half-height row under the home indicator is not.
    private static func fittedCell(target: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return target }
        let columns = max(1, (width / target).rounded())
        return width / columns
    }
}

#Preview {
    PixelRippleField()
        .ignoresSafeArea()
}
