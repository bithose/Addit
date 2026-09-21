import SwiftUI

/// The tap-toggled tracklist overlay for the album screen.
///
/// The artwork beneath this view is already dimmed and blurred while the
/// overlay is shown. The album title/artist and track rows therefore sit
/// directly over that artwork with no second rendered panel competing with it.
/// A tap that no row claims dismisses the overlay, so the transparent layer
/// doubles as its gesture shield.
struct TracklistOverlayView<Rows: View>: View {
    let title: String
    let artist: String
    let description: String?
    /// Pre-formatted album total, shown as a footer when available.
    let albumDuration: String?
    /// How far the header clears the top chrome (status bar + nav bar).
    var topInset: CGFloat = 0
    var onDismiss: () -> Void = {}
    var onRefresh: (() -> Void)?

    @ViewBuilder var rows: () -> Rows

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Transparent shield: the blurred artwork remains the only surface
            // behind the text and rows.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 0) {
                        rows()

                        if let albumDuration {
                            HStack {
                                Spacer()
                                Text(albumDuration)
                                    .font(.readout(11))
                                    .foregroundStyle(Phosphor.dim)
                                    .phosphorGlow(intensity: 0.4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        }
                    }
                }
                .onTapGesture { onDismiss() }
                .refreshable { onRefresh?() }
            }
            .onTapGesture { onDismiss() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .simultaneousGesture(TapGesture().onEnded { onDismiss() })
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.uiTitle.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(artist)
                .font(.uiSubheadline)
                .foregroundStyle(Color.appDimmedText)

            if let description {
                Text(description)
                    .font(.uiFootnote)
                    .foregroundStyle(Color.appDimmedText)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topInset + 16)
        .padding(.bottom, 12)
    }

}
