import SwiftUI
import UIKit
import HaloShared

/// Sheet "peek" che si apre tappando una bolla. Contiene:
///  - header con portrait + nome + handle + tier
///  - chip vibe corrente
///  - 3 finte halo posts (foto / testo / audio)
///  - reaction bar con i 6 glyph custom
struct HaloSpacePeekSheet: View {
  let person: HaloPersonNode
  @State private var selectedReactions: Set<String> = []

  private let posts: [DemoPost]

  init(person: HaloPersonNode) {
    self.person = person
    self.posts = [
      DemoPost(id: 1, kind: .photo, caption: person.note.isEmpty ? "oggi così" : person.note, ago: "2h"),
      DemoPost(id: 2, kind: .text,  caption: "mi sto rendendo conto che l’autunno è la mia stagione preferita da sempre", ago: "8h"),
      DemoPost(id: 3, kind: .audio, caption: "voice note · 14s", ago: "1g"),
    ]
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        header
        vibeChip
        ForEach(posts) { post in
          postCard(post)
            .padding(.horizontal, HaloVisual.HaloSpace.peekHorizontalPadding)
            .padding(.bottom, 12)
        }
      }
      .padding(.top, 4)
      .padding(.bottom, 40)
    }
    .background(haloSheetBackground())
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(.clear)
  }

  // MARK: header

  private var header: some View {
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [MoodPalette.auraRing(person.mood, alpha: 0.55), .clear],
              center: .center, startRadius: 0, endRadius: 50
            )
          )
          .frame(width: HaloVisual.HaloSpace.peekAvatarAuraSize, height: HaloVisual.HaloSpace.peekAvatarAuraSize)
        Circle()
          .fill(person.tier.swarmHaloState.ringFill)
          .frame(width: HaloVisual.HaloSpace.peekAvatarRingSize, height: HaloVisual.HaloSpace.peekAvatarRingSize)
          .overlay(Circle().strokeBorder(person.tier.swarmHaloState.stroke, lineWidth: 0.8))
          .shadow(color: person.tier.swarmHaloState.glow, radius: 9)
        PortraitView(personId: person.id, size: HaloVisual.HaloSpace.peekPortraitSize, grayscale: true)
          .background(HaloTheme.portraitBacking, in: Circle())
      }
      .frame(width: HaloVisual.HaloSpace.peekAvatarRingSize, height: HaloVisual.HaloSpace.peekAvatarRingSize)

      VStack(alignment: .leading, spacing: 1) {
        Text(person.name)
          .font(HaloType.serif(22, weight: .regular))
          .foregroundStyle(HaloInk.cream)
        Text("@\(person.handle) · \(person.tier.label)")
          .font(HaloType.ui(13, weight: .regular))
          .foregroundStyle(HaloInk.creamLow)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, HaloVisual.HaloSpace.peekHorizontalPadding).padding(.top, 20).padding(.bottom, 16)
  }

  private var vibeChip: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(MoodPalette.auraColor(person.mood, l: 0.8))
        .frame(width: 10, height: 10)
        .shadow(color: MoodPalette.auraRing(person.mood, alpha: 0.55), radius: 4)
      Text(person.mood.rawValue)
        .font(HaloType.ui(14, weight: .medium))
        .foregroundStyle(HaloInk.cream)
      if !person.note.isEmpty {
        Text("“\(person.note)”")
          .font(HaloType.serif(15, weight: .regular))
          .foregroundStyle(HaloInk.creamLow)
          .lineLimit(1)
          .truncationMode(.tail)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .haloContentGlass(in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.fieldRadius))
    .padding(.horizontal, HaloVisual.HaloSpace.peekHorizontalPadding).padding(.bottom, 16)
  }

  // MARK: posts

  private func postCard(_ post: DemoPost) -> some View {
    VStack(spacing: 0) {
      switch post.kind {
      case .photo:  photoBody(post)
      case .text:   textBody(post)
      case .audio:  audioBody(post)
      }
      reactionsRow(for: post)
    }
    .haloContentGlass(in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.cardRadius))
    .clipShape(RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.cardRadius))
  }

  private func photoBody(_ post: DemoPost) -> some View {
    ZStack(alignment: .bottomLeading) {
      LinearGradient(
        colors: [
          MoodPalette.auraColor(person.mood, l: 0.5),
          MoodPalette.auraColor(person.mood, l: 0.25),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
      .frame(height: 160)

      // Diagonal stripes overlay (15% opacity)
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
      .frame(height: 160)

      VStack(alignment: .leading, spacing: 6) {
        Text("foto · \(post.ago)")
          .font(HaloType.mono(10, weight: .medium))
          .kerning(1.0)
          .foregroundStyle(HaloInk.creamLow)
        if !post.caption.isEmpty {
          Text(post.caption)
            .font(HaloType.serif(15, weight: .regular))
            .foregroundStyle(HaloInk.cream)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(SwarmHalo.absoluteBlack.opacity(0.42))
    }
  }

  private func textBody(_ post: DemoPost) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(post.caption)
        .font(HaloType.serif(18, weight: .regular))
        .lineSpacing(4)
        .foregroundStyle(HaloInk.cream)
      Text("testo · \(post.ago)")
        .font(HaloType.mono(10, weight: .medium))
        .kerning(1.0)
        .foregroundStyle(HaloInk.creamMute)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func audioBody(_ post: DemoPost) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle().fill(MoodPalette.auraColor(person.mood, l: 0.7))
        Image(systemName: "play.fill")
          .font(HaloType.system(12, weight: .bold))
          .foregroundStyle(SwarmHalo.background)
          .offset(x: 1)
      }
      .frame(width: 38, height: 38)

      VStack(alignment: .leading, spacing: 4) {
        // waveform pseudo-statica
        HStack(spacing: 2) {
          ForEach(0..<22, id: \.self) { i in
            Capsule()
              .fill(SwarmHalo.ink.opacity(0.15 + (Double(i) / 28) * 0.4))
              .frame(width: 3, height: CGFloat(7 + abs(sin(Double(i) * 1.4)) * 17))
          }
        }
        .frame(height: 24)

        Text("\(post.caption) · \(post.ago)")
          .font(HaloType.mono(10, weight: .medium))
          .kerning(1.0)
          .foregroundStyle(HaloInk.creamMute)
      }
    }
    .padding(16)
  }

  private func reactionsRow(for post: DemoPost) -> some View {
    HStack(spacing: 2) {
      ForEach(ReactionKind.allCases, id: \.self) { r in
        let key = "\(post.id)-\(r.rawValue)"
        let on = selectedReactions.contains(key)
        Button {
          if on { selectedReactions.remove(key) } else { selectedReactions.insert(key) }
          UISelectionFeedbackGenerator().selectionChanged()
        } label: {
          ReactionGlyph(
            kind: r,
            size: 18,
            color: on ? MoodPalette.auraColor(person.mood, l: 0.85) : SwarmHalo.ink.opacity(0.45)
          )
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(on ? SwarmHalo.ink.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.fieldRadius))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 8)
    .overlay(alignment: .top) {
      Rectangle().fill(SwarmHalo.inkWhisper).frame(height: 0.5)
    }
  }
}

// MARK: - models

private struct DemoPost: Identifiable {
  enum Kind { case photo, text, audio }
  let id: Int
  let kind: Kind
  let caption: String
  let ago: String
}

// MARK: - shared sheet background

func haloSheetBackground() -> some View {
  Rectangle()
    .fill(.clear)
    .haloGlass(
      in: UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: HaloTheme.sheetCornerRadius, topTrailing: HaloTheme.sheetCornerRadius)
      ),
      interactive: false
    )
  .clipShape(
    UnevenRoundedRectangle(
      cornerRadii: .init(topLeading: HaloTheme.sheetCornerRadius, topTrailing: HaloTheme.sheetCornerRadius)
    )
  )
  .ignoresSafeArea()
}
