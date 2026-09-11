import SwiftUI

/// The screen between launch and the library: the chrome wordmark over a field
/// of pixels rippling like water.
///
/// The mark is `ChromeWordmark`, the same one the sign-in screen carries — so
/// the first two screens of a cold launch show the app under one identity
/// instead of two, and the chrome half of chrome-and-aqua arrives on the very
/// first frame the app draws for itself.
///
/// Rendered from two places — `AccountContainerView` shows it while the session
/// restores (before `ContentView` exists at all), and `ContentView` shows it
/// during an account switch. It lives here so those two can't drift apart; they
/// were previously separate hand-maintained copies, and they had.
///
/// Full-bleed rather than a panel inset into the chassis, which is what the
/// design language would ask for anywhere else. This surface has no chassis:
/// it's the first thing drawn, it's up for a moment, and the whole screen being
/// the display is the effect. `PixelRippleField` owns everything about it.
struct LoadingSplashView: View {
    /// How long a cold launch holds this on screen, in seconds, *after* there
    /// is nothing left to wait for.
    ///
    /// The value is not a taste call — it's `kDropPeriod` from
    /// `PixelRipple.metal`, the time it takes every drop slot to fire exactly
    /// once. The field starts empty and fills over precisely this long, so
    /// cutting it any shorter shows an unfinished screen and running it longer
    /// starts the field over. Move one and move the other.
    ///
    /// Only the launch applies this (`AccountContainerView`). The account
    /// switch that shows the same view has a real wait behind it and shouldn't
    /// be padded.
    static let launchHold: Double = 2.4

    /// How long the field takes to fade out to black once the hold is up, in
    /// seconds. Slow next to everything else here on purpose: this is the
    /// animation ending, and a quick fade would read as the screen being taken
    /// away rather than as the water going still.
    static let blackoutFade: Double = 0.45

    /// A beat of plain black between the fade landing and the library sliding
    /// in. Short — it's a breath, not a pause — but without it the slide starts
    /// while the last of the field is still visible and the two motions muddle.
    static let blackoutHold: Double = 0.12

    /// Fades the *field* down to the black behind it, which is what the launch
    /// does at the end of `launchHold` before handing over to the library.
    /// Animated by the caller.
    ///
    /// The wordmark deliberately doesn't go with it. The water draining away
    /// from under the mark leaves the app's name alone on black for a beat,
    /// which is the thing the launch is for — and it's the mark that then
    /// carries the slide, so there's something to watch leave.
    ///
    /// Default off: `ContentView` shows this same view during an account
    /// switch, where there's a real wait behind it and nothing to hand over to
    /// at any particular moment.
    var isBlackedOut: Bool = false

    var body: some View {
        ZStack {
            // The floor the fade lands on. True black rather than the panel's
            // own unlit colour: this is the app going dark between two screens,
            // and a near-black that still carries a hue reads as a dimmed
            // picture instead of as nothing.
            Color.black

            PixelRippleField()
                // The unlit panel, so a partial bottom row and the launch
                // storyboard behind it match the field rather than flashing.
                .background(Color(red: 0.006, green: 0.004, blue: 0.021))
                // One opacity over the whole field so the fade can't come apart
                // into layers going dark at different rates.
                .opacity(isBlackedOut ? 0 : 1)

            ChromeWordmark(lift: 0.30)
                // The field runs from near-black to ice, so the mark can't
                // rely on contrast with any one part of it — this is what keeps
                // it off the surface when a crest passes underneath. Chrome is
                // a reflection of a room, and against a lit ripple its own
                // midtones are close enough to the water to sit *in* it. The
                // `lift` is the other half of that: the face carries more light
                // here than it does on the sign-in screen, which has only a
                // flat background to stand out from.
                //
                // The halo is applied out here rather than inside
                // `ChromeWordmark`, whose own drop shadow sets the letters on a
                // plain background: this is a shadow the sign-in screen has no
                // field to need. Outside the fade too, so it stays with the
                // mark once the water has gone.
                .shadow(color: .black.opacity(0.55), radius: 18)
                .shadow(color: .black.opacity(0.35), radius: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

#Preview {
    LoadingSplashView()
}
