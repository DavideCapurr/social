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
  @State private var inviteLink: HaloInvite?
  @State private var isCreatingInvite: Bool = false

  private let maxInner = 5

  var body: some View {
    ZStack {
      DeepSpaceBackground()
      VStack(spacing: 18) {
        eyebrow
        searchField
        inviteLinkRow
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
        SwarmLoadingState(label: "inner sync")
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
      Text("scegli i tuoi 5.")
        .font(HaloType.serif(28, weight: .regular))
        .foregroundStyle(HaloInk.cream)
      Text("massimo 5. li puoi spostare quando vuoi.")
        .font(HaloType.ui(12, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(HaloInk.creamMute)
      TextField("cerca per handle", text: $query)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .foregroundStyle(HaloInk.cream)
        .font(HaloType.ui(14, weight: .regular))
        .onChange(of: query) { _, _ in
          Task { await search() }
        }
    }
    .padding(.horizontal, 14).padding(.vertical, 12)
    .swarmSurface(.control, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous), activation: .connected)
  }

  /// Per i primi utenti la ricerca e vuota: un link invito porta dentro
  /// chi non e ancora su Halo (`InvitesService.openInviteLink`).
  private var inviteLinkRow: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text("non trovi nessuno?")
          .font(HaloType.ui(12, weight: .medium))
          .foregroundStyle(HaloInk.cream)
        Text(inviteLink == nil
          ? "manda un link a chi non e ancora su Halo."
          : "link pronto. scade tra 14 giorni.")
          .font(HaloType.ui(11, weight: .regular))
          .foregroundStyle(HaloInk.creamMute)
      }
      Spacer()
      if let url = inviteLink?.deepLinkURL {
        ShareLink(item: url) {
          Label("condividi", systemImage: "square.and.arrow.up")
            .font(HaloType.ui(12, weight: .semibold))
            .foregroundStyle(HaloInk.cream)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .swarmSurface(.control, in: Capsule(), activation: .connected)
        }
      } else {
        Button {
          Task { await createInviteLink() }
        } label: {
          Text(isCreatingInvite ? "creo..." : "invita con link")
            .font(HaloType.ui(12, weight: .semibold))
            .foregroundStyle(SwarmHalo.background)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(SwarmActivationRole.connected.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isCreatingInvite)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .swarmSurface(.panel, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous), activation: .rest)
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
        } else if results.isEmpty && !query.isEmpty {
          Text("nessun handle che inizia con \u{201C}\(query)\u{201D}.")
            .font(HaloType.serif(13, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
            .padding(.top, 18)
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
              .swarmSurface(.card, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous), activation: isPicked(p) ? .connected : .rest)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.vertical, 4)
    }
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
        Text(picked.isEmpty ? "continua" : "aggiungi al mio Inner (\(picked.count))")
          .font(HaloType.ui(15, weight: .semibold))
          .foregroundStyle(SwarmHalo.background)
          .padding(.horizontal, 18).padding(.vertical, 12)
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
    }
  }

  @MainActor
  private func search() async {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { results = []; return }
    isSearching = true; defer { isSearching = false }
    if let found = try? await ProfilesService.shared.search(handle: q) {
      results = found
    }
  }

  @MainActor
  private func createInviteLink() async {
    guard !isCreatingInvite else { return }
    isCreatingInvite = true; defer { isCreatingInvite = false }
    errorMessage = nil
    do {
      inviteLink = try await InvitesService.shared.openInviteLink()
    } catch {
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a creare il link. Riprova."
      )
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
}
