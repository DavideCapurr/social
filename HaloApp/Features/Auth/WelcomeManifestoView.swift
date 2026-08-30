import SwiftUI

struct WelcomeManifestoView<Actions: View>: View {
  @ViewBuilder var actions: () -> Actions

  init(@ViewBuilder actions: @escaping () -> Actions) {
    self.actions = actions
  }

  var body: some View {
    ZStack {
      DeepSpaceBackground()
      VStack(spacing: SwarmHalo.s6) {
        Spacer(minLength: SwarmHalo.s12)
        manifesto
        ledger
        Spacer(minLength: SwarmHalo.s6)
        actions()
        Spacer().frame(height: SwarmHalo.s6)
      }
      .padding(.horizontal, SwarmHalo.s6)
    }
    .preferredColorScheme(.dark)
  }

  private var manifesto: some View {
    VStack(alignment: .leading, spacing: SwarmHalo.s3) {
      Text("Halo")
        .font(HaloType.serifUpright(64, weight: .medium))
        .foregroundStyle(SwarmHalo.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text("Le tue persone, non il tuo pubblico.")
        .font(HaloType.serif(36, weight: .regular))
        .foregroundStyle(SwarmHalo.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text("presenza, non performance.")
        .haloEyebrow(SwarmHalo.inkSecondary, size: 9, tracking: 2.0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var ledger: some View {
    HStack(spacing: 0) {
      SwarmMetricTile(label: "pubblico", value: "00", activation: .rest, active: false)
      Rectangle().fill(SwarmHalo.inkLine).frame(width: SwarmStroke.hairline, height: 28)
      SwarmMetricTile(label: "inner", value: "05", activation: .connected, active: true)
      Rectangle().fill(SwarmHalo.inkLine).frame(width: SwarmStroke.hairline, height: 28)
      SwarmMetricTile(label: "feed", value: "NO", activation: .attention, active: true)
    }
    .padding(.vertical, SwarmHalo.s3)
    .swarmSurface(.rail, in: RoundedRectangle(cornerRadius: HaloVisual.Auth.panelRadius, style: .continuous), activation: .connected)
  }
}

extension WelcomeManifestoView where Actions == EmptyView {
  init() {
    self.init { EmptyView() }
  }
}
