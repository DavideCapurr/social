import SwiftUI
import HaloShared

/// Profilo per-persona: header (portrait grande + display + handle + tier + vibe attiva) +
/// lista post non scaduti tramite `PostsService.posts(forUser:)`.
/// Swipe orizzontale per navigare tra persone dello stesso tier (passate come `peers`).
/// Stato empty con mood se non ha post attivi.
struct HaloSpaceView: View {
  let initialPerson: HaloPersonNode
  /// Persone dello stesso tier per il navigation swipe orizzontale.
  let peers: [HaloPersonNode]
  var onClose: () -> Void = {}

  @State private var index: Int
  @State private var inviteTarget: HaloPersonNode?
  @State private var reportTarget: HaloPersonNode?

  init(person: HaloPersonNode, peers: [HaloPersonNode], onClose: @escaping () -> Void = {}) {
    self.initialPerson = person
    self.peers = peers.isEmpty ? [person] : peers
    self.onClose = onClose
    let i = (peers.isEmpty ? [person] : peers).firstIndex { $0.id == person.id } ?? 0
    self._index = State(initialValue: i)
  }

  private var current: HaloPersonNode { peers[index] }

  var body: some View {
    ZStack {
      DeepSpaceBackground()
      VStack(spacing: 0) {
        topRow
        TabView(selection: $index) {
          ForEach(Array(peers.enumerated()), id: \.element.id) { (i, p) in
            HaloSpacePage(person: p, onInvite: { inviteTarget = p })
              .tag(i)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(SwarmHalo.easeSwarm(0.25), value: index)
      }
    }
    .preferredColorScheme(.dark)
    .sheet(item: $inviteTarget) { person in
      InnerInviteSheet(person: person)
    }
    .sheet(item: $reportTarget) { person in
      ReportUserSheet(person: person)
    }
  }

  // MARK: - top row (close + paginator dots)

  private var topRow: some View {
    HStack {
      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(HaloType.system(14, weight: .semibold))
          .foregroundStyle(SwarmHalo.inkSecondary)
          .frame(width: HaloVisual.HaloSpace.topButtonSize, height: HaloVisual.HaloSpace.topButtonSize)
          .background(SwarmHalo.inkWhisper, in: Circle())
      }
      .buttonStyle(.plain)
      Spacer()
      VStack(spacing: 5) {
        Text("HALO / SPACE")
          .haloEyebrow(current.tier.swarmHaloState.accent, size: 8, tracking: 2.2)
        if peers.count > 1 {
          HStack(spacing: 4) {
            ForEach(0..<peers.count, id: \.self) { i in
              Circle()
                .fill(i == index ? SwarmHalo.ink.opacity(0.85) : SwarmHalo.ink.opacity(0.20))
                .frame(width: 5, height: 5)
            }
          }
        }
      }
      Spacer()
      HStack(spacing: 8) {
        Button {
          inviteTarget = current
        } label: {
          Image(systemName: "person.badge.plus")
            .font(HaloType.system(13, weight: .semibold))
            .foregroundStyle(SwarmActivationRole.connected.color)
            .frame(width: HaloVisual.HaloSpace.topButtonSize, height: HaloVisual.HaloSpace.topButtonSize)
            .background(SwarmActivationRole.connected.color.opacity(0.12), in: Circle())
            .overlay(Circle().strokeBorder(SwarmActivationRole.connected.stroke, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invita \(current.name) nel tuo Inner")

        Button {
          reportTarget = current
        } label: {
          Image(systemName: "exclamationmark.triangle")
            .font(HaloType.system(13, weight: .semibold))
            .foregroundStyle(SwarmHalo.attention)
            .frame(width: HaloVisual.HaloSpace.topButtonSize, height: HaloVisual.HaloSpace.topButtonSize)
            .background(SwarmHalo.attention.opacity(0.12), in: Circle())
            .overlay(Circle().strokeBorder(SwarmHalo.attention.opacity(0.32), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Segnala \(current.name)")
      }
    }
    .padding(.horizontal, HaloVisual.HaloSpace.horizontalPadding).padding(.vertical, 12)
  }
}

// MARK: - single page (header + post list)

private struct HaloSpacePage: View {
  let person: HaloPersonNode
  var onInvite: () -> Void = {}
  @State private var posts: [HaloPost] = []
  @State private var isLoading: Bool = true
  @State private var lastError: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header
        spaceLedger
        if isLoading {
          SwarmLoadingState(label: "carico HaloSpace")
        } else if let lastError {
          errorState(lastError)
        } else if posts.isEmpty {
          emptyState
        } else {
          streamHeader
          ForEach(posts, id: \.id) { post in
            PostCardView(
              post: post,
              viewerTier: person.tier,
              fallbackMood: person.mood
            )
          }
        }
      }
      .padding(.horizontal, HaloVisual.HaloSpace.pageHorizontalPadding)
      .padding(.bottom, 40)
    }
    .task(id: person.id) {
      await load()
    }
  }

  // MARK: - header

  private var header: some View {
    VStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [MoodPalette.auraRing(person.mood, alpha: 0.55), .clear],
              center: .center, startRadius: 0, endRadius: 70
            )
          )
          .frame(width: HaloVisual.HaloSpace.heroAuraSize, height: HaloVisual.HaloSpace.heroAuraSize)
        Circle()
          .fill(person.tier.swarmHaloState.ringFill)
          .frame(width: HaloVisual.HaloSpace.heroRingSize, height: HaloVisual.HaloSpace.heroRingSize)
          .overlay(Circle().strokeBorder(person.tier.swarmHaloState.stroke, lineWidth: 1))
          .shadow(color: person.tier.swarmHaloState.glow, radius: 12)
        PortraitView(personId: person.id, size: HaloVisual.HaloSpace.heroPortraitSize, grayscale: true)
          .background(HaloTheme.portraitBacking, in: Circle())
      }
      .frame(width: HaloVisual.HaloSpace.heroAuraSize, height: HaloVisual.HaloSpace.heroAuraSize)

      VStack(spacing: 7) {
        Text(person.name.lowercased())
          .font(HaloType.serif(40, weight: .regular))
          .foregroundStyle(HaloInk.cream)
          .lineLimit(1)
          .minimumScaleFactor(0.70)
        HStack(spacing: 8) {
          Text("@\(person.handle)")
            .font(HaloType.ui(13, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
          tierBadge
        }
        if person.hasActiveVibe {
          HStack(spacing: 6) {
            Circle()
              .fill(MoodPalette.auraColor(person.mood, l: 0.85))
              .frame(width: 7, height: 7)
              .shadow(color: MoodPalette.auraRing(person.mood, alpha: 0.55), radius: 3)
            Text(person.mood.rawValue)
              .font(HaloType.ui(12, weight: .medium))
              .foregroundStyle(HaloInk.creamLow)
            if !person.note.isEmpty {
              Text("\u{201C}\(person.note)\u{201D}")
                .font(HaloType.serif(13, weight: .regular))
                .foregroundStyle(HaloInk.creamLow)
                .lineLimit(1)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(Capsule().fill(SwarmHalo.inkWhisper))
          .overlay(Capsule().strokeBorder(HaloInk.creamLine, lineWidth: 0.5))
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 10)
    .padding(.bottom, 4)
  }

  private var tierBadge: some View {
    Text(person.tier.label)
      .font(HaloType.eyebrow(9))
      .kerning(1.8)
      .textCase(.uppercase)
      .foregroundStyle(person.tier.swarmHaloState.accent)
      .padding(.horizontal, 7)
      .padding(.vertical, 2.5)
      .haloGlass(in: Capsule(), tint: person.tier.swarmHaloState.accent.opacity(0.18))
  }

  private var spaceLedger: some View {
    HStack(spacing: 0) {
      ledgerCell("tier", person.tier.label)
      ledgerDivider
      ledgerCell("vibe", person.hasActiveVibe ? person.mood.rawValue : "rest")
      ledgerDivider
      ledgerCell("Moment", isLoading ? "--" : String(format: "%02d", posts.count))
    }
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.panelRadius, style: .continuous)
        .fill(SwarmHalo.inkWhisper)
    )
    .overlay(
      RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.panelRadius, style: .continuous)
        .strokeBorder(HaloInk.creamHair, lineWidth: 0.6)
    )
  }

  private func ledgerCell(_ label: String, _ value: String) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(HaloType.mono(13, weight: .semibold))
        .kerning(0.8)
        .foregroundStyle(label == "tier" ? person.tier.swarmHaloState.accent : HaloInk.cream)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(label)
        .haloEyebrow(HaloInk.creamMute, size: 7.4, tracking: 1.7)
    }
    .frame(maxWidth: .infinity)
  }

  private var ledgerDivider: some View {
    Rectangle()
      .fill(HaloInk.creamLine)
      .frame(width: 0.5, height: 26)
  }

  private var streamHeader: some View {
    HStack(spacing: 10) {
      Text("Moment")
        .haloEyebrow(HaloInk.creamMute, size: 8.5, tracking: 2.0)
      Rectangle().fill(HaloInk.creamLine).frame(height: 0.5)
      Text("72H")
        .font(HaloType.mono(8.5, weight: .medium))
        .kerning(1.2)
        .foregroundStyle(HaloInk.creamMute)
    }
    .padding(.top, 2)
  }

  // MARK: - empty state

  private var emptyState: some View {
    SwarmEmptyState(
      title: "ancora silenzio.",
      message: "\(person.name.lowercased()) non ha Moment attivi nelle ultime 72h. Puoi essere tu a farti sentire.",
      activation: .connected,
      actionTitle: "invitalo più vicino",
      actionIcon: "person.badge.plus",
      action: onInvite
    )
  }

  // MARK: - load

  @MainActor
  private func load() async {
    isLoading = true
    lastError = nil
    defer { isLoading = false }

    if DemoMode.isActive {
      posts = demoPosts(for: person)
      return
    }

    guard let userUUID = UUID(uuidString: person.id) else {
      posts = []
      return
    }
    do {
      posts = try await PostsService.shared.posts(forUser: userUUID)
    } catch {
      posts = []
      lastError = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a caricare questo HaloSpace."
      )
    }
  }

  private func errorState(_ message: String) -> some View {
    SwarmEmptyState(
      title: "non arriva il segnale.",
      message: message,
      activation: .attention
    )
  }

  private func demoPosts(for person: HaloPersonNode) -> [HaloPost] {
    guard let createdAt = person.lastPostAt else { return [] }
    let caption = person.lastPostCaption ?? person.note
    return [
      HaloPost(
        id: stableDemoUUID(person.id, salt: "post"),
        userId: stableDemoUUID(person.id, salt: "user"),
        kind: person.lastPostKind ?? .text,
        mediaPath: person.lastPostMediaPath,
        caption: caption.isEmpty ? nil : caption,
        mood: person.mood,
        minTier: person.tier,
        createdAt: createdAt,
        expiresAt: person.lastPostExpiresAt
      )
    ]
  }

  private func stableDemoUUID(_ value: String, salt: String) -> UUID {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in "\(salt)|\(value)".utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 1_099_511_628_211
    }
    let suffix = String(format: "%012llx", hash & 0x0000_FFFF_FFFF_FFFF)
    return UUID(uuidString: "00000000-0000-4000-8000-\(suffix)") ?? UUID()
  }
}

struct ReportUserSheet: View {
  @Environment(\.dismiss) private var dismiss

  let person: HaloPersonNode

  @State private var reason: ReportReason = .harassment
  @State private var details: String = ""
  @State private var blockAfterSubmit: Bool = true
  @State private var isSubmitting: Bool = false
  @State private var didSubmit: Bool = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 0) {
      topRail
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          if didSubmit {
            SwarmEmptyState(
              title: "segnale ricevuto.",
              message: blockAfterSubmit
                ? "\(person.name) non sarà più nella tua orbita."
                : "il report è stato inviato a Halo.",
              activation: .connected
            )
          } else {
            reasonSection
            detailsSection
            blockSection
            if let errorMessage {
              Text(errorMessage)
                .font(HaloType.ui(12, weight: .regular))
                .foregroundStyle(SwarmHalo.attention)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .swarmSurface(
                  .panel,
                  in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.fieldRadius, style: .continuous),
                  activation: .attention
                )
            }
          }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
      }
      .scrollIndicators(.hidden)

      footer
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
    .background(haloSheetBackground())
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(.clear)
  }

  private var topRail: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("SAFETY / REPORT")
          .haloEyebrow(SwarmHalo.attention, size: 8.5, tracking: 2.3)
        Text(person.name.lowercased())
          .font(HaloType.serif(24, weight: .regular))
          .foregroundStyle(HaloInk.cream)
      }
      Spacer()
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(HaloType.system(12, weight: .semibold))
          .foregroundStyle(HaloInk.creamLow)
          .frame(width: 30, height: 30)
          .background(Circle().fill(SwarmHalo.inkWhisper))
          .overlay(Circle().strokeBorder(HaloInk.creamLine, lineWidth: 0.5))
      }
      .buttonStyle(.plain)
    }
  }

  private var reasonSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader("motivo")
      LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
        ForEach(ReportReason.allCases) { item in
          Button {
            reason = item
            HapticEngine.selection()
          } label: {
            HStack(spacing: 8) {
              Circle()
                .fill(item == reason ? SwarmHalo.attention : SwarmHalo.strokeRest)
                .frame(width: 7, height: 7)
              Text(item.label)
                .font(HaloType.ui(13, weight: item == reason ? .semibold : .medium))
                .foregroundStyle(item == reason ? HaloInk.cream : HaloInk.creamLow)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .swarmSurface(
              .control,
              in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.fieldRadius, style: .continuous),
              activation: item == reason ? .attention : .rest
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var detailsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("dettagli")
      TextField("aggiungi contesto per la review", text: $details, axis: .vertical)
        .textFieldStyle(.plain)
        .font(HaloType.ui(14, weight: .regular))
        .foregroundStyle(HaloInk.cream)
        .lineLimit(4, reservesSpace: true)
        .onChange(of: details) { _, newValue in
          if newValue.count > 500 { details = String(newValue.prefix(500)) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .haloContentGlass(in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.fieldRadius))
      Text("\(details.count)/500")
        .font(HaloType.mono(10, weight: .medium))
        .foregroundStyle(HaloInk.creamMute)
    }
  }

  private var blockSection: some View {
    Toggle(isOn: $blockAfterSubmit) {
      VStack(alignment: .leading, spacing: 3) {
        Text("blocca e rimuovi")
          .font(HaloType.ui(14, weight: .semibold))
          .foregroundStyle(HaloInk.cream)
        Text("non comparirà più nella tua orbita.")
          .font(HaloType.ui(12, weight: .regular))
          .foregroundStyle(HaloInk.creamMute)
      }
    }
    .toggleStyle(.switch)
    .tint(SwarmHalo.attention)
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .swarmSurface(
      .panel,
      in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.fieldRadius, style: .continuous),
      activation: blockAfterSubmit ? .attention : .rest
    )
  }

  private var footer: some View {
    HStack {
      if didSubmit {
        Spacer()
        Button("chiudi") { dismiss() }
          .font(HaloType.ui(15, weight: .semibold))
          .buttonStyle(.plain)
          .foregroundStyle(HaloInk.cream)
      } else {
        Button("annulla") { dismiss() }
          .font(HaloType.ui(14, weight: .medium))
          .buttonStyle(.plain)
          .foregroundStyle(HaloInk.creamMute)
        Spacer()
        Button {
          Task { await submit() }
        } label: {
          Text(isSubmitting ? "invio..." : "invia")
            .font(HaloType.ui(15, weight: .semibold))
            .foregroundStyle(HaloInk.cream)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .swarmSurface(
              .control,
              in: Capsule(),
              activation: .attention
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
      }
    }
  }

  private func sectionHeader(_ text: String) -> some View {
    HStack(spacing: 8) {
      Text(text)
        .haloEyebrow(HaloInk.creamMute, size: 8.5, tracking: 2.0)
      Rectangle()
        .fill(HaloInk.creamLine)
        .frame(height: 0.5)
    }
  }

  @MainActor
  private func submit() async {
    guard !isSubmitting else { return }

    if DemoMode.isActive {
      isSubmitting = true
      errorMessage = nil
      defer { isSubmitting = false }
      didSubmit = true
      return
    }

    guard let userId = UUID(uuidString: person.id) else {
      errorMessage = "Questo profilo non può essere segnalato."
      return
    }

    isSubmitting = true
    errorMessage = nil
    defer { isSubmitting = false }

    do {
      _ = try await ReportsService.shared.submit(
        reportedUserId: userId,
        reason: reason,
        details: details
      )
      if blockAfterSubmit {
        try await ReportsService.shared.block(userId)
      }
      didSubmit = true
    } catch {
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a inviare il report. Riprova."
      )
    }
  }
}
