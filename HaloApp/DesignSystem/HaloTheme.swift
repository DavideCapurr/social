import SwiftUI

/// Halo theme — thin backwards-compatible facade over `SwarmHalo`.
///
/// All concrete values live in `Tokens.swift`. This file exists so that
/// the dozens of components that already reference `HaloTheme.*` keep
/// working without a global refactor.
enum HaloTheme {
  // Background tokens
  static let pureBlack         = SwarmHalo.absoluteBlack
  static let background        = SwarmHalo.background
  static let surface           = SwarmHalo.surface
  static let surfaceModal      = SwarmHalo.surfaceModal
  static let portraitBacking   = SwarmHalo.surfaceRaised

  // Text
  static let text              = SwarmHalo.ink
  static let textSecondary     = SwarmHalo.inkSecondary
  static let textMuted         = SwarmHalo.inkMuted
  static let textCaption       = SwarmHalo.inkMuted
  static let textHairline      = SwarmHalo.inkHairline

  // Strokes & rings
  static let hairline          = SwarmHalo.strokeRest
  static let hairlineSoft      = SwarmHalo.strokeSoft
  static let ringInactive      = SwarmHalo.cream.opacity(0.07)
  static let ringActive        = SwarmHalo.strokeActive
  static let glassFallbackFill = HaloVisual.Chrome.fallbackFill
  static let glassStroke       = HaloVisual.Chrome.stroke
  static let glassStrokeSoft   = HaloVisual.Chrome.contentStroke

  static let cornerRadius: CGFloat = SwarmHalo.radiusCard
  static let sheetCornerRadius: CGFloat = SwarmHalo.radiusSheet

  /// Mono digit font for timestamps and counters. Now uses IBM Plex Mono.
  /// Routed through `HaloType.mono` so it inherits the global type scale.
  static let mono = HaloType.mono(11)
}

// MARK: - SWARM semantic primitives

enum SwarmSurfaceRole {
  case field
  case rail
  case panel
  case card
  case sheet
  case control
  case chip

  var fill: Color {
    switch self {
    case .field: return SwarmHalo.background
    case .rail: return SwarmHalo.surfaceRaised
    case .panel: return SwarmHalo.surface
    case .card: return SwarmHalo.surface
    case .sheet: return SwarmHalo.surfaceModal
    case .control: return SwarmHalo.inkWhisper
    case .chip: return SwarmHalo.inkWhisper
    }
  }

  var stroke: Color {
    switch self {
    case .field: return .clear
    case .rail: return SwarmHalo.strokeHair
    case .panel: return SwarmHalo.strokeSoft
    case .card: return SwarmHalo.strokeHair
    case .sheet: return SwarmHalo.strokeRest
    case .control: return SwarmHalo.inkLine
    case .chip: return SwarmHalo.inkLine
    }
  }
}

enum SwarmActivationRole {
  case connected
  case operational
  case rest
  case farRest
  case attention

  var color: Color {
    switch self {
    case .connected: return SwarmHalo.bronze
    case .operational: return SwarmHalo.bronzeSoft
    case .rest: return SwarmHalo.cream
    case .farRest: return SwarmHalo.absoluteBlack
    case .attention: return SwarmHalo.attention
    }
  }

  /// Text-safe accent for values/labels that must stay legible on warm black.
  /// `operational` (bronzeSoft, ~2.5:1) is promoted to full bronze (~5.5:1) so
  /// stat counters like "close" don't read as disabled.
  var textAccent: Color {
    switch self {
    case .connected: return SwarmHalo.bronze
    case .operational: return SwarmHalo.bronze
    case .rest: return SwarmHalo.cream
    case .farRest: return SwarmHalo.cream
    case .attention: return SwarmHalo.attention
    }
  }

  var stroke: Color {
    switch self {
    case .connected, .operational: return color.opacity(0.48)
    case .rest: return SwarmHalo.strokeRest
    case .farRest: return SwarmHalo.cream.opacity(0.08)
    case .attention: return color.opacity(0.58)
    }
  }

  var glow: Color {
    switch self {
    case .connected, .operational: return color.opacity(0.12)
    case .rest: return SwarmHalo.cream.opacity(0.05)
    case .farRest: return .clear
    case .attention: return color.opacity(0.18)
    }
  }

  var fill: Color {
    switch self {
    case .connected, .operational: return color.opacity(0.055)
    case .rest: return SwarmHalo.inkWhisper
    case .farRest: return SwarmHalo.absoluteBlack.opacity(0.72)
    case .attention: return color.opacity(0.075)
    }
  }
}

enum SwarmStroke {
  static let hairline: CGFloat = 0.5
  static let standard: CGFloat = 0.6
  static let active: CGFloat = 0.8
  static let node: CGFloat = 1.0
}

enum SwarmMotion {
  static let tap = SwarmHalo.easeSwarm(SwarmHalo.durTap)
  static let mount = SwarmHalo.easeSwarm(SwarmHalo.durCardMount)
  static let sheet = SwarmHalo.easeSwarm(SwarmHalo.durSheet)
  static let loader = SwarmHalo.easeSwarm(SwarmHalo.durLoader)
  static let breath = SwarmHalo.easeSwarm(SwarmHalo.durBreath)
}

extension View {
  func swarmSurface<S: InsettableShape>(
    _ role: SwarmSurfaceRole = .panel,
    in shape: S,
    activation: SwarmActivationRole? = nil
  ) -> some View {
    let stroke = activation?.stroke ?? role.stroke
    return self
      .background(role.fill, in: shape)
      .overlay(shape.strokeBorder(stroke, lineWidth: SwarmStroke.standard))
  }

  func swarmRail() -> some View {
    self
      .padding(.horizontal, SwarmHalo.s3)
      .padding(.vertical, SwarmHalo.s2)
      .swarmSurface(.rail, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous))
      .shadow(color: SwarmHalo.absoluteBlack.opacity(0.28), radius: 18, y: 10)
  }

  func swarmPanel() -> some View {
    self
      .swarmSurface(.panel, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous))
  }

  func swarmChip(active: Bool = false, activation: SwarmActivationRole = .rest) -> some View {
    self
      .padding(.horizontal, SwarmHalo.s3)
      .padding(.vertical, SwarmHalo.s2)
      .background(active ? activation.color.opacity(0.10) : Color.clear, in: Capsule())
      .haloGlass(
        in: Capsule(),
        tint: active ? activation.color.opacity(0.18) : nil,
        stroke: active ? activation.stroke : SwarmSurfaceRole.chip.stroke
      )
      .shadow(color: active ? activation.glow : .clear, radius: 6, y: 2)
  }

  func swarmIconFrame(active: Bool = false, activation: SwarmActivationRole = .rest) -> some View {
    self
      .frame(width: 36, height: 36)
      .background(active ? activation.fill : SwarmHalo.inkWhisper, in: Circle())
      .overlay(Circle().strokeBorder(active ? activation.stroke : SwarmHalo.inkLine, lineWidth: SwarmStroke.hairline))
      .shadow(color: active ? activation.glow : .clear, radius: 8)
  }

  /// Compatibility path for existing controls. iOS 26 uses native Liquid Glass;
  /// older OS versions fall back to black surfaces, never gray materials.
  @ViewBuilder
  func haloGlass<S: InsettableShape>(
    in shape: S,
    tint: Color? = nil,
    interactive: Bool = false,
    stroke: Color = HaloTheme.glassStroke
  ) -> some View {
    if #available(iOS 26.0, *) {
      self
        .background(HaloVisual.Chrome.controlFill, in: shape)
        .glassEffect(.regular.tint(tint ?? HaloVisual.Chrome.controlFill).interactive(interactive), in: shape)
        .overlay(shape.strokeBorder(stroke, lineWidth: 0.6))
    } else {
      self
        .background(HaloTheme.glassFallbackFill, in: shape)
        .overlay(shape.strokeBorder(stroke, lineWidth: 0.6))
    }
  }

  /// Quieter native glass for cards and content surfaces.
  @ViewBuilder
  func haloContentGlass<S: InsettableShape>(
    in shape: S,
    stroke: Color = HaloTheme.glassStrokeSoft
  ) -> some View {
    if #available(iOS 26.0, *) {
      self
        .background(HaloVisual.Chrome.contentFill, in: shape)
        .glassEffect(.regular.tint(HaloVisual.Chrome.contentFill), in: shape)
        .overlay(shape.strokeBorder(stroke, lineWidth: 0.5))
    } else {
      self
        .background(HaloVisual.Chrome.fallbackFill, in: shape)
        .overlay(shape.strokeBorder(stroke, lineWidth: 0.5))
    }
  }
}

extension Color {
  /// Minimal `#RRGGBB` hex parser. Returns black on invalid input.
  init(hex: String) {
    var h = hex
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else {
      self = .black
      return
    }
    let r = Double((v >> 16) & 0xFF) / 255.0
    let g = Double((v >>  8) & 0xFF) / 255.0
    let b = Double( v        & 0xFF) / 255.0
    self = Color(red: r, green: g, blue: b)
  }
}

// MARK: - Reusable SWARM components

struct SwarmOperationalRail<Trailing: View>: View {
  let title: String
  let context: String
  var activation: SwarmActivationRole = .rest
  @ViewBuilder var trailing: () -> Trailing

  init(
    title: String,
    context: String,
    activation: SwarmActivationRole = .rest,
    @ViewBuilder trailing: @escaping () -> Trailing
  ) {
    self.title = title
    self.context = context
    self.activation = activation
    self.trailing = trailing
  }

  var body: some View {
    HStack(spacing: SwarmHalo.s3) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .haloEyebrow(activation.color.opacity(0.86), size: 8.5, tracking: 2.4)
        Text(context)
          .font(HaloType.mono(9, weight: .medium))
          .kerning(1.4)
          .textCase(.uppercase)
          .foregroundStyle(SwarmHalo.inkMuted)
      }
      Rectangle()
        .fill(SwarmHalo.inkLine)
        .frame(height: SwarmStroke.hairline)
      trailing()
    }
    .swarmRail()
  }
}

extension SwarmOperationalRail where Trailing == EmptyView {
  init(title: String, context: String, activation: SwarmActivationRole = .rest) {
    self.init(title: title, context: context, activation: activation) {
      EmptyView()
    }
  }
}

struct SwarmCommandButton: View {
  let label: String
  var icon: String? = nil
  var activation: SwarmActivationRole = .rest
  var isProminent: Bool = false
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: SwarmHalo.s2) {
        if let icon {
          Image(systemName: icon)
            .font(HaloType.system(13, weight: .semibold))
        }
        Text(label)
          .font(HaloType.ui(13, weight: .semibold))
      }
      .foregroundStyle(isProminent ? SwarmHalo.background : SwarmHalo.ink)
      .padding(.horizontal, SwarmHalo.s4)
      .padding(.vertical, 10)
      .background(isProminent ? activation.color : activation.fill, in: Capsule())
      .overlay(Capsule().strokeBorder(isProminent ? activation.color.opacity(0.92) : activation.stroke, lineWidth: SwarmStroke.standard))
      .shadow(color: isProminent ? activation.glow : .clear, radius: 10, y: 4)
    }
    .buttonStyle(.plain)
  }
}

struct SwarmMetricTile: View {
  let label: String
  let value: String
  var activation: SwarmActivationRole = .rest
  var active: Bool = false

  var body: some View {
    VStack(spacing: 3) {
      Text(value)
        .font(HaloType.mono(15, weight: .semibold))
        .kerning(0.8)
        .foregroundStyle(active ? activation.textAccent : SwarmHalo.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(label)
        .haloEyebrow(SwarmHalo.inkMuted, size: 7.2, tracking: 1.7)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .frame(minWidth: 42)
  }
}

struct SwarmEmptyState: View {
  let title: String
  let message: String
  var activation: SwarmActivationRole = .rest
  /// Optional nudge. When present, empty states suggest an action instead of
  /// only informing.
  var actionTitle: String? = nil
  var actionIcon: String? = nil
  var action: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: SwarmHalo.s3) {
      ZStack {
        Circle()
          .strokeBorder(activation.stroke, style: StrokeStyle(lineWidth: SwarmStroke.standard, dash: [3, 5]))
          .frame(width: 68, height: 68)
        Circle()
          .fill(activation.color.opacity(0.16))
          .frame(width: 8, height: 8)
      }
      Text(title)
        .font(HaloType.serif(24, weight: .regular))
        .foregroundStyle(SwarmHalo.ink)
      Text(message)
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(SwarmHalo.inkSecondary)
        .multilineTextAlignment(.center)

      if let actionTitle, let action {
        SwarmCommandButton(label: actionTitle, icon: actionIcon, activation: activation, isProminent: true, action: action)
          .padding(.top, SwarmHalo.s1)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, SwarmHalo.s8)
    .padding(.horizontal, SwarmHalo.s4)
    .swarmSurface(.panel, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous), activation: activation)
  }
}

struct SwarmLoadingState: View {
  let label: String

  var body: some View {
    VStack(spacing: SwarmHalo.s3) {
      ProgressView()
        .tint(SwarmHalo.ink)
      Text(label)
        .haloEyebrow(SwarmHalo.inkMuted, size: 8, tracking: 1.8)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, SwarmHalo.s8)
    .swarmSurface(.panel, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous))
  }
}
