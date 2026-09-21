import SwiftUI
import UIKit

/// A square, rounded album-art object moving across an anchored surface.
///
/// The image itself is the draggable object. Its interactive bounds follow the
/// object's real on-screen position, so only a touch that begins on the square
/// moves it. Blank surface space is inert. The object may travel beyond the
/// surface and keeps the position where it was released.
struct AlbumArtCanvasView: View {
    /// The high-resolution square art (already at `displayPixels`).
    let image: UIImage?
    /// True while the tracklist overlay is up: dims and blurs the artwork.
    var isRevealed: Bool = false

    private static let objectScale: CGFloat = 2.5
    private static let cornerRadius: CGFloat = 14
    private static let surfaceInset: CGFloat = 16
    /// Fraction of the finger's travel the artwork follows. `< 1` makes the
    /// object lag the finger so it feels heavier and does not race across the
    /// screen.
    private static let dragResistance: CGFloat = 0.6
    /// How far (points) an artwork edge may recede past a surface edge before
    /// the corner "anchors" stop it. Horizontal reveal is disabled entirely:
    /// the cover always fills the width, so left/right motion only pans across
    /// the cover and never exposes the background beside it. Vertical travel
    /// is capped asymmetrically below.
    private static let maxRevealX: CGFloat = 0
    /// Hard ceilings on vertical travel. The cover's top edge sits far above the
    /// visible area at rest, so downward travel (revealing the top rows) is
    /// larger than upward travel (revealing the bottom background), which stays
    /// tight.
    private static let maxPanYUp: CGFloat = 25
    private static let maxPanYDown: CGFloat = 100
    /// Width (in surface points) of the left-edge strip reserved for the
    /// navigation interactive pop. The artwork drag ignores a touch that
    /// starts in this band so the system back-swipe can take it.
    private static let backSwipeWidth: CGFloat = 24

    @State private var pan: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    /// nil = touch has not yet been classified; true = the drag began on the
    /// artwork; false = the drag began on blank surface and must be inert.
    @State private var dragOnArtwork: Bool?

    var body: some View {
        GeometryReader { proxy in
            let surfaceSize = proxy.size
            let artSide = min(
                surfaceSize.width - Self.surfaceInset * 2,
                surfaceSize.height - Self.surfaceInset * 2
            ) * Self.objectScale
            let artCenterX = surfaceSize.width / 2 + pan.width
            let artCenterY = surfaceSize.height / 2 + pan.height
            // The artwork's true on-screen bounds. `pan` only commits at the
            // end of a drag, so this rect is the object's position at the
            // moment a drag starts and drives the start-location hit test.
            let artRect = CGRect(
                x: artCenterX - artSide / 2,
                y: artCenterY - artSide / 2,
                width: artSide,
                height: artSide
            )
            let maxPanX = max(0, (artSide - surfaceSize.width) / 2 + Self.maxRevealX)
            let effectiveDrag = (dragOnArtwork == true)
                ? CGSize(
                    width: dragTranslation.width * Self.dragResistance,
                    height: dragTranslation.height * Self.dragResistance
                )
                : .zero
            let displayedPan = clamped(
                CGSize(
                    width: pan.width + effectiveDrag.width,
                    height: pan.height + effectiveDrag.height
                ),
                maxX: maxPanX,
                maxYUp: Self.maxPanYUp,
                maxYDown: Self.maxPanYDown
            )

            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: artSide, height: artSide)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: Self.cornerRadius,
                                style: .continuous
                            )
                        )
                        .position(
                            x: surfaceSize.width / 2 + displayedPan.width,
                            y: surfaceSize.height / 2 + displayedPan.height
                        )
                        .overlay {
                            Color.black.opacity(isRevealed ? 0.30 : 0)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: Self.cornerRadius,
                                        style: .continuous
                                    )
                                )
                        }
                        .blur(radius: isRevealed ? 22 : 0)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 96))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: surfaceSize.width, height: surfaceSize.height)
            // `.simultaneousGesture` (not `.gesture`) so the NavigationStack's
            // interactive pop can still claim a left-edge swipe instead of the
            // artwork drag swallowing it.
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation
                    }
                    .onChanged { value in
                        // Classify the touch the first time movement is seen.
                        // `pan` is unchanged mid-drag, so `artRect` is the
                        // object's position the moment the drag began. The
                        // left-edge strip is reserved for the navigation
                        // back-swipe, so a drag that starts there is inert.
                        if dragOnArtwork == nil {
                            dragOnArtwork = artRect.contains(value.startLocation)
                                && value.startLocation.x >= Self.backSwipeWidth
                        }
                    }
                    .onEnded { value in
                        if dragOnArtwork == true {
                            pan = clamped(
                                CGSize(
                                    width: pan.width + value.translation.width * Self.dragResistance,
                                    height: pan.height + value.translation.height * Self.dragResistance
                                ),
                                maxX: maxPanX,
                                maxYUp: Self.maxPanYUp,
                                maxYDown: Self.maxPanYDown
                            )
                        }
                        dragOnArtwork = nil
                    }
            )
            .animation(.easeInOut(duration: 0.24), value: isRevealed)
        }
    }

    private func clamped(_ translation: CGSize, maxX: CGFloat, maxYUp: CGFloat, maxYDown: CGFloat) -> CGSize {
        CGSize(
            width: max(-maxX, min(maxX, translation.width)),
            height: max(-maxYUp, min(maxYDown, translation.height))
        )
    }
}
