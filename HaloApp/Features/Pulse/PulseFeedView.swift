import SwiftUI
import HaloShared

/// Pulse: timeline cronologica di Vibe e Moment.
/// Il default resta Inner, ma "Tutti" apre il flusso delle proprie orbite
/// senza trasformare la schermata in una chat di gruppo.
struct PulseFeedView: View {
  @State private var vm = FeedViewModel(bootstrap: DemoMode.isActive ? .seed : .live)
  @State private var moment: HaloMoment = .current()
  @State private var scope: PulseScope = .inner
  @State private var draft: String = ""
  @State private var isDraftOpen: Bool = false

  var onPersonTap: (HaloPersonNode) -> Void = { _ in }

  var body: some View {
    ZStack {
      backgroundLayer

      ScrollView {
        LazyVStack(spacing: 0) {
          headerSection
            .padding(.horizontal, 22)
            .padding(.top, 12)

          PulseScopePicker(selection: $scope)
            .padding(.horizontal, 22)
            .padding(.top, 16)

          pulseSignalDeck
            .padding(.top, 14)
            .padding(.bottom, 12)

          timelineContent

          Spacer().frame(height: 24)
        }
        .padding(.bottom, 16)
      }
      .scrollIndicators(.hidden)
    }
    .safeAreaInset(edge: .bottom) {
      // Composer ancorato appena sopra la tab bar, con scrim opaco: il feed
      // sfuma sotto il dock invece di trasparire dietro le card.
      PulseDropDock(
        scope: scope,
        text: $draft,
        isDraftOpen: $isDraftOpen,
        onPublish: publishDraft,
        onQuickDrop: addQuickDrop
      )
      .padding(.horizontal, 14)
      .padding(.top, HaloVisual.Shell.composerScrimTopPadding)
      .padding(.bottom, HaloVisual.Shell.composerBottomPadding)
      .background(
        LinearGradient(
          stops: [
            .init(color: SwarmHalo.background.opacity(0), location: 0),
            .init(color: SwarmHalo.background.opacity(0.96), location: 0.42),
            .init(color: SwarmHalo.background, location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .allowsHitTesting(false)
      )
    }
    .task {
      moment = .current()
      await vm.load()
    }
  }

  private var backgroundLayer: some View {
    ZStack {
      DeepSpaceBackground()
      let dominant = vm.dominantMood(in: scope) ?? .warm
      RadialGradient(
        colors: [MoodPalette.auraRing(dominant, alpha: 0.14), .clear],
        center: UnitPoint(x: 0.14, y: 0.88),
        startRadius: 0,
        endRadius: 470
      )
      .ignoresSafeArea()
      .animation(SwarmHalo.easeSwarm(0.6), value: dominant)
    }
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(moment.eyebrow)
          .haloEyebrow(HaloInk.creamMute, size: 9.5, tracking: 2.6)
        Rectangle().fill(HaloInk.creamLine).frame(height: 0.5)
      }
      .padding(.bottom, 2)

      Text(moment.headline + ".")
        .font(HaloType.serif(36, weight: .regular))
        .foregroundStyle(HaloInk.cream)
        .lineLimit(1)
        .minimumScaleFactor(0.72)

      Text(scope == .inner ? "Moment spontanei dal tuo Inner" : "tutti i segnali dalle tue orbite")
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)
        .animation(SwarmHalo.easeSwarm(0.18), value: scope)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var pulseSignalDeck: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        pulseMetricTile
        ForEach(vm.pulsePeople(in: scope).prefix(8)) { person in
          PulseSignalTile(person: person)
            .onTapGesture { onPersonTap(person) }
        }
      }
      .padding(.horizontal, 22)
    }
  }

  @ViewBuilder
  private var timelineContent: some View {
    let groups = vm.pulseEventGroups(in: scope)
    if vm.isLoading && groups.isEmpty {
      SwarmLoadingState(label: "carico il Pulse")
        .padding(.horizontal, 22)
        .padding(.top, 14)
    } else if let lastError = vm.lastError {
      SwarmEmptyState(
        title: "pulse fuori portata.",
        message: lastError,
        activation: .attention
      )
      .padding(.horizontal, 22)
      .padding(.top, 14)
    } else if groups.isEmpty {
      SwarmEmptyState(
        title: "nessun Moment.",
        message: scope == .inner
          ? "quando il tuo Inner manda vibe o Moment, li trovi qui."
          : "quando le tue orbite si muovono, il Pulse si accende.",
        activation: .rest
      )
      .padding(.horizontal, 22)
      .padding(.top, 14)
    } else {
      ForEach(groups) { group in
        momentSeparator(group)
          .padding(.horizontal, 22)
          .padding(.top, group.moment == .adesso ? 8 : 22)
          .padding(.bottom, 10)

        ForEach(group.events) { event in
          PulseTimelineRow(event: event) {
            PulseDropCard(
              event: event,
              onPersonTap: { onPersonTap(event.person) },
              onReact: { kind in
                Task { await vm.react(to: event, with: kind) }
              }
            )
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 3)
        }
      }
    }
  }

  private var pulseMetricTile: some View {
    let liveCount = vm.liveEventCount(in: scope)
    let eventCount = vm.pulseEvents(in: scope).count

    return VStack(alignment: .leading, spacing: 8) {
      Text(scope.title)
        .haloEyebrow(HaloInk.creamMute, size: 7.8, tracking: 1.7)
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(String(format: "%02d", liveCount))
          .font(HaloType.mono(22, weight: .semibold))
          .foregroundStyle(liveCount > 0 ? SwarmHalo.ink : HaloInk.cream)
        Text("live")
          .font(HaloType.ui(10, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
      }
      Text("\(eventCount) Moment")
        .font(HaloType.ui(11, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)
    }
    .frame(width: 104, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 11)
    .haloContentGlass(
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      stroke: HaloInk.creamHair
    )
  }

  private var pulseStats: some View {
    let activeCount = vm.pulsePeople(in: scope).filter(\.hasActiveVibe).count
    let eventCount = vm.pulseEvents(in: scope).count
    let liveCount = vm.liveEventCount(in: scope)

    return HStack(alignment: .center, spacing: 0) {
      statCell(scope.title.lowercased(), value: String(format: "%02d", vm.pulsePeople(in: scope).count))
      separator
      statCell("live", value: String(format: "%02d", liveCount), accent: liveCount > 0)
      separator
      statCell("Moment", value: String(format: "%02d", eventCount), accent: activeCount > 0)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .haloContentGlass(
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      stroke: HaloInk.creamHair
    )
  }

  private var separator: some View {
    Rectangle()
      .fill(HaloInk.creamLine)
      .frame(width: 0.5, height: 28)
  }

  private func statCell(_ label: String, value: String, accent: Bool = false) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(HaloType.mono(18, weight: .semibold))
        .foregroundStyle(accent ? SwarmHalo.ink : HaloInk.cream)
      Text(label)
        .haloEyebrow(HaloInk.creamMute, size: 8, tracking: 2.4)
    }
    .frame(maxWidth: .infinity)
  }

  private func momentSeparator(_ group: PulseEventGroup) -> some View {
    HStack(spacing: 10) {
      Text(group.moment.title)
        .haloEyebrow(group.moment == .adesso ? SwarmHalo.inkSecondary : HaloInk.creamMute, size: 9.5, tracking: 3.0)
      Rectangle()
        .fill(group.moment == .adesso ? SwarmHalo.strokeActive : HaloInk.creamLine)
        .frame(height: 0.5)
      Text(String(format: "%02d", group.events.count))
        .font(HaloType.mono(9, weight: .medium))
        .kerning(2.0)
        .foregroundStyle(group.moment == .adesso ? SwarmHalo.inkSecondary : HaloInk.creamMute)
    }
  }

  private func publishDraft() {
    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    Task { await vm.publishMessage(text, audience: scope) }
    draft = ""
    withAnimation(SwarmHalo.easeSwarm(0.18)) {
      isDraftOpen = false
    }
  }

  private func addQuickDrop(_ type: PulseDropDock.DropType) {
    switch type {
    case .note:
      withAnimation(SwarmHalo.easeSwarm(0.18)) {
        isDraftOpen = true
      }
    case .vibe:
      let text = draft
      Task { await vm.publishQuickDrop(.vibe, audience: scope, note: text) }
      draft = ""
      isDraftOpen = false
    }
  }
}

private struct PulseScopePicker: View {
  @Binding var selection: PulseScope

  var body: some View {
    Picker("Feed", selection: $selection) {
      ForEach(PulseScope.allCases) { scope in
        Text(scope.title).tag(scope)
      }
    }
    .pickerStyle(.segmented)
    .tint(SwarmHalo.ink)
  }
}

private struct PulseSignalTile: View {
  let person: HaloPersonNode

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        PortraitView(personId: person.id, size: 30, grayscale: true)
          .background(HaloTheme.portraitBacking, in: Circle())
          .overlay(Circle().strokeBorder(person.tier.swarmHaloState.stroke, lineWidth: 0.6))
        VStack(alignment: .leading, spacing: 1) {
          Text(person.name.lowercased())
            .font(HaloType.ui(11, weight: .semibold))
            .foregroundStyle(HaloInk.cream)
            .lineLimit(1)
          Text(person.tier.label.lowercased())
            .haloEyebrow(HaloInk.creamMute, size: 6.8, tracking: 1.3)
        }
      }

      HStack(spacing: 6) {
        Circle()
          .fill(MoodPalette.auraColor(person.mood, l: 0.78))
          .frame(width: 6, height: 6)
        Text(person.hasActiveVibe ? person.mood.rawValue : "rest")
          .font(HaloType.ui(10, weight: .medium))
          .foregroundStyle(HaloInk.creamLow)
          .lineLimit(1)
      }
    }
    .frame(width: 118, alignment: .leading)
    .padding(.horizontal, 11)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
        .fill(SwarmHalo.inkWhisper)
    )
    .overlay(
      RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
        .strokeBorder(person.hasActiveVibe ? person.tier.swarmHaloState.stroke : HaloInk.creamLine, lineWidth: 0.6)
    )
  }
}

private struct PulseTimelineRow<Content: View>: View {
  let event: PulseEvent
  @ViewBuilder var content: () -> Content

  var body: some View {
    HStack(alignment: .top, spacing: 9) {
      VStack(spacing: 6) {
        Text(timeLabel(event.createdAt))
          .font(HaloType.mono(8, weight: .medium))
          .kerning(0.7)
          .textCase(.uppercase)
          .foregroundStyle(HaloInk.creamMute)
          .frame(width: 34)

        Circle()
          .fill(event.isLive ? event.person.tier.swarmHaloState.accent.opacity(0.82) : HaloInk.creamLine)
          .frame(width: event.isLive ? 7 : 5, height: event.isLive ? 7 : 5)
          .shadow(color: event.isLive ? event.person.tier.swarmHaloState.glow : .clear, radius: 5)

        Rectangle()
          .fill(HaloInk.creamLine)
          .frame(width: 0.5, height: railHeight)
      }
      .frame(width: 38)
      .padding(.top, 10)

      content()
        .frame(maxWidth: .infinity)
    }
  }

  private var railHeight: CGFloat {
    switch event.kind {
    case .moodChange: return 24
    case .audioPost: return 104
    case .photoPost: return 178
    default: return 136
    }
  }

  private func timeLabel(_ date: Date) -> String {
    let age = Date.now.timeIntervalSince(date)
    if age < 30 * 60 { return "ora" }
    if age < 3600 { return "\(Int(age / 60))m" }
    if age < 24 * 3600 { return "\(Int(age / 3600))h" }
    return "\(Int(age / (24 * 3600)))g"
  }
}

private struct PulseDropCard: View {
  let event: PulseEvent
  var onPersonTap: () -> Void = {}
  var onReact: (ReactionKind) -> Void = { _ in }

  var body: some View {
    switch event.kind {
    case .moodChange:
      systemEvent
    default:
      Button(action: onPersonTap) {
        VStack(alignment: .leading, spacing: 12) {
          header
          content
          actionRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
      }
      .buttonStyle(.plain)
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 11) {
      avatar

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 7) {
          Text(event.isMine ? "tu" : event.person.name.lowercased())
            .font(HaloType.serif(18))
            .foregroundStyle(HaloInk.cream)
          Circle()
            .fill(MoodPalette.auraColor(event.person.mood, l: 0.78))
            .frame(width: 5, height: 5)
          Text(event.person.mood.rawValue)
            .haloEyebrow(HaloInk.creamMute, size: 7.5, tracking: 1.5)
        }
        Text("@\(event.person.handle) · \(event.person.tier.label.lowercased())")
          .font(HaloType.ui(11, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
          .lineLimit(1)
      }

      Spacer(minLength: 10)

      VStack(alignment: .trailing, spacing: 5) {
        Text(timeLabel(event.createdAt))
          .font(HaloType.mono(9, weight: .medium))
          .kerning(0.7)
          .textCase(.uppercase)
          .foregroundStyle(event.isLive ? SwarmHalo.inkSecondary : HaloInk.creamMute)
        audienceBadge
      }
    }
  }

  private var avatar: some View {
    ZStack {
      Circle()
        .fill(event.person.tier.swarmHaloState.ringFill)
        .frame(width: 42, height: 42)
        .overlay(Circle().strokeBorder(event.person.tier.swarmHaloState.stroke, lineWidth: 0.7))
        .shadow(color: event.person.tier.swarmHaloState.glow, radius: 7)
      PortraitView(personId: event.person.id, size: 36, grayscale: true)
        .background(HaloTheme.portraitBacking, in: Circle())
    }
    .frame(width: 46, height: 46)
  }

  private var audienceBadge: some View {
    Text(event.audience.title.lowercased())
      .haloEyebrow(event.audience == .inner ? event.person.tier.swarmHaloState.accent.opacity(0.82) : HaloInk.creamMute, size: 7.4, tracking: 1.5)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(Capsule().fill(HaloInk.creamWhisper))
      .overlay(Capsule().strokeBorder(HaloInk.creamLine, lineWidth: 0.5))
  }

  @ViewBuilder
  private var content: some View {
    switch event.kind {
    case .message(let text):
      noteDrop(text, label: "nota")
    case .vibe(let text):
      noteDrop(text, label: "vibe", accent: true)
    case .photoPost(let caption):
      photoDrop(caption)
    case .textPost(let body):
      longNoteDrop(body)
    case .audioPost(let caption):
      audioDrop(caption)
    case .moodChange:
      EmptyView()
    }
  }

  private func noteDrop(_ text: String, label: String, accent: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text(label)
        .haloEyebrow(accent ? SwarmHalo.bronze : HaloInk.creamMute, size: 7.8, tracking: 1.7)
      Text(text)
        .font(HaloType.serif(19))
        .foregroundStyle(HaloInk.cream)
        .lineSpacing(3)
        .lineLimit(6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.leading, 12)
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 1)
        .fill(accent ? SwarmHalo.bronze.opacity(0.76) : HaloInk.creamLine)
        .frame(width: 2)
    }
  }

  private func photoDrop(_ caption: String) -> some View {
    ZStack(alignment: .bottomLeading) {
      LinearGradient(
        colors: [
          MoodPalette.auraColor(event.person.mood, l: 0.42),
          MoodPalette.auraColor(event.person.mood, l: 0.18),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      Canvas { ctx, size in
        ctx.opacity = 0.10
        var path = Path()
        let step: CGFloat = 7
        var x: CGFloat = -size.height
        while x < size.width {
          path.move(to: CGPoint(x: x, y: size.height))
          path.addLine(to: CGPoint(x: x + size.height, y: 0))
          x += step
        }
        ctx.stroke(path, with: .color(SwarmHalo.ink.opacity(0.50)), lineWidth: 0.5)
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("scatto")
          .haloEyebrow(SwarmHalo.inkSecondary, size: 7.8, tracking: 1.8)
        if !caption.isEmpty {
          Text(caption)
            .font(HaloType.serif(15))
            .foregroundStyle(SwarmHalo.ink)
            .lineLimit(2)
        }
      }
      .padding(14)
    }
    .frame(height: 158)
    .clipShape(RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
        .strokeBorder(HaloInk.creamLine, lineWidth: 0.5)
    )
  }

  private func longNoteDrop(_ body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("nota lunga")
        .haloEyebrow(HaloInk.creamMute, size: 7.8, tracking: 1.7)
      Text(body)
        .font(HaloType.ui(14, weight: .regular))
        .foregroundStyle(HaloInk.cream)
        .lineSpacing(3)
        .lineLimit(6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(13)
    .background(
      RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
        .fill(HaloInk.nightSurface.opacity(0.34))
    )
    .overlay(
      RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
        .strokeBorder(HaloInk.creamLine, lineWidth: 0.5)
    )
  }

  private func audioDrop(_ caption: String) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(MoodPalette.auraColor(event.person.mood, l: 0.70))
        Image(systemName: "play.fill")
          .font(HaloType.system(11, weight: .bold))
          .foregroundStyle(SwarmHalo.background)
          .offset(x: 1)
      }
      .frame(width: 34, height: 34)

      VStack(alignment: .leading, spacing: 7) {
        Text("audio")
          .haloEyebrow(HaloInk.creamMute, size: 7.8, tracking: 1.7)
        HStack(spacing: 2) {
          ForEach(0..<30, id: \.self) { i in
            Capsule()
              .fill(SwarmHalo.ink.opacity(i < 13 ? 0.78 : 0.22))
              .frame(width: 2, height: CGFloat(5 + abs(sin(Double(i) * 1.3)) * 16))
          }
        }
        .frame(height: 24)
      }

      Spacer()
      Text(caption.isEmpty ? "audio" : caption)
        .font(HaloType.mono(9, weight: .medium))
        .kerning(0.4)
        .foregroundStyle(HaloInk.creamMute)
    }
    .padding(13)
    .background(
      RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
        .fill(HaloInk.nightSurface.opacity(0.34))
    )
    .overlay(
      RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
        .strokeBorder(HaloInk.creamLine, lineWidth: 0.5)
    )
  }

  private var actionRow: some View {
    HStack(spacing: 8) {
      if event.person.lastPostId != nil {
        ForEach(ReactionKind.allCases, id: \.self) { kind in
          reactionChip(kind)
        }
      }
      Spacer()
      if event.isLive {
        Text("live")
          .haloEyebrow(SwarmHalo.inkSecondary, size: 7.8, tracking: 1.7)
      }
    }
  }

  private func reactionChip(_ kind: ReactionKind) -> some View {
    let tally = event.person.lastPostReactionTallies.first(where: { $0.kind == kind })

    return Button {
      onReact(kind)
    } label: {
      HStack(spacing: 5) {
        ReactionGlyph(kind: kind, size: 13, color: tally == nil ? HaloInk.creamMute : SwarmHalo.inkSecondary)
        reactionLabel(tally)
      }
      .foregroundStyle(HaloInk.creamLow)
      .padding(.horizontal, 7)
      .padding(.vertical, 5)
      .background(Capsule().fill(HaloInk.creamWhisper))
      .overlay(Capsule().strokeBorder(HaloInk.creamLine, lineWidth: 0.5))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func reactionLabel(_ tally: HaloReactionTally?) -> some View {
    if let tally, tally.count > 0 {
      if event.person.tier == .inner || event.person.tier == .close,
         let labels = tally.actorLabels,
         !labels.isEmpty {
        Text(labels.prefix(2).map { "@\($0)" }.joined(separator: " "))
          .font(HaloType.ui(9, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
          .lineLimit(1)
        if tally.count > 2 {
          Text("+\(tally.count - 2)")
            .font(HaloType.mono(9, weight: .medium))
            .foregroundStyle(HaloInk.creamMute)
        }
      } else {
        Text("\(tally.count)")
          .font(HaloType.mono(9, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
      }
    } else {
      Color.clear.frame(width: 1, height: 9)
    }
  }

  private var systemEvent: some View {
    HStack(spacing: 8) {
      Rectangle()
        .fill(HaloInk.creamLine)
        .frame(height: 0.5)
      Circle()
        .fill(MoodPalette.auraColor(event.person.mood, l: 0.75))
        .frame(width: 6, height: 6)
      Text("\(event.person.name.lowercased()) ha cambiato vibe")
        .haloEyebrow(HaloInk.creamMute, size: 8.5, tracking: 1.8)
      Rectangle()
        .fill(HaloInk.creamLine)
        .frame(height: 0.5)
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
  }

  private var cardBackground: some View {
    Color.clear
      .haloContentGlass(
        in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
        stroke: .clear
      )
      .overlay(
        RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                SwarmHalo.inkWhisper,
                Color.clear,
                SwarmHalo.absoluteBlack.opacity(0.12),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
      )
  }

  private var cardBorder: some View {
    RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous)
      .strokeBorder(event.isLive ? SwarmHalo.strokeActive : HaloInk.creamHair, lineWidth: event.isLive ? 0.8 : 0.5)
  }

  private func timeLabel(_ date: Date) -> String {
    let age = Date.now.timeIntervalSince(date)
    if age < 30 * 60 { return "ora" }
    if age < 3600 { return "\(Int(age / 60))m" }
    if age < 24 * 3600 { return "\(Int(age / 3600))h" }
    return "\(Int(age / (24 * 3600)))g"
  }
}

private struct PulseDropDock: View {
  enum DropType {
    case note
    case vibe
  }

  let scope: PulseScope
  @Binding var text: String
  @Binding var isDraftOpen: Bool
  var onPublish: () -> Void
  var onQuickDrop: (DropType) -> Void

  private var canPublish: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(spacing: 9) {
      if isDraftOpen {
        draftPanel
          .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      HStack(spacing: 8) {
        dockButton("nota", icon: "square.and.pencil", type: .note)
        dockButton("vibe", icon: "sparkle", type: .vibe)
      }
      .padding(10)
      .haloGlass(
        in: Capsule(),
        tint: HaloVisual.Chrome.controlFill,
        interactive: true,
        stroke: HaloInk.creamHair
      )
      .shadow(color: SwarmHalo.absoluteBlack.opacity(0.45), radius: 18, y: 10)
    }
  }

  private var draftPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("nuovo Moment")
          .haloEyebrow(HaloInk.creamMute, size: 8, tracking: 1.8)
        Rectangle()
          .fill(HaloInk.creamLine)
          .frame(height: 0.5)
        Text(scope.title.lowercased())
          .haloEyebrow(scope == .inner ? SwarmHalo.inkSecondary : HaloInk.creamMute, size: 8, tracking: 1.8)
      }

      TextField("una cosa vera, adesso", text: $text, axis: .vertical)
        .textFieldStyle(.plain)
        .font(HaloType.serif(18))
        .foregroundStyle(HaloInk.cream)
        .lineLimit(2...5)
        .padding(.vertical, 4)

      HStack(spacing: 8) {
        Button {
          withAnimation(SwarmHalo.easeSwarm(0.18)) {
            isDraftOpen = false
          }
        } label: {
          Text("chiudi")
            .font(HaloType.mono(9, weight: .medium))
            .kerning(0.7)
            .textCase(.uppercase)
        }
        .foregroundStyle(HaloInk.creamMute)
        .buttonStyle(.plain)

        Spacer()

        Button(action: onPublish) {
          Text("manda")
            .font(HaloType.mono(9, weight: .semibold))
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(canPublish ? SwarmHalo.background : HaloInk.creamMute)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(canPublish ? SwarmHalo.ink : HaloInk.creamWhisper))
            .overlay(Capsule().strokeBorder(HaloInk.creamLine, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!canPublish)
      }
    }
    .padding(14)
    .haloContentGlass(
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      stroke: HaloInk.creamHair
    )
    .shadow(color: SwarmHalo.absoluteBlack.opacity(0.35), radius: 16, y: 8)
  }

  private func dockButton(_ label: String, icon: String, type: DropType) -> some View {
    Button {
      onQuickDrop(type)
    } label: {
      VStack(spacing: 5) {
        Image(systemName: icon)
          .font(HaloType.system(14, weight: .semibold))
        Text(label)
          .font(HaloType.mono(8.5, weight: .medium))
          .kerning(0.6)
          .textCase(.uppercase)
          .lineLimit(1)
          .minimumScaleFactor(0.82)
      }
      .foregroundStyle(HaloInk.creamLow)
      .frame(maxWidth: .infinity)
      .frame(height: 46)
      .background(
        RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous)
          .fill(HaloInk.creamWhisper)
      )
      .overlay(
        RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous)
          .strokeBorder(HaloInk.creamLine, lineWidth: 0.5)
      )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  PulseFeedView()
    .preferredColorScheme(.dark)
}
