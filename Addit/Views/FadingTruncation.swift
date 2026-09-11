import SwiftUI

/// A view modifier that replaces SwiftUI's ellipsis truncation with a trailing
/// fade-out when a single-line `Text` can't fit its full content.
///
/// Usage: `Text("…").fadingTruncation()`
///
/// Implementation notes:
/// - The text is wrapped in a scroll-disabled horizontal `ScrollView`. That
///   container takes the width the parent offers and clips its content to
///   that width (same cutoff point SwiftUI's built-in truncation would pick)
///   without propagating the oversized intrinsic width back up the layout.
/// - `fixedSize(horizontal: true)` on the inner text prevents SwiftUI from
///   inserting the "…" character — the glyphs render in full and the scroll
///   container does the clipping.
/// - `mask(...)` fades the trailing `fadeWidth` points of whatever is
///   visible, and is applied **only when the text is actually too long**. A
///   mask forces the masked subtree into an offscreen pass, and this modifier
///   is on both labels of every album card — a screen of them was paying for
///   a dozen offscreen passes a frame to fade text that mostly fits, since a
///   fitting string put the faded region past its own last glyph and drew
///   identically either way. Overflow is free to detect: the inner frame's
///   `minWidth` pins it to the container when the text fits, so a measured
///   width above that *is* the overflow. `TrailingFade` at the bottom of this
///   file is what makes "no fade" mean no `.mask` at all.
extension View {
    func fadingTruncation(
        fadeWidth: CGFloat = 18,
        alignment: Alignment = .leading
    ) -> some View {
        modifier(FadingTruncationModifier(fadeWidth: fadeWidth, alignment: alignment))
    }
}

private struct FadingTruncationModifier: ViewModifier {
    let fadeWidth: CGFloat
    let alignment: Alignment
    @State private var containerWidth: CGFloat = 0
    @State private var textWidth: CGFloat = 0

    /// Half a point of slack, so a text laid out to exactly the container width
    /// doesn't flap between masked and unmasked on rounding.
    private var overflows: Bool {
        containerWidth > 0 && textWidth > containerWidth + 0.5
    }

    func body(content: Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                // When the text is shorter than the container, `minWidth`
                // pads the frame out to the container width so the specified
                // alignment takes effect (e.g. centered text stays centered).
                // When the text is longer, the frame grows to fit the text
                // and the ScrollView clips the trailing overflow.
                .frame(minWidth: containerWidth, alignment: alignment)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { textWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, new in
                                textWidth = new
                            }
                    }
                )
        }
        .scrollDisabled(true)
        .modifier(TrailingFade(isActive: overflows, fadeWidth: fadeWidth))
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, new in
                        containerWidth = new
                    }
            }
        )
    }

}

/// Applies the trailing fade, or genuinely nothing.
///
/// The branch is the point: masking with an opaque rectangle would still cost
/// the offscreen pass, so the fitting case has to skip `.mask` itself rather
/// than pass it something that draws everything through.
private struct TrailingFade: ViewModifier {
    let isActive: Bool
    let fadeWidth: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content.mask(
                HStack(spacing: 0) {
                    Rectangle().fill(.black)
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: fadeWidth)
                }
            )
        } else {
            content
        }
    }
}

/// The multi-line counterpart to `fadingTruncation`: text clamped to a number
/// of lines whose overflow **fades out** instead of ending in an ellipsis.
///
/// Why it isn't the modifier above. That one clips a single line in a
/// scroll-disabled `ScrollView` and fades the trailing edge of the whole thing,
/// which works precisely because there is only ever one line. Fade the trailing
/// edge of a two-line block and you fade the end of the *first* line too — and
/// a line that wrapped is by definition running right up to the edge, so what
/// you get is a title that appears to be cut in the middle of a perfectly
/// intact word.
///
/// So the fade is confined to the last line's band, and applied only when the
/// clamp actually cut something. Both of those need measuring:
///
/// - **Was anything cut?** A hidden copy of the same text, at the same width
///   with no line limit, gives the height the text *wanted*. Taller than the
///   clamped one means there is more text than is showing. Without this test a
///   centered line that merely came close to the edge would be faded for no
///   reason, since a centered short line can end well inside the fade's reach.
/// - **Where is the last line?** The clamped height divided by the line count.
///   When the text is cut, the clamp is by definition full, so that division is
///   exact rather than an estimate.
///
/// The ellipsis is still generated — `Text` gives no way to refuse one — and is
/// hidden by the fade rather than removed: it sits at the very end of the line,
/// which the gradient has taken to fully transparent well before its own edge.
/// That's what `fadeWidth` and the 0.55 stop are for, and why the fade is wider
/// than the single-line one.
struct FadingClampedText: View {
    let text: String
    let font: Font
    /// Lines to show before cutting.
    var lines: Int = 1
    var alignment: TextAlignment = .center
    /// Width of the fade in points. Wide enough that the last third of it —
    /// where the ellipsis lives — is completely clear.
    var fadeWidth: CGFloat = 46

    /// Height as drawn, and height the text would have taken unclamped.
    @State private var clampedHeight: CGFloat = 0
    @State private var naturalHeight: CGFloat = 0

    private var isTruncated: Bool {
        clampedHeight > 0 && naturalHeight > clampedHeight + 0.5
    }

    var body: some View {
        Text(text)
            .font(font)
            .multilineTextAlignment(alignment)
            .lineLimit(lines)
            .background(heightReader { clampedHeight = $0 })
            .background(alignment: .top) { ruler }
            .modifier(
                LastLineFade(
                    isActive: isTruncated,
                    bandHeight: clampedHeight / CGFloat(max(lines, 1)),
                    fadeWidth: fadeWidth
                )
            )
    }

    /// The same text, same width, no line limit — and never drawn. Anchored to
    /// the top of a background so that being taller than what it measures
    /// against costs nothing: a background is laid out inside its parent's
    /// frame and reports nothing back up.
    private var ruler: some View {
        Text(text)
            .font(font)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .background(heightReader { naturalHeight = $0 })
    }

    private func heightReader(_ store: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { store(geo.size.height) }
                .onChange(of: geo.size.height) { _, new in store(new) }
        }
    }
}

/// Fades the trailing end of the bottom `bandHeight` of a view, or does nothing
/// at all — same reasoning as `TrailingFade`, a mask that draws everything
/// through still costs the offscreen pass.
private struct LastLineFade: ViewModifier {
    let isActive: Bool
    let bandHeight: CGFloat
    let fadeWidth: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive, bandHeight > 0 {
            content.mask(
                VStack(spacing: 0) {
                    // Every line but the last, untouched.
                    Rectangle().fill(.black)

                    HStack(spacing: 0) {
                        Rectangle().fill(.black)
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .clear, location: 0.55),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: fadeWidth)
                    }
                    .frame(height: bandHeight)
                }
            )
        } else {
            content
        }
    }
}
