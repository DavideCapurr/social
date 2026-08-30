import SwiftUI
import HaloShared

/// Card di un singolo `HaloPost` con body specifico per tipo (foto/testo/audio),
/// caption opzionale, mood tag e decay indicator (anello che si svuota nelle 72h).
struct PostCardView: View {
  let post: HaloPost
  /// Tier del viewer verso l'autore (per la ReactionBar e gating UI futuro).
  let viewerTier: FriendshipTier
  /// Aggregati di reazioni sul post.
  var reactions: [ReactionsService.Aggregate] = []
  /// Reazioni del viewer (toggle UI).
  var viewerSelected: Set<ReactionKind> = []
  /// Mood usato per accents quando `post.mood` è nil.
  var fallbackMood: Mood = .chill
  var onReact: (ReactionKind) -> Void = { _ in }

  private var accentMood: Mood { post.mood ?? fallbackMood }

  /// Decay 0..1 in base ad `expiresAt - now`.
  private var decay: Double {
    let total = post.expiresAt.timeIntervalSince(post.createdAt)
    let remaining = post.expiresAt.timeIntervalSince(Date.now)
    guard total > 0 else { return 0 }
    return max(0, min(1, remaining / total))
  }

  private var isExpiringSoon: Bool {
    decay > 0 && post.expiresAt.timeIntervalSince(Date.now) < 2 * 3600
  }

  private var ageLabel: String {
    let s = Date.now.timeIntervalSince(post.createdAt)
    if s < 60 { return "adesso" }
    if s < 3600 { return "\(Int(s / 60))m" }
    if s < 86400 { return "\(Int(s / 3600))h" }
    return "\(Int(s / 86400))g"
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      mediaSlot
      if let caption = post.caption, !caption.isEmpty, post.kind != .text {
        Text(caption)
          .font(HaloType.serif(15, weight: .regular))
          .foregroundStyle(HaloInk.cream)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16).padding(.vertical, 10)
      }
      Divider().background(SwarmHalo.inkWhisper)
      ReactionBarView(
        viewerTier: viewerTier,
        aggregates: reactions,
        selected: viewerSelected,
        accentMood: accentMood,
        onTap: onReact
      )
    }
    .haloContentGlass(
      in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.cardRadius),
      stroke: isExpiringSoon ? SwarmHalo.attention.opacity(0.86) : HaloTheme.glassStrokeSoft
    )
    .clipShape(RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.cardRadius))
  }

  // MARK: - header (decay ring + age + mood tag)

  private var header: some View {
    HStack(spacing: 10) {
      ZStack {
        Circle()
          .stroke(SwarmHalo.strokeRest, lineWidth: 1.5)
          .frame(width: 22, height: 22)
        Circle()
          .trim(from: 0, to: decay)
          .stroke(MoodPalette.auraColor(accentMood, l: 0.78),
                  style: .init(lineWidth: 1.8, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .frame(width: 22, height: 22)
        Image(systemName: kindIcon(post.kind))
          .font(HaloType.system(9, weight: .semibold))
          .foregroundStyle(SwarmHalo.inkSecondary)
      }

      Text(ageLabel)
        .font(HaloType.mono(11, weight: .medium))
        .kerning(1.0)
        .foregroundStyle(HaloInk.creamMute)

      Spacer()

      if let mood = post.mood {
        HStack(spacing: 6) {
          Circle()
            .fill(MoodPalette.auraColor(mood, l: 0.82))
            .frame(width: 6, height: 6)
          Text(mood.rawValue)
            .font(HaloType.ui(11, weight: .medium))
            .foregroundStyle(HaloInk.creamLow)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .haloGlass(in: Capsule(), tint: MoodPalette.auraColor(mood, l: 0.55))
      }
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
  }

  private func kindIcon(_ k: PostKind) -> String {
    switch k {
    case .photo: return "photo.fill"
    case .text:  return "text.alignleft"
    case .audio: return "waveform"
    }
  }

  // MARK: - body specific

  @ViewBuilder
  private var mediaSlot: some View {
    switch post.kind {
    case .photo: photoBody
    case .text:  textBody
    case .audio: audioBody
    }
  }

  private var photoBody: some View {
    ZStack(alignment: .bottomLeading) {
      StorageImageView(path: post.mediaPath) {
        photoPlaceholder
      }
    }
    .frame(height: 220)
    .clipped()
  }

  private var photoPlaceholder: some View {
    ZStack {
      LinearGradient(
        colors: [
          MoodPalette.auraColor(accentMood, l: 0.50),
          MoodPalette.auraColor(accentMood, l: 0.25),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      Canvas { ctx, size in
        ctx.opacity = 0.15
        var path = Path()
        let step: CGFloat = 8
        var x: CGFloat = -size.height
        while x < size.width {
          path.move(to: CGPoint(x: x, y: size.height))
          path.addLine(to: CGPoint(x: x + size.height, y: 0))
          x += step
        }
        ctx.stroke(path, with: .color(SwarmHalo.ink.opacity(0.50)), lineWidth: 0.5)
      }
    }
  }

  private var textBody: some View {
    Text(post.caption ?? "—")
      .font(HaloType.serif(20, weight: .regular))
      .lineSpacing(4)
      .foregroundStyle(HaloInk.cream)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16).padding(.vertical, 16)
  }

  private var audioBody: some View {
    HStack(spacing: 12) {
      StorageAudioPlaybackButton(path: post.mediaPath, accentMood: accentMood)
      HStack(spacing: 2) {
        ForEach(0..<24, id: \.self) { i in
          Capsule()
            .fill(SwarmHalo.ink.opacity(0.18 + (Double(i) / 30) * 0.50))
            .frame(width: 2.5, height: CGFloat(8 + abs(sin(Double(i) * 1.4)) * 18))
        }
      }
      .frame(height: 26)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 14)
  }
}
