import SwiftUI

struct HaloSegment<Value: Hashable>: Identifiable {
  let value: Value
  let title: String
  var systemImage: String?

  var id: Value { value }

  init(_ value: Value, title: String, systemImage: String? = nil) {
    self.value = value
    self.title = title
    self.systemImage = systemImage
  }
}

struct HaloSegmentedControl<Value: Hashable>: View {
  @Binding var selection: Value
  let segments: [HaloSegment<Value>]
  var accent: Color = SwarmHalo.ink
  var minHeight: CGFloat = 48

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: SwarmHalo.s1) {
        controlBody
      }
    } else {
      controlBody
    }
  }

  private var controlBody: some View {
    HStack(spacing: SwarmHalo.s1) {
      ForEach(segments) { segment in
        segmentButton(segment)
      }
    }
    .padding(4)
    .haloContentGlass(in: Capsule(), stroke: HaloTheme.glassStrokeSoft)
  }

  private func segmentButton(_ segment: HaloSegment<Value>) -> some View {
    let isSelected = selection == segment.value

    return Button {
      guard !isSelected else { return }
      HapticEngine.selection()
      withAnimation(SwarmMotion.tap) {
        selection = segment.value
      }
    } label: {
      HStack(spacing: SwarmHalo.s2) {
        if let systemImage = segment.systemImage {
          Image(systemName: systemImage)
            .font(HaloType.system(12, weight: .semibold))
        }

        Text(segment.title)
          .font(HaloType.ui(13, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
      }
      .foregroundStyle(isSelected ? SwarmHalo.ink : SwarmHalo.inkSecondary)
      .frame(maxWidth: .infinity, minHeight: minHeight - 8)
      .padding(.horizontal, SwarmHalo.s2)
      .background(isSelected ? HaloVisual.Palette.absoluteBlack : Color.clear, in: Capsule())
      .haloGlass(
        in: Capsule(),
        tint: HaloVisual.Chrome.controlFill,
        interactive: true,
        stroke: isSelected ? accent.opacity(0.54) : .clear
      )
      .shadow(color: isSelected ? accent.opacity(0.18) : .clear, radius: 8, y: 3)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(segment.title)
    .accessibilityValue(isSelected ? "selezionato" : "non selezionato")
  }
}
