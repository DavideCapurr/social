import SwiftUI
import HaloShared

/// Selezione dei primi 1-5 Inner durante onboarding.
/// Ricerca per handle (`ProfilesService.search`) → tap per aggiungere.
/// Per ogni aggiunta, segue (default `.nebula`) e propone tier `.inner`
/// (la controparte conferma più avanti).
struct InitialInnerCircleView: View {
  var onDone: () -> Void = {}
  var onSkip: () -> Void = {}

  @State private var query: String = ""
  @State private var results: [Profile] = []
  @State private var picked: [Profile] = []
  @State private var isSearching: Bool = false
  @State private var isWorking: Bool = false
  @State private var errorMessage: String?

  private let maxInner = 5

  var body: some View {
    ZStack {
      DeepSpaceBackground()
      VStack(spacing: HaloVisual.Auth.sectionSpacing) {
        eyebrow
        searchField
        selectionProgress
        pickedRow
        resultsList
        Spacer(minLength: 0)
        if let errorMessage {
          Text(errorMessage)
            .font(HaloType.ui(12, weight: .regular))
            .foregroundStyle(SwarmHalo.attention)
            .multilineTextAlignment(.center)
        }
        ctaRow
      }
      .padding(.horizontal, 22)
      .padding(.top, 26)
      .padding(.bottom, 26)
      if isWorking {
        SwarmLoadingState(label: "sincronizzo inner")
          .padding(.horizontal, SwarmHalo.s6)
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - subviews

  private var eyebrow: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("HALO / INNER")
        .haloEyebrow(SwarmActivationRole.connected.color, size: 9, tracking: 2.2)
      Text("scegli le prime 5 persone.")
        .font(HaloType.serif(28, weight: .regular))
        .foregroundStyle(HaloInk.cream)
      Text("Saranno il tuo cerchio più vicino. Puoi cambiarle quando vuoi.")
        .font(HaloType.ui(12, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(HaloInk.creamMute)
      TextField("@handle o nome", text: $query)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .foregroundStyle(HaloInk.cream)
        .font(HaloType.ui(14, weight: .regular))
        .onChange(of: query) { _, _ in
          Task { await search() }
        }
    }
    .padding(.horizontal, HaloVisual.Auth.fieldHorizontalPadding)
    .padding(.vertical, HaloVisual.Auth.fieldVerticalPadding)
    .swarmSurface(.control, in: RoundedRectangle(cornerRadius: HaloVisual.Auth.fieldRadius, style: .continuous), activation: .connected)
  }

  private var selectionProgress: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text("\(picked.count)/\(maxInner) scelte")
          .font(HaloType.ui(13, weight: .semibold))
          .foregroundStyle(HaloInk.cream)
        Text(picked.isEmpty ? "Puoi anche continuare senza aggiungere nessuno." : "Tocca una persona scelta per rimuoverla.")
          .font(HaloType.ui(11, weight: .regular))
          .foregroundStyle(HaloInk.creamMute)
      }
      Spacer()
      ForEach(0..<maxInner, id: \.self) { index in
        Circle()
          .fill(index < picked.count ? SwarmActivationRole.connected.color : SwarmHalo.inkWhisper)
          .frame(width: 8, height: 8)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .swarmSurface(.panel, in: RoundedRectangle(cornerRadius: HaloVisual.Auth.panelRadius, style: .continuous), activation: .connected)
  }

  @ViewBuilder
  private var pickedRow: some View {
    if !picked.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(picked, id: \.id) { p in
            Button {
              picked.removeAll { $0.id == p.id }
            } label: {
              HStack(spacing: 6) {
                Circle()
                  .fill(SwarmHalo.surfaceRaised)
                  .frame(width: 18, height: 18)
                  .overlay(
                    PortraitView(personId: p.handle, size: 16)
                      .clipShape(Circle())
                  )
                Text("@\(p.handle)")
                  .font(HaloType.ui(12, weight: .medium))
                  .foregroundStyle(HaloInk.cream)
                Image(systemName: "xmark")
                  .font(HaloType.system(9, weight: .bold))
                  .foregroundStyle(HaloInk.creamMute)
              }
              .padding(.horizontal, 10).padding(.vertical, 6)
              .swarmChip(active: true, activation: .connected)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var resultsList: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        if isSearching {
          ProgressView().tint(SwarmHalo.ink).padding(.top, 18)
        } else if query.isEmpty {
          emptySearchState
        } else if results.isEmpty && !query.isEmpty {
          SwarmEmptyState(
            title: "Nessun risultato.",
            message: "Prova con handle più corti come @gia, @fra o @mura.",
            activation: .rest,
            actionTitle: "prova @gia",
            actionIcon: "magnifyingglass",
            action: { query = "gia" }
          )
        } else {
          ForEach(results, id: \.id) { p in
            Button {
              toggle(p)
            } label: {
              HStack(spacing: 12) {
                Circle()
                  .fill(MoodPalette.auraColor(.chill, l: 0.55))
                  .frame(width: 36, height: 36)
                  .overlay(
                    PortraitView(personId: p.handle, size: 32).clipShape(Circle())
                  )
                VStack(alignment: .leading, spacing: 2) {
                  Text(p.displayName)
                    .font(HaloType.serif(16, weight: .regular))
                    .foregroundStyle(HaloInk.cream)
                  Text("@\(p.handle)")
                    .font(HaloType.ui(11, weight: .regular))
                    .foregroundStyle(HaloInk.creamMute)
                }
                Spacer()
                Image(systemName: isPicked(p) ? "checkmark.circle.fill" : "plus.circle")
                  .font(HaloType.system(18, weight: .regular))
                  .foregroundStyle(isPicked(p)
                    ? SwarmHalo.orbitalBlue
                    : HaloInk.creamMute)
              }
              .padding(.horizontal, 12).padding(.vertical, 10)
              .swarmSurface(.card, in: RoundedRectangle(cornerRadius: HaloVisual.Auth.fieldRadius, style: .continuous), activation: isPicked(p) ? .connected : .rest)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPicked(p) ? "rimuovi @\(p.handle) dall'Inner" : "aggiungi @\(p.handle) all'Inner")
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var emptySearchState: some View {
    VStack(spacing: 14) {
      SwarmEmptyState(
        title: "Cerca una persona.",
        message: "Scrivi un handle o un nome. In demo puoi provare gli esempi qui sotto.",
        activation: .connected
      )
      HStack(spacing: 8) {
        quickSearchButton("@gia")
        quickSearchButton("@fra")
        quickSearchButton("@mura")
      }
    }
  }

  private func quickSearchButton(_ label: String) -> some View {
    Button {
      query = String(label.dropFirst())
    } label: {
      Text(label)
        .font(HaloType.ui(12, weight: .semibold))
        .foregroundStyle(HaloInk.cream)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(SwarmHalo.inkWhisper, in: Capsule())
        .overlay(Capsule().strokeBorder(SwarmHalo.inkLine, lineWidth: SwarmStroke.hairline))
    }
    .buttonStyle(.plain)
  }

  private var ctaRow: some View {
    HStack {
      Button(action: onSkip) {
        Text("salta")
          .font(HaloType.ui(14, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
      }
      .buttonStyle(.plain)
      Spacer()
      Button { Task { await confirm() } } label: {
        Text(picked.isEmpty ? "continua senza Inner" : "aggiungi al mio Inner (\(picked.count))")
          .font(HaloType.ui(15, weight: .semibold))
          .foregroundStyle(SwarmHalo.absoluteBlack)
          .padding(.horizontal, 18)
          .frame(minHeight: HaloVisual.Auth.controlMinHeight)
          .background(SwarmActivationRole.connected.color, in: Capsule())
          .overlay(Capsule().strokeBorder(SwarmActivationRole.connected.stroke, lineWidth: SwarmStroke.standard))
          .shadow(color: SwarmActivationRole.connected.glow, radius: 10, y: 4)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - actions

  private func isPicked(_ p: Profile) -> Bool {
    picked.contains(where: { $0.id == p.id })
  }

  private func toggle(_ p: Profile) {
    errorMessage = nil
    if let i = picked.firstIndex(where: { $0.id == p.id }) {
      picked.remove(at: i)
    } else if picked.count < maxInner {
      picked.append(p)
    } else {
      errorMessage = "Puoi scegliere massimo 5 persone."
    }
  }

  @MainActor
  private func search() async {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { results = []; return }
    isSearching = true; defer { isSearching = false }
    if DemoMode.isActive {
      results = demoSearch(matching: q)
      return
    }
    if let found = try? await ProfilesService.shared.search(handle: q) {
      results = found
    }
  }

  @MainActor
  private func confirm() async {
    guard !picked.isEmpty else {
      onSkip()
      return
    }

    isWorking = true; defer { isWorking = false }
    errorMessage = nil
    if DemoMode.isActive {
      onDone()
      return
    }
    do {
      for p in picked {
        try await FollowsService.shared.addInitialInnerCandidate(p.id)
      }
      onDone()
    } catch {
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco ad aggiungere il tuo Inner. Riprova."
      )
    }
  }

  private func demoSearch(matching query: String) -> [Profile] {
    let needle = query.lowercased()
    return demoProfiles.filter { profile in
      profile.handle.lowercased().hasPrefix(needle) ||
        profile.displayName.lowercased().contains(needle)
    }
  }

  private var demoProfiles: [Profile] {
    (SeedPeople.all + SeedPeople.asteroids).enumerated().map { index, node in
      let suffix = String(1000 + index)
      return Profile(
        id: UUID(uuidString: "00000000-0000-4000-8000-00000000\(suffix)") ?? UUID(),
        handle: node.handle,
        displayName: node.name
      )
    }
  }
}
