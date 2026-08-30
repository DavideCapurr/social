import SwiftUI
import HaloShared

/// Profile surface for the current user. It keeps Plus, Memory and safety
/// surfaces visible as real SWARM command objects even while backend work is
/// staged for later phases.
struct ProfileView: View {
  @Environment(AppState.self) private var state

  let person: HaloPersonNode
  var tierCounts: [FriendshipTier: Int] = [:]
  var onVibeTap: () -> Void = {}
  var onComposeTap: () -> Void = {}

  @State private var showPlus: Bool = false
  @State private var showDiscovery: Bool = false
  @State private var showBocconiVerify: Bool = false
  @State private var showEventRings: Bool = false
  @State private var showClubRings: Bool = false
  @State private var showMemory: Bool = false
  @State private var showSafetyReport: Bool = false
  @State private var showPrivacy: Bool = false
  @State private var memoryCount: Int = 0

  init(
    person: HaloPersonNode,
    tierCounts: [FriendshipTier: Int] = [:],
    onVibeTap: @escaping () -> Void = {},
    onComposeTap: @escaping () -> Void = {}
  ) {
    self.person = person
    self.tierCounts = tierCounts
    self.onVibeTap = onVibeTap
    self.onComposeTap = onComposeTap
  }

  init(userId: UUID) {
    self.person = HaloPersonNode(
      id: userId.uuidString,
      handle: "halo",
      name: "Halo",
      tier: .inner,
      mood: .chill,
      note: "presenza, non performance",
      hasNew: false
    )
  }

  var body: some View {
    ZStack {
      DeepSpaceBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: SwarmHalo.s4) {
          rail
          heroNode
          haloLedger
          commandPanel
          memoryPanel
          safetyPanel
        }
        .padding(.horizontal, SwarmHalo.s4)
        .padding(.top, SwarmHalo.s3)
        .padding(.bottom, 112)
      }
      .scrollIndicators(.hidden)
    }
    .sheet(isPresented: $showPlus) { PlusUpsellView() }
    .sheet(isPresented: $showDiscovery) { DiscoveryView { showDiscovery = false } }
    .sheet(isPresented: $showBocconiVerify) { BocconiVerifyView() }
    .sheet(isPresented: $showEventRings) { EventRingView() }
    .sheet(isPresented: $showClubRings) { ClubRingView() }
    .sheet(isPresented: $showMemory) {
      MemoryArchiveView(hasPlusHint: state.currentProfile?.hasPlus ?? false) {
        showMemory = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          showPlus = true
        }
      }
    }
    .sheet(isPresented: $showSafetyReport) {
      ProfileReportSheet()
    }
    .sheet(isPresented: $showPrivacy) {
      ProfilePrivacySheet()
    }
    .task {
      await loadMemoryCount()
    }
    .onChange(of: state.currentProfile?.hasPlus ?? false) { _, _ in
      Task { await loadMemoryCount() }
    }
  }

  private var rail: some View {
    SwarmOperationalRail(title: "HALO / PROFILE", context: "@\(person.handle)") {
      SwarmCommandButton(label: "scopri", icon: "sparkle.magnifyingglass", activation: .operational) {
        showDiscovery = true
      }
    }
  }

  private var heroNode: some View {
    VStack(spacing: SwarmHalo.s4) {
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [MoodPalette.auraRing(person.mood, alpha: 0.42), .clear],
              center: .center,
              startRadius: 0,
              endRadius: 120
            )
          )
          .frame(width: 220, height: 220)
        Circle()
          .strokeBorder(SwarmActivationRole.connected.stroke, lineWidth: SwarmStroke.node)
          .frame(width: 150, height: 150)
          .shadow(color: SwarmActivationRole.connected.glow, radius: 16)
        PortraitView(personId: person.id, size: 132, grayscale: true)
          .background(HaloTheme.portraitBacking, in: Circle())
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: SwarmHalo.s2) {
        Text(person.name.lowercased())
          .font(HaloType.serif(48, weight: .regular))
          .foregroundStyle(SwarmHalo.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        HStack(spacing: SwarmHalo.s2) {
          statusDot
          Text(person.mood.rawValue)
            .haloEyebrow(SwarmHalo.inkSecondary, size: 9, tracking: 2.1)
          Text("·")
            .foregroundStyle(SwarmHalo.inkMuted)
          Text("il tuo halo")
            .haloEyebrow(SwarmHalo.inkMuted, size: 9, tracking: 2.1)
          if state.currentProfile?.hasPlus == true {
            Image(systemName: "sparkles")
              .font(HaloType.system(9, weight: .semibold))
              .foregroundStyle(SwarmActivationRole.attention.color)
              .accessibilityLabel("Halo Plus")
          }
        }
      }
    }
    .padding(.vertical, SwarmHalo.s4)
  }

  private var statusDot: some View {
    Circle()
      .fill(MoodPalette.auraColor(person.mood, l: 0.80))
      .frame(width: 7, height: 7)
      .shadow(color: MoodPalette.auraRing(person.mood, alpha: 0.55), radius: 4)
  }

  private var haloLedger: some View {
    HStack(spacing: 0) {
      metric("inner", count(.inner), .connected)
      divider
      metric("close", count(.close), .operational)
      divider
      metric("orbita", count(.orbit), .rest)
      divider
      metric("live", person.hasActiveVibe ? "01" : "00", .attention, active: person.hasActiveVibe)
    }
    .padding(.vertical, SwarmHalo.s3)
    .swarmSurface(.rail, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous))
  }

  private func metric(_ label: String, _ value: String, _ role: SwarmActivationRole, active: Bool = true) -> some View {
    SwarmMetricTile(label: label, value: value, activation: role, active: active)
      .frame(maxWidth: .infinity)
  }

  private func count(_ tier: FriendshipTier) -> String {
    String(format: "%02d", tierCounts[tier] ?? 0)
  }

  private func twoDigits(_ value: Int) -> String {
    String(format: "%02d", value)
  }

  private var divider: some View {
    Rectangle()
      .fill(SwarmHalo.inkLine)
      .frame(width: SwarmStroke.hairline, height: 28)
  }

  private var commandPanel: some View {
    VStack(alignment: .leading, spacing: SwarmHalo.s3) {
      sectionHeader("command")
      profileCommand("manda una vibe", "waveform.path.ecg", role: .connected, action: onVibeTap)
      profileCommand("aggiungi un Moment", "plus", role: .connected, action: onComposeTap)
      profileCommand("verifica Bocconi", "checkmark.seal", role: .connected) {
        showBocconiVerify = true
      }
      profileCommand("Event Ring", "qrcode.viewfinder", role: .connected) {
        showEventRings = true
      }
      profileCommand("Club e corsi", "person.3.sequence", role: .operational) {
        showClubRings = true
      }
      profileCommand("scopri account pubblici", "scope", role: .operational) {
        showDiscovery = true
      }
    }
    .padding(SwarmHalo.s4)
    .swarmPanel()
  }

  @ViewBuilder
  private var memoryPanel: some View {
    let hasPlus = state.currentProfile?.hasPlus ?? false
    VStack(alignment: .leading, spacing: SwarmHalo.s3) {
      sectionHeader("memory")
      Text(hasPlus ? "i frammenti del semestre restano privati finché non li riapri." : "i frammenti scaduti restano privati. Halo Plus li riapre senza metrica pubblica.")
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(SwarmHalo.inkSecondary)
      HStack {
        SwarmMetricTile(label: "frammenti", value: twoDigits(memoryCount), activation: hasPlus ? .attention : .rest, active: memoryCount > 0 && hasPlus)
        Spacer()
        SwarmCommandButton(label: "Memory", icon: "archivebox", activation: .attention) {
          showMemory = true
        }
        SwarmCommandButton(label: "Halo Plus", icon: "sparkles", activation: .attention) {
          showPlus = true
        }
      }
    }
    .padding(SwarmHalo.s4)
    .swarmPanel()
  }

  @MainActor
  private func loadMemoryCount() async {
    do {
      memoryCount = try await PostsService.shared.memoryCount()
    } catch {
      memoryCount = 0
    }
  }

  private var safetyPanel: some View {
    VStack(alignment: .leading, spacing: SwarmHalo.s3) {
      sectionHeader("safety")
      Text("blocca, segnala e sposta distanza senza esporre il tier.")
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(SwarmHalo.inkSecondary)
      HStack(spacing: SwarmHalo.s2) {
        SwarmCommandButton(label: "report", icon: "exclamationmark.triangle", activation: .attention) {
          showSafetyReport = true
        }
        .accessibilityLabel("Apri report safety")
        SwarmCommandButton(label: "privacy", icon: "lock", activation: .rest) {
          showPrivacy = true
        }
        .accessibilityLabel("Apri privacy")
      }
    }
    .padding(SwarmHalo.s4)
    .swarmPanel()
  }

  private func sectionHeader(_ text: String) -> some View {
    HStack(spacing: SwarmHalo.s2) {
      Text(text)
        .haloEyebrow(SwarmHalo.inkMuted, size: 8.5, tracking: 2.0)
      Rectangle()
        .fill(SwarmHalo.inkLine)
        .frame(height: SwarmStroke.hairline)
    }
  }

  private func profileCommand(
    _ title: String,
    _ icon: String,
    role: SwarmActivationRole,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: SwarmHalo.s3) {
        Image(systemName: icon)
          .font(HaloType.system(14, weight: .semibold))
          .foregroundStyle(role.color)
          .swarmIconFrame(active: true, activation: role)
        Text(title)
          .font(HaloType.ui(14, weight: .medium))
          .foregroundStyle(SwarmHalo.ink)
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(HaloType.system(11, weight: .semibold))
          .foregroundStyle(SwarmHalo.inkMuted)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct ProfileReportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var state

  @State private var query: String = ""
  @State private var results: [Profile] = []
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?
  @State private var reportTarget: HaloPersonNode?

  var body: some View {
    VStack(spacing: 0) {
      topRail
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          hero
          searchField
          content
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
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
    .task(id: query) {
      await search()
    }
    .sheet(item: $reportTarget) { person in
      ReportUserSheet(person: person)
    }
  }

  private var topRail: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("SAFETY / REPORT")
          .haloEyebrow(SwarmActivationRole.attention.color, size: 8.5, tracking: 2.3)
        Text("trova un profilo")
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

  private var hero: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("segnala senza esporre il tier.")
        .font(HaloType.serif(28, weight: .regular))
        .foregroundStyle(HaloInk.cream)
      Text("scegli un profilo e usa lo stesso report sicuro di HaloSpace.")
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)
    }
    .padding(14)
    .swarmSurface(
      .panel,
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      activation: .attention
    )
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(HaloInk.creamMute)
      TextField("cerca @handle o nome", text: $query)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .foregroundStyle(HaloInk.cream)
        .font(HaloType.ui(14, weight: .regular))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .swarmSurface(
      .control,
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous)
    )
  }

  @ViewBuilder
  private var content: some View {
    if isLoading {
      SwarmLoadingState(label: "cerco profili")
    } else if let errorMessage {
      errorText(errorMessage)
    } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      SwarmEmptyState(
        title: "cerca un handle.",
        message: DemoMode.isActive ? "prova @gia, @fra o @mura." : "il report si apre solo su un profilo diverso dal tuo.",
        activation: .rest,
        actionTitle: DemoMode.isActive ? "prova @gia" : nil,
        actionIcon: "magnifyingglass"
      ) {
        query = "gia"
        Task { await search() }
      }
    } else if results.isEmpty {
      SwarmEmptyState(
        title: "nessun profilo.",
        message: DemoMode.isActive ? "nei dati demo puoi cercare per nome o handle, ad esempio @fra o Giacomo." : "controlla handle o nome e riprova.",
        activation: .rest,
        actionTitle: DemoMode.isActive ? "cerca @fra" : nil,
        actionIcon: "magnifyingglass"
      ) {
        query = "fra"
        Task { await search() }
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        sectionHeader("risultati")
        ForEach(results) { profile in
          resultRow(profile)
        }
      }
    }
  }

  private func resultRow(_ profile: Profile) -> some View {
    Button {
      reportTarget = HaloPersonNode(safetyProfile: profile)
    } label: {
      HStack(spacing: 12) {
        Circle()
          .fill(MoodPalette.auraColor(.chill, l: 0.55))
          .frame(width: 40, height: 40)
          .overlay(PortraitView(personId: profile.handle, size: 36).clipShape(Circle()))
        VStack(alignment: .leading, spacing: 2) {
          Text(profile.displayName)
            .font(HaloType.serif(16, weight: .regular))
            .foregroundStyle(HaloInk.cream)
            .lineLimit(1)
          Text("@\(profile.handle)")
            .font(HaloType.ui(11, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
        }
        Spacer()
        Image(systemName: "exclamationmark.triangle")
          .font(HaloType.system(12, weight: .semibold))
          .foregroundStyle(SwarmActivationRole.attention.color)
          .frame(width: 30, height: 30)
          .background(SwarmActivationRole.attention.fill, in: Circle())
          .overlay(Circle().strokeBorder(SwarmActivationRole.attention.stroke, lineWidth: 0.6))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .swarmSurface(
        .card,
        in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
        activation: .attention
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Segnala \(profile.displayName)")
  }

  private var footer: some View {
    HStack {
      Button("chiudi") { dismiss() }
        .font(HaloType.ui(14, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(HaloInk.creamMute)
      Spacer()
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

  private func errorText(_ message: String) -> some View {
    Text(message)
      .font(HaloType.ui(12, weight: .regular))
      .foregroundStyle(SwarmHalo.attention)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .swarmSurface(
        .panel,
        in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous),
        activation: .attention
      )
  }

  @MainActor
  private func search() async {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    results = []
    errorMessage = nil
    guard !q.isEmpty else { return }

    if DemoMode.isActive {
      results = Self.demoProfiles(matching: q)
      return
    }

    isLoading = true
    defer { isLoading = false }

    try? await Task.sleep(nanoseconds: 250_000_000)
    guard !Task.isCancelled else { return }

    do {
      let currentUserId = state.currentProfile?.id
      results = try await ProfilesService.shared.search(handle: q)
        .filter { $0.id != currentUserId }
    } catch {
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a cercare profili. Riprova."
      )
    }
  }

  private static func demoProfiles(matching rawQuery: String) -> [Profile] {
    let q = rawQuery
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
      .lowercased()

    guard !q.isEmpty else { return [] }

    let people = SeedPeople.all + SeedPeople.demoted + SeedPeople.asteroids
    return people.enumerated().compactMap { index, person -> Profile? in
      let handle = person.handle.lowercased()
      let name = person.name.lowercased()
      guard handle.contains(q) || name.contains(q) else { return nil }
      return Profile(
        id: demoProfileId(index: index),
        handle: person.handle,
        displayName: person.name,
        bio: person.note.isEmpty ? nil : person.note,
        isPublic: !person.isMutual
      )
    }
    .prefix(12)
    .map { $0 }
  }

  private static func demoProfileId(index: Int) -> UUID {
    let suffix = String(format: "%012d", index + 1)
    return UUID(uuidString: "00000000-0000-4000-8000-\(suffix)") ?? UUID()
  }
}

private struct ProfilePrivacySheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var state

  @State private var isPublic: Bool = false
  @State private var blockedProfiles: [Profile] = []
  @State private var blockedFallbackIds: [UUID] = []
  @State private var isLoading: Bool = true
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 0) {
      topRail
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          visibilitySection
          blockedSection
          if let errorMessage {
            errorText(errorMessage)
          }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
      }
      .scrollIndicators(.hidden)

      footer
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
    .background(haloSheetBackground())
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(.clear)
    .task { await load() }
  }

  private var topRail: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("SAFETY / PRIVACY")
          .haloEyebrow(SwarmActivationRole.rest.color, size: 8.5, tracking: 2.3)
        Text("controlli profilo")
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

  private var visibilitySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("visibilita")
      Toggle(isOn: $isPublic) {
        VStack(alignment: .leading, spacing: 3) {
          Text("account pubblico in Discovery")
            .font(HaloType.ui(14, weight: .semibold))
            .foregroundStyle(HaloInk.cream)
          Text("handle e nome possono apparire nella ricerca pubblica.")
            .font(HaloType.ui(12, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
        }
      }
      .toggleStyle(.switch)
      .tint(SwarmActivationRole.connected.color)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .swarmSurface(
        .panel,
        in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous),
        activation: isPublic ? .connected : .rest
      )

      Text("i Moment restano filtrati dai tier scelti quando pubblichi.")
        .font(HaloType.ui(12, weight: .regular))
        .foregroundStyle(HaloInk.creamMute)
    }
    .padding(14)
    .swarmSurface(
      .panel,
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      activation: .rest
    )
  }

  @ViewBuilder
  private var blockedSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("blocchi")
      if isLoading {
        SwarmLoadingState(label: "leggo blocchi")
      } else if blockedProfiles.isEmpty && blockedFallbackIds.isEmpty {
        SwarmEmptyState(
          title: "nessun blocco.",
          message: "i profili bloccati spariscono da orbita e feed.",
          activation: .rest
        )
      } else {
        ForEach(blockedProfiles) { profile in
          blockedRow(profile)
        }
        ForEach(blockedFallbackIds, id: \.self) { id in
          blockedFallbackRow(id)
        }
      }
    }
    .padding(14)
    .swarmSurface(
      .panel,
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      activation: .rest
    )
  }

  private var footer: some View {
    HStack {
      Button("chiudi") { dismiss() }
        .font(HaloType.ui(14, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(HaloInk.creamMute)
      Spacer()
      Button {
        Task { await saveVisibility() }
      } label: {
        Text(isSaving ? "salvo..." : "salva")
          .font(HaloType.ui(15, weight: .semibold))
          .foregroundStyle(HaloInk.cream)
          .padding(.horizontal, 22)
          .padding(.vertical, 12)
          .swarmSurface(
            .control,
            in: Capsule(),
            activation: .connected
          )
      }
      .buttonStyle(.plain)
      .disabled(isSaving)
    }
  }

  private func blockedRow(_ profile: Profile) -> some View {
    HStack(spacing: 12) {
      Circle()
        .fill(MoodPalette.auraColor(.lost, l: 0.50))
        .frame(width: 38, height: 38)
        .overlay(PortraitView(personId: profile.handle, size: 34).clipShape(Circle()))
      VStack(alignment: .leading, spacing: 2) {
        Text(profile.displayName)
          .font(HaloType.serif(15, weight: .regular))
          .foregroundStyle(HaloInk.cream)
          .lineLimit(1)
        Text("@\(profile.handle)")
          .font(HaloType.ui(11, weight: .regular))
          .foregroundStyle(HaloInk.creamMute)
      }
      Spacer()
      unblockButton(profile.id)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .swarmSurface(
      .card,
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      activation: .rest
    )
  }

  private func blockedFallbackRow(_ id: UUID) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "person.crop.circle.badge.xmark")
        .font(HaloType.system(17, weight: .semibold))
        .foregroundStyle(HaloInk.creamMute)
        .frame(width: 38, height: 38)
        .background(SwarmHalo.inkWhisper, in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text("profilo bloccato")
          .font(HaloType.serif(15, weight: .regular))
          .foregroundStyle(HaloInk.cream)
        Text(id.uuidString.lowercased())
          .font(HaloType.mono(9, weight: .regular))
          .foregroundStyle(HaloInk.creamMute)
          .lineLimit(1)
      }
      Spacer()
      unblockButton(id)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .swarmSurface(
      .card,
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      activation: .rest
    )
  }

  private func unblockButton(_ id: UUID) -> some View {
    Button {
      Task { await unblock(id) }
    } label: {
      Text("sblocca")
        .font(HaloType.ui(12, weight: .semibold))
        .foregroundStyle(HaloInk.cream)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .swarmSurface(
          .control,
          in: Capsule(),
          activation: .rest
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Sblocca profilo")
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

  private func errorText(_ message: String) -> some View {
    Text(message)
      .font(HaloType.ui(12, weight: .regular))
      .foregroundStyle(SwarmHalo.attention)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .swarmSurface(
        .panel,
        in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous),
        activation: .attention
      )
  }

  @MainActor
  private func load() async {
    isLoading = true
    errorMessage = nil
    isPublic = state.currentProfile?.isPublic ?? false
    defer { isLoading = false }

    do {
      let ids = try await ReportsService.shared.blockedIds()
      var profiles: [Profile] = []
      var fallbackIds: [UUID] = []
      for id in ids.sorted(by: { $0.uuidString < $1.uuidString }) {
        do {
          profiles.append(try await ProfilesService.shared.profile(id: id))
        } catch {
          fallbackIds.append(id)
        }
      }
      blockedProfiles = profiles
      blockedFallbackIds = fallbackIds
    } catch {
      blockedProfiles = []
      blockedFallbackIds = []
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a leggere i blocchi."
      )
    }
  }

  @MainActor
  private func saveVisibility() async {
    guard !isSaving else { return }
    guard var profile = state.currentProfile else {
      errorMessage = "Sessione non valida. Esci e rientra."
      return
    }

    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    do {
      profile.isPublic = isPublic
      try await ProfilesService.shared.update(profile)
      state.currentProfile = profile
    } catch {
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a salvare la privacy."
      )
    }
  }

  @MainActor
  private func unblock(_ id: UUID) async {
    errorMessage = nil
    do {
      try await ReportsService.shared.unblock(id)
      blockedProfiles.removeAll { $0.id == id }
      blockedFallbackIds.removeAll { $0 == id }
    } catch {
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a sbloccare questo profilo."
      )
    }
  }
}

extension HaloPersonNode {
  init(safetyProfile profile: Profile) {
    self.init(
      id: profile.id.uuidString,
      handle: profile.handle,
      name: profile.displayName,
      tier: .nebula,
      mood: .chill,
      note: "",
      hasNew: false,
      hasActiveVibe: false,
      isMutual: false
    )
  }
}

#Preview {
  ProfileView(
    person: SeedPeople.me,
    tierCounts: [.inner: 5, .close: 12, .orbit: 28, .nebula: 84]
  )
}
