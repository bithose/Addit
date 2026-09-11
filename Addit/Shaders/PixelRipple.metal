#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// The launch screen's field: a panel of round emitters behaving like struck
// water.
//
// Nothing here is a sprite or an easing curve. The surface is a height field —
// a handful of expanding circular wavefronts summed together — sampled once
// per *cell* rather than once per pixel. That sampling is the entire point of
// the effect: the wave is smooth and continuous, and quantising it onto a grid
// is what makes it read as a low-resolution display showing a fluid rather
// than as a blurred gradient.
//
// The cell's sample is then drawn as a **dot whose size is its brightness** —
// a full-bleed disc at the top of the ramp, nothing at all at the bottom. This
// is halftone, and it does two jobs one flat square couldn't. The grid stops
// being something the picture is chopped into and becomes a thing in its own
// right, a panel of emitters that happen to be showing water; and it carries
// value twice over, in size as well as colour, so a crest reads even where the
// palette is running out of headroom.
//
// `PixelEQGrid` is the app's other pixel grid and stays square-ish and fixed:
// it's a readout you're meant to count, and a cell that changes size can't be
// counted. This one is a display you're meant to read *through*.
//
// Called from `PixelRippleField.swift` via `.colorEffect`.

// MARK: - Tuning

/// Wavefronts in flight. Each one owns a staggered slot in `kDropPeriod`, so
/// this is also what sets the patter: a new drop lands every
/// `kDropPeriod / kDrops` seconds.
constant int kDrops = 8;
/// Seconds from a drop landing to its slot recycling somewhere else. Long
/// enough that a ring crosses the screen and dies before its slot is reused,
/// so slots never visibly "jump".
///
/// Also the full length of the fill, and so the length of the launch: every
/// slot has fired exactly once by the time this is up. Keep it in step with
/// `LoadingSplashView.launchHold`.
constant float kDropPeriod = 2.4;
/// Wavefront speed, in screen widths per second.
constant float kWaveSpeed = 0.42;
/// Ripples per screen width. High enough for several rings inside one front.
constant float kWaveNumber = 46.0;

/// Clearance between two neighbouring dots at full brightness, as a fraction
/// of the cell. The grid's limit: a dot never grows past this, so even a screen
/// blown out to ice keeps its emitters separate instead of merging into a
/// sheet.
constant float kGap = 0.13;
/// Radius of the dimmest dot, in cell units. Not zero — an emitter at rest is
/// still an emitter, and letting the darks vanish outright turns the calm parts
/// of the field into a hole in the panel rather than water lying flat.
constant float kMinRadius = 0.055;
/// The unlit panel the dots sit on. Below the palette's own darkest entry, so
/// the emitters read as *on* something rather than as holes cut in the void.
constant float3 kBackdrop = float3(0.006, 0.004, 0.021);

/// Palette steps. The field is continuous; this is what makes it look
/// *indexed* — flat bands of colour stepping into each other the way a 256
/// colour display would have done it. Lower is chunkier.
constant float kPaletteSteps = 26.0;

// MARK: - Helpers

/// Hoskins' hash: two uncorrelated values in 0…1 from an integer pair.
/// Used for drop placement, so `(slot, cycle)` in gives a different point on
/// screen every time a slot comes round.
static float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

/// The spectrum, low to high: void → indigo → electric blue → cyan → ice.
///
/// Cool the whole way, and pushed hard toward the blues — this is the aqua
/// half of chrome-and-aqua, with the magenta added separately at the crests
/// so the two never average into a muddy purple across the middle.
static float3 spectrum(float t) {
    const float3 kVoid    = float3(0.015, 0.010, 0.055);
    const float3 kIndigo  = float3(0.075, 0.030, 0.240);
    const float3 kUltra   = float3(0.155, 0.080, 0.580);
    const float3 kElectric= float3(0.060, 0.430, 0.960);
    const float3 kCyan    = float3(0.200, 0.900, 1.000);
    const float3 kIce     = float3(0.880, 0.995, 1.000);

    float3 c = mix(kVoid, kIndigo, smoothstep(0.00, 0.34, t));
    c = mix(c, kUltra,    smoothstep(0.34, 0.52, t));
    c = mix(c, kElectric, smoothstep(0.52, 0.70, t));
    c = mix(c, kCyan,     smoothstep(0.70, 0.86, t));
    c = mix(c, kIce,      smoothstep(0.86, 1.00, t));
    return c;
}

// MARK: - Entry point

[[ stitchable ]] half4 pixelRipple(float2 position,
                                   half4 currentColor,
                                   float2 size,
                                   float cell,
                                   float time) {
    // Snap to the centre of the cell this pixel belongs to, and work from
    // there onwards as though the cell were a single sample point. Everything
    // below is therefore one value for the whole cell — where the pixel
    // actually falls inside it matters only to the dot cut at the very end.
    float2 sample = (floor(position / cell) + 0.5) * cell;

    // Normalise by width alone so a cell stays square: y runs 0…aspect, not
    // 0…1. Using each axis' own extent would stretch the rings into ellipses
    // on a tall screen.
    float2 uv = sample / size.x;
    float aspect = size.y / size.x;

    float height = 0.0;     // the surface itself
    float lead = 0.0;       // its quadrature — peaks a quarter wave ahead

    for (int i = 0; i < kDrops; i++) {
        float slot = float(i);
        // Slot `i` first fires `i` intervals in, and `local` is the time since
        // then. Negative means its first drop hasn't landed yet, and that slot
        // contributes nothing at all.
        //
        // That guard is what gives the launch a shape. Without it the slots
        // are simply periodic, and any stagger — forwards or backwards — just
        // relabels which slot is which: t = 0 always lands mid-storm. Cutting
        // off everything before zero instead means the field starts empty and
        // fills one ring at a time, and by `kDropPeriod` every slot has fired
        // exactly once. That is the whole animation, and it is why the splash
        // is held for exactly that long — see `LoadingSplashView.launchHold`.
        float local = time - slot * (kDropPeriod / float(kDrops));
        if (local < 0.0) { continue; }
        float cycle = floor(local / kDropPeriod);
        float age = local - cycle * kDropPeriod;

        float2 rnd = hash22(float2(slot, cycle));
        float2 origin = float2(rnd.x, rnd.y * aspect);

        float dist = distance(uv, origin);
        // Distance behind the wavefront. Negative outside the ring, positive
        // inside it, zero exactly on it.
        float front = dist - kWaveSpeed * age;

        // The ring widens as it travels — a front of constant width reads as a
        // hard expanding circle, an object rather than a disturbance.
        float width = 0.13 + 0.075 * age;
        float envelope = exp(-(front * front) / (width * width));
        // Energy leaves with time, and spreads out over a growing circumference.
        // The floor in the denominator is what keeps a fresh drop from
        // clipping to a white square at its own centre — without it the
        // amplitude runs away as `dist` goes to zero and the impact point
        // blows out instead of reading as the hottest part of the ripple.
        float decay = exp(-1.25 * age) / (0.62 + 3.0 * dist);

        float phase = kWaveNumber * front;
        height += sin(phase) * envelope * decay;
        lead += cos(phase) * envelope * decay;
    }

    // A slow swell under everything, so the field is never completely flat
    // between drops. Two incommensurate sheets, so it doesn't loop visibly.
    height += 0.075 * sin(uv.x * 6.3 + time * 0.55) * sin(uv.y * 4.7 - time * 0.41);

    // Ripples are small and signed; centre them in the ramp so the resting
    // surface sits in the indigo and crests climb out of it. `tanh` rather
    // than a clamp: two fronts crossing shouldn't flatten into a white plate.
    float level = 0.5 + 0.5 * tanh(height * 2.6);

    // Bend the midtones down. Without this the undisturbed surface — which is
    // most of the screen, most of the time — lands mid-ramp and the whole
    // field is one flat blue with the ripples barely brighter than it. The
    // crests are unaffected at the top of the curve, so this is contrast
    // rather than dimming: the water goes dark and the disturbance lights up.
    level = pow(level, 1.75);

    // Quantise to palette entries. Done to the ramp parameter rather than to
    // the final colour so the bands land on the same values everywhere on
    // screen, which is what makes them read as a palette rather than as
    // banding artefacts.
    level = round(level * (kPaletteSteps - 1.0)) / (kPaletteSteps - 1.0);

    float3 col = spectrum(level);

    // Hot magenta on the leading edge of each front — the quarter-wave-ahead
    // signal is exactly where the water is climbing fastest. This is the other
    // half of the chrome palette, and keeping it on the edges means it reads as
    // a rim light on a moving surface instead of tinting the whole field.
    const float3 kMagenta = float3(1.00, 0.16, 0.72);
    col += kMagenta * 0.42 * smoothstep(0.18, 0.85, lead);

    // Cut the dot. Its radius runs with `level` — the same quantised ramp the
    // colour comes from, so size steps in the same palette increments the
    // colour does and the two never disagree about how lit a cell is. Ice
    // fills the cell to the grid's limit, the void is a speck.
    //
    // Deliberately the ramp rather than the colour's luminance: the spectrum
    // spends its middle in indigo and ultraviolet, which are plainly *lit* and
    // barely bright, so sizing by luminance would shrink the whole body of a
    // ripple and leave only its white crest showing.
    float radius = mix(kMinRadius, 0.5 - kGap * 0.5, level);

    // Antialiased over roughly a point rather than hard-edged: the cell size is
    // fitted to the screen width and is almost never a whole number of device
    // pixels, so a hard edge would round differently from one dot to the next
    // and a grid of supposedly identical emitters would visibly seethe.
    float2 local = position / cell - floor(position / cell);
    float fromCentre = length(local - 0.5);
    float aa = 0.5 / cell;
    // Named `coverage` rather than `dot`, which is a Metal builtin.
    float coverage = 1.0 - smoothstep(radius - aa, radius + aa, fromCentre);
    col = mix(kBackdrop, col, coverage);

    return half4(half3(col), 1.0h);
}
