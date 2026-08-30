import SwiftUI
import HaloShared

/// Backwards-compatible visual tokens used by app-side surfaces.
///
/// Keep the concrete visual direction in `HaloVisual` below. The older
/// `SwarmHalo`/`HaloTheme` facade remains so existing screens inherit palette
/// changes without a global refactor.
enum SwarmHalo {

  // MARK: - Current endpoints

  static let absoluteBlack = HaloVisual.Palette.absoluteBlack
  /// Primary ink — plain white, used at varying opacity. `docs/DESIGN.md` R3.
  static let cream = HaloVisual.Palette.cream
  /// Deprecated alias kept only so any stray reference still resolves to ink.
  static let platinum = HaloVisual.Palette.cream

  // MARK: - Activation: none (docs/DESIGN.md R4)
  //
  // Halo has no brand accent. Colour comes only from people's mood states.
  // The tokens below are neutral and deprecated; the single exception is
  // `attention`, which is *semantic* (something went wrong) rather than
  // brand, and stays coloured so failure is never silent.

  /// Deprecated — neutral. Prefer `ink`, or a mood colour for a person.
  static let bronzeAccent = HaloVisual.Palette.bronze
  /// Deprecated — neutral. Prefer `inkSecondary`.
  static let bronzeAccentSoft = HaloVisual.Palette.bronzeSoft
  /// Attention — errors, downgrades, reports only. The one coloured token that
  /// is not a person: semantic, not accent.
  static let attention = Color(hex: "#FF2B6E")

  // MARK: - Legacy SWARM activation aliases (deprecated, neutral)

  static let orbitalBlue = bronzeAccent
  static let signalGreen = bronzeAccentSoft
  /// Legacy name — resolves to the semantic attention colour.
  static let launchAmber = attention

  // MARK: - Semantic surfaces

  static let background = HaloVisual.Palette.ground
  static let surface = cream.opacity(0.055)
  static let surfaceRaised = cream.opacity(0.085)
  static let surfaceModal = cream.opacity(0.11)
  static let edge = cream.opacity(0.035)

  // MARK: - Semantic ink

  static let ink = cream
  static let inkSecondary = cream.opacity(0.68)
  /// Tertiary ink. Bumped to ~0.52 so muted counters/labels clear WCAG AA
  /// (~4.5:1) on warm black instead of reading as disabled.
  static let inkMuted = cream.opacity(0.52)
  static let inkHairline = cream.opacity(0.18)
  static let inkLine = cream.opacity(0.10)
  static let inkWhisper = cream.opacity(0.06)

  // MARK: - Semantic strokes

  static let strokeRest = cream.opacity(0.12)
  static let strokeActive = cream.opacity(0.42)
  static let strokeSoft = cream.opacity(0.08)
  static let strokeHair = cream.opacity(0.16)

  // MARK: - Legacy aliases during migration

  static let warmBlack = HaloVisual.Palette.ground
  static let nightSurface = HaloVisual.Palette.nightSurface
  static let nightSurface2 = HaloVisual.Palette.nightSurface2
  static let nightEdge = HaloVisual.Palette.creamWhisper

  static let paperCream = HaloVisual.Palette.cream
  static let creamLow = HaloVisual.Palette.creamLow
  static let creamMute = HaloVisual.Palette.creamMute
  static let creamHair = HaloVisual.Palette.creamHair
  static let creamLine = HaloVisual.Palette.creamLine
  static let creamWhisper = HaloVisual.Palette.creamWhisper

  static let bronze = HaloVisual.Palette.bronze
  static let bronzeSoft = HaloVisual.Palette.bronzeSoft
  static let bronzeGlow = HaloVisual.Palette.bronzeGlow
  static let warmMagenta = attention

  // MARK: - Radii (docs/DESIGN.md R2 — intimate, not operator)

  /// 6 / 4 / 2 were SWARM-literal: instrument radii, built for density and
  /// precision. A place where you share something personal doesn't have 2px
  /// corners. Softened so the surface reads as calm rather than tactical.
  static let radiusCard:  CGFloat = 20
  static let radiusInput: CGFloat = 16
  static let radiusChip:  CGFloat = 12
  static let radiusPill:  CGFloat = 999
  static let radiusSheet: CGFloat = 28

  // MARK: - Spacing (SWARM 4/8 scale)

  static let s1:  CGFloat = 4
  static let s2:  CGFloat = 8
  static let s3:  CGFloat = 12
  static let s4:  CGFloat = 16
  static let s6:  CGFloat = 24
  static let s8:  CGFloat = 32
  static let s12: CGFloat = 48
  static let s16: CGFloat = 64
  static let s24: CGFloat = 96
  static let s32: CGFloat = 128

  // MARK: - Motion durations

  static let durTap:        Double = 0.12
  static let durCardMount:  Double = 0.32
  static let durStagger:    Double = 0.04
  static let durSheet:      Double = 0.42
  static let durBreath:     Double = 4.0
  static let durLoader:     Double = 0.9
  static let durSelfBreath: Double = 6.0

  // MARK: - Motion easing

  /// SWARM signature easing — `cubic-bezier(0.2, 0.7, 0.1, 1)`.
  /// Use this for every transition that isn't a snap/tactical action.
  static let easeSwarm = Animation.timingCurve(0.2, 0.7, 0.1, 1)

  /// SWARM easing with explicit duration override.
  static func easeSwarm(_ duration: Double) -> Animation {
    .timingCurve(0.2, 0.7, 0.1, 1, duration: duration)
  }
}

// MARK: - Type scale

/// Type scale. Hero is capped at 72 for mobile. Values are base px; the global
/// `HaloType.scale` multiplier is applied on top at render time.
///
/// One family across every step (`docs/DESIGN.md` R3): this ramp plus weight
/// and opacity is the whole hierarchy.
enum SwarmHaloTypeScale {
  static let hero: CGFloat = 72
  static let h1: CGFloat = 40
  static let h2: CGFloat = 28
  static let h3: CGFloat = 22
  static let lede: CGFloat = 17
  static let body: CGFloat = 15
  static let ui: CGFloat = 13
  static let eyebrow: CGFloat = 11
}

// MARK: - Halo tier mapping

/// App-side state mapping. `HaloShared` stays data-only and never imports
/// SwiftUI color types.
enum SwarmHaloTierState {
  case connected
  case operational
  case rest
  case farRest

  // Relational distance is rendered as *presence*, not as hue —
  // `docs/DESIGN.md` R4. Closer people are more present: brighter ink, a
  // stronger edge, a wider glow. Nothing here carries a brand colour, so the
  // only colour on a person is their own mood (`MoodPalette.auraColor`).
  //
  // Keeping distance on the neutral channel also means hue stays free to mean
  // exactly one thing, everywhere in the app: someone is there.

  /// Ink weight for the tier. Nearer reads brighter.
  var accent: Color {
    switch self {
    case .connected: return SwarmHalo.cream
    case .operational: return SwarmHalo.cream.opacity(0.72)
    case .rest: return SwarmHalo.cream.opacity(0.44)
    case .farRest: return SwarmHalo.cream.opacity(0.16)
    }
  }

  var stroke: Color {
    switch self {
    case .connected: return SwarmHalo.cream.opacity(0.42)
    case .operational: return SwarmHalo.cream.opacity(0.26)
    case .rest: return SwarmHalo.strokeHair
    case .farRest: return SwarmHalo.cream.opacity(0.07)
    }
  }

  var activeStroke: Color {
    switch self {
    case .connected: return SwarmHalo.cream.opacity(0.80)
    case .operational: return SwarmHalo.cream.opacity(0.58)
    case .rest: return SwarmHalo.cream.opacity(0.36)
    case .farRest: return SwarmHalo.cream.opacity(0.10)
    }
  }

  var ringFill: Color {
    switch self {
    case .connected: return SwarmHalo.cream.opacity(0.10)
    case .operational: return SwarmHalo.surfaceRaised
    case .rest: return SwarmHalo.cream.opacity(0.055)
    case .farRest: return SwarmHalo.cream.opacity(0.02)
    }
  }

  /// Neutral presence glow, decaying with distance. A *person's* halo is their
  /// mood — use `MoodPalette.auraRing(mood:)` where the mood is known; this is
  /// the fallback for surfaces that only know the tier.
  var glow: Color {
    switch self {
    case .connected: return SwarmHalo.cream.opacity(0.14)
    case .operational: return SwarmHalo.cream.opacity(0.08)
    case .rest: return SwarmHalo.cream.opacity(0.04)
    case .farRest: return .clear
    }
  }

  var badgeFill: Color {
    switch self {
    case .connected: return SwarmHalo.cream.opacity(0.11)
    case .operational: return SwarmHalo.cream.opacity(0.07)
    case .rest: return SwarmHalo.inkWhisper
    case .farRest: return SwarmHalo.cream.opacity(0.03)
    }
  }
}

extension FriendshipTier {
  var swarmHaloState: SwarmHaloTierState {
    switch self {
    case .inner: return .connected
    case .close: return .operational
    case .orbit: return .rest
    case .nebula: return .farRest
    case .asteroid: return .farRest
    }
  }
}

// MARK: - Type families
//
// Removed: `SwarmHaloFont` named the five bundled faces (Cormorant Garamond,
// Satoshi, Inter, IBM Plex Mono, Space Grotesk). Per `docs/DESIGN.md` R3 the
// app uses one family — the system face — so there are no PostScript names to
// resolve and no silent-fallback risk when one is missing.
//
// The .ttf files in `HaloApp/Resources/Fonts/` (~2.4 MB) and their `UIAppFonts`
// entries in Info.plist are now unreferenced. Removing them touches the Xcode
// project, so it is tracked separately in PLAN.md rather than done here.

// MARK: - App-wide editable visual direction

/// Single edit point for the current Halo visual direction.
///
/// Keep surface-specific views wired to these values instead of hardcoding
/// hex colors, mood hues, radii, or key sizing constants in feature files.
enum HaloVisual {
  enum Palette {
    /// True black. Shadows, scrims and the far-rest void only — never a
    /// background. See `ground`.
    static let absoluteBlack = Color(hex: "#000000")

    /// The app ground. Barely cold, never pure black: per `docs/DESIGN.md` R2
    /// the dark is *intimate* (evening, bedroom, lockscreen), not *premium*.
    /// Pure black reads as high-contrast and clinical.
    static let ground = Color(hex: "#0B0C0E")
    static let warmBlack = ground

    static let nightSurface = Color(hex: "#141619")
    static let nightSurface2 = Color(hex: "#191C20")

    /// Primary ink. Plain white at varying opacity — `docs/DESIGN.md` §5.
    /// The paper-cream `#E4DDCF` belonged to the editorial direction that made
    /// the app read as a magazine; the token name is kept so call sites survive.
    static let cream = Color(hex: "#FFFFFF")
    static let creamLow = cream.opacity(0.66)
    /// ~0.50 keeps muted labels above WCAG AA on the ground.
    static let creamMute = cream.opacity(0.50)
    static let creamHair = cream.opacity(0.16)
    static let creamLine = cream.opacity(0.09)
    static let creamWhisper = cream.opacity(0.05)

    // MARK: - No brand accent (docs/DESIGN.md R4)
    //
    // Halo has no accent colour. The only colour in the app comes from the
    // mood states of people, via `HaloVisual.Aura` / `MoodPalette` — so colour
    // means something literal: colour = someone is there.
    //
    // These three tokens were the bronze accent. They now resolve to neutral
    // ink so no surface renders brand colour, and the names stay put so the
    // ~20 call sites keep compiling while they are migrated to either plain
    // ink or a real mood colour.

    /// Deprecated: was `#A88260`. Now neutral — prefer `SwarmHalo.ink`.
    static let bronze = cream.opacity(0.92)
    /// Deprecated: now neutral — prefer `SwarmHalo.inkSecondary`.
    static let bronzeSoft = cream.opacity(0.55)
    /// Deprecated: a presence glow with no hue. For a person's glow use
    /// `MoodPalette.auraRing(mood:)` — that one carries meaning.
    static let bronzeGlow = cream.opacity(0.14)

    static let glassInkFill = ground
  }

  enum Aura {
    static func color(_ mood: Mood, alpha: Double = 1) -> Color {
      color(mood, luminance: nil, alpha: alpha)
    }

    static func color(_ mood: Mood, luminance: Double?, alpha: Double = 1) -> Color {
      let token = token(for: mood)
      return Color.fromOKLCH(l: luminance ?? token.l, c: token.c, h: token.h, alpha: alpha)
    }

    /// Luminanza relativa WCAG del fill aura per un mood alla luminanza `luminance`.
    static func relativeLuminance(_ mood: Mood, luminance: Double? = nil) -> Double {
      let token = token(for: mood)
      return Color.oklchRelativeLuminance(l: luminance ?? token.l, c: token.c, h: token.h)
    }

    private static func token(for mood: Mood) -> (l: Double, c: Double, h: Double) {
      switch mood {
      case .chill:
        return (0.78, 0.10, 220)
      case .wild:
        return (0.74, 0.18, 30)
      case .focused:
        return (0.78, 0.12, 160)
      case .warm:
        return (0.80, 0.14, 60)
      case .electric:
        return (0.86, 0.18, 145)
      case .blue:
        return (0.66, 0.16, 250)
      case .soft:
        return (0.82, 0.10, 350)
      case .lost:
        return (0.62, 0.07, 290)
      }
    }
  }

  enum Typography {
    /// Legacy name. One family now (`docs/DESIGN.md` R3) — this resolves to
    /// the system face like every other role. Prefer `HaloType.ui(_:weight:)`.
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
      .system(size: size, weight: weight)
    }
  }

  enum Chrome {
    static let controlFill = HaloVisual.Palette.ground.opacity(0.76)
    static let contentFill = HaloVisual.Palette.ground.opacity(0.88)
    static let fallbackFill = HaloVisual.Palette.ground
    static let stroke = HaloVisual.Palette.cream.opacity(0.14)
    static let contentStroke = HaloVisual.Palette.cream.opacity(0.09)
  }

  enum Orbita {
    static let chromeFill = HaloVisual.Palette.ground.opacity(0.94)
    static let chromeFillStrong = HaloVisual.Palette.ground
    static let chromeStroke = HaloVisual.Palette.cream.opacity(0.14)
    /// Selection is neutral: brighter, not tinted (`docs/DESIGN.md` R4).
    static let chromeStrokeStrong = HaloVisual.Palette.cream.opacity(0.40)
    static let selectedFill = HaloVisual.Palette.cream.opacity(0.12)
    static let selectedStroke = HaloVisual.Palette.cream.opacity(0.34)

    static let contentTopPadding: CGFloat = 48
    static let sectionGap: CGFloat = 12

    static let headerHorizontalPadding: CGFloat = 26
    static let headerTopPadding: CGFloat = 14
    static let headerBottomPadding: CGFloat = 4
    static let logoRingSize: CGFloat = 9
    static let logoRingLeading: CGFloat = 18
    static let logoTextSize: CGFloat = 15
    static let logoTracking: CGFloat = 6.3
    static let logoTextLeading: CGFloat = 6.3
    static let vibePillTopPadding: CGFloat = 12
    static let vibePillHorizontalPadding: CGFloat = 11
    static let vibePillVerticalPadding: CGFloat = 6
    static let vibeDotSize: CGFloat = 7
    static let headerPillFillOpacity = 0.55

    static let heroHorizontalPadding: CGFloat = 22
    static let heroTopPadding: CGFloat = 14
    static let heroCardRadius: CGFloat = 24
    static let heroCardHorizontalPadding: CGFloat = 12
    static let heroCardVerticalPadding: CGFloat = 10
    static let heroPortraitSize: CGFloat = 44
    static let heroPortraitFontSize: CGFloat = 22
    static let heroDotSize: CGFloat = 8

    static let fieldBaseWidth: CGFloat = 396
    static let fieldBaseHeight: CGFloat = 533
    static let fieldMinScale: CGFloat = 0.86
    static let innerRadius: CGFloat = 78
    static let closeRadius: CGFloat = 130
    static let orbitRadius: CGFloat = 172
    static let innerBubbleSize: CGFloat = 36
    static let closeBubbleSize: CGFloat = 26
    static let orbitBubbleSize: CGFloat = 18

    static let selfOuterSize: CGFloat = 64
    static let selfInnerSize: CGFloat = 48
    static let selfFrameSize: CGFloat = 118

    static let zoomRailTrailingPadding: CGFloat = 8
    static let zoomRailControlSize: CGFloat = 34
    static let zoomRailHorizontalPadding: CGFloat = 2
    static let zoomRailVerticalPadding: CGFloat = 6
    static let zoomRailIdleOpacity = 0.30
    static let zoomRailActiveOpacity = 0.92
    static let zoomRailLineHeight: CGFloat = 64

    static let footerBottomPadding: CGFloat = 92
    static let footerSafeAreaExtra: CGFloat = 70

    static let dockHorizontalPadding: CGFloat = 18
    static let dockInnerHorizontalPadding: CGFloat = 10
    static let dockVerticalPadding: CGFloat = 8
    static let dockTabHeight: CGFloat = 44
    static let dockSelectedRadius: CGFloat = 25
    static let dockComposeSize: CGFloat = 52
    static let dockStroke = HaloVisual.Palette.cream.opacity(0.14)
    static let dockShadow = HaloVisual.Palette.absoluteBlack.opacity(0.40)
  }

  enum AudioRecorder {
    static let panelRadius: CGFloat = 24
    static let fieldRadius: CGFloat = 18
    static let controlSize: CGFloat = 64
    static let iconSize: CGFloat = 22
    static let waveformHeight: CGFloat = 70

    static let surfaceFill = HaloVisual.Palette.absoluteBlack
    static let controlFill = HaloVisual.Palette.absoluteBlack
    static let stroke = HaloVisual.Palette.creamLine
    static let activeStroke = HaloVisual.Palette.bronze.opacity(0.58)
  }
}
