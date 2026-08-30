import SwiftUI
import HaloShared

/// Sheet di conferma cambio tier proposto via drag.
/// Mostra: titolo "Porta più vicino?" / "Sposta più distante?" + diagramma badge tier
/// + spiegazione cosa cambia in visibilità + due CTA.
struct TierConfirmationSheet: View {
  struct Proposal: Equatable {
    let person: HaloPersonNode
    let from: FriendshipTier
    let to: FriendshipTier
    var closer: Bool { to.rank > from.rank } // verso inner (più alto)
  }

  let proposal: Proposal
  var onAccept: () -> Void = {}
  var onDecline: () -> Void = {}

  var body: some View {
    VStack(spacing: 0) {
      header
      diagram
      explanation
      actions
    }
    .padding(.bottom, 30)
    .background(haloSocialSheetBackground())
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(HaloVisual.SocialSheet.background)
  }

  private var header: some View {
    VStack(spacing: 8) {
      Text("SPOSTA NEL TUO HALO")
        .font(HaloType.eyebrow(11))
        .kerning(2.4)
        .foregroundStyle(HaloInk.creamMute)

      VStack(spacing: 2) {
        HStack(spacing: 5) {
          Text(proposal.closer ? "porta" : "sposta")
            .foregroundStyle(HaloInk.cream)
          Text(proposal.person.name)
            .foregroundStyle(MoodPalette.auraColor(proposal.person.mood, l: 0.85))
        }
        Text(proposal.closer ? "più vicino." : "più distante.")
          .foregroundStyle(HaloInk.cream)
      }
      .font(HaloType.serif(28, weight: .regular))
      .multilineTextAlignment(.center)
    }
    .padding(.horizontal, HaloVisual.SocialSheet.footerHorizontalPadding)
    .padding(.top, 22)
    .padding(.bottom, 8)
  }

  private var diagram: some View {
    HStack(spacing: 22) {
      tierBadge(proposal.from, dimmed: true, highlight: nil)
      Image(systemName: "arrow.right")
        .font(HaloType.system(15, weight: .regular))
        .foregroundStyle(HaloInk.cream.opacity(0.55))
      tierBadge(proposal.to, dimmed: false, highlight: MoodPalette.auraColor(proposal.person.mood, l: 0.75))
    }
    .padding(.vertical, 22)
  }

  private func tierBadge(_ tier: FriendshipTier, dimmed: Bool, highlight: Color?) -> some View {
    VStack(spacing: 6) {
      ZStack {
        if let highlight {
          Circle()
            .fill(
              RadialGradient(
                colors: [highlight.opacity(0.15), .clear],
                center: .center, startRadius: 0, endRadius: 30
              )
            )
        }
        Circle()
          .strokeBorder(
            highlight ?? HaloInk.cream.opacity(0.3),
            style: .init(lineWidth: 1, dash: dimmed ? [3, 3] : [])
          )
        Text(tier.label)
          .font(HaloType.eyebrow(10))
          .kerning(1.8)
          .textCase(.uppercase)
          .foregroundStyle(highlight ?? HaloInk.creamLow)
      }
      .frame(width: 54, height: 54)
      .opacity(dimmed ? 0.55 : 1)

      Text("cap \(tier.softCap.map(String.init) ?? "∞")")
        .font(HaloType.mono(10, weight: .medium))
        .kerning(1.0)
        .foregroundStyle(HaloInk.creamMute)
    }
  }

  private var explanation: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(visibilityText)
        .font(HaloType.ui(14, weight: .regular))
        .lineSpacing(3)
        .foregroundStyle(HaloInk.cream)
      Text("richiede conferma anche da \(proposal.person.name).")
        .font(HaloType.serif(13, weight: .regular))
        .foregroundStyle(HaloInk.creamMute)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .haloSocialSurface(in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous))
    .padding(.horizontal, HaloVisual.SocialSheet.footerHorizontalPadding)
  }

  private var actions: some View {
    HStack(spacing: 10) {
      Button(action: onDecline) {
        Text("annulla")
          .font(HaloType.ui(15, weight: .medium))
          .foregroundStyle(HaloInk.creamLow)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .frame(minHeight: HaloVisual.SocialSheet.actionHeight)
          .haloSocialSurface(
            in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous),
            fill: HaloVisual.SocialSheet.controlFill
          )
      }
      .buttonStyle(.plain)

      Button(action: onAccept) {
        Text("invia richiesta")
          .font(HaloType.ui(15, weight: .semibold))
          .foregroundStyle(SwarmHalo.background)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .frame(minHeight: HaloVisual.SocialSheet.actionHeight)
          .background(
            LinearGradient(
              colors: [
                MoodPalette.auraColor(proposal.person.mood, l: 0.78),
                MoodPalette.auraColor(proposal.person.mood, l: 0.5),
              ],
              startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous)
          )
          .shadow(color: MoodPalette.auraRing(proposal.person.mood, alpha: 0.5), radius: 12, y: 4)
          .overlay(
            RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous)
              .strokeBorder(MoodPalette.auraColor(proposal.person.mood, l: 0.74).opacity(0.62), lineWidth: 0.6)
          )
      }
      .buttonStyle(.plain)
      .layoutPriority(1.3)
    }
    .padding(.horizontal, HaloVisual.SocialSheet.footerHorizontalPadding)
    .padding(.top, 14)
  }

  private var visibilityText: String {
    switch proposal.to {
    case .inner:  return "Potrà vedere tutti i tuoi post (anche audio) e le reazioni emotive in chiaro."
    case .close:  return "Potrà vedere foto, testo e audio. Reazioni in chiaro."
    case .orbit:  return "Vedrà foto e testo. Reazioni solo aggregate."
    case .nebula: return "Vedrà solo la tua presenza e la bio. Niente post."
    case .asteroid: return "Sparirà dai tuoi anelli: resta tra i contatti ma non comparirà più nell'orbita né nelle storie."
    }
  }
}
