import SwiftUI
import PhotosUI
import HaloShared

/// Onboarding: scegli handle (univoco) + display name + avatar.
/// Salva il profilo via `ProfilesService.update`. Se l'utente sceglie un avatar,
/// fa upload via `StorageService.uploadAvatar` e salva il path.
struct OnboardingView: View {
  let initialProfile: Profile
  var onDone: (Profile) -> Void = { _ in }

  @State private var handle: String
  @State private var displayName: String
  @State private var photo: PhotosPickerItem?
  @State private var avatarData: Data?
  @State private var isWorking: Bool = false
  @State private var errorMessage: String?

  init(initialProfile: Profile, onDone: @escaping (Profile) -> Void = { _ in }) {
    self.initialProfile = initialProfile
    self.onDone = onDone
    self._handle = State(initialValue: initialProfile.handle.hasPrefix("halo_") ? "" : initialProfile.handle)
    self._displayName = State(initialValue: initialProfile.displayName == "Halo" ? "" : initialProfile.displayName)
  }

  var body: some View {
    ZStack {
      DeepSpaceBackground()
      ScrollView {
        VStack(spacing: HaloVisual.Auth.sectionSpacing) {
          manifesto
          avatarPicker
          handleField
          nameField
          if let err = errorMessage {
            Text(err)
              .font(HaloType.ui(12, weight: .regular))
              .foregroundStyle(SwarmHalo.attention)
          }
          Spacer().frame(height: 12)
          ctaButton
        }
        .padding(.horizontal, HaloVisual.Auth.horizontalPadding)
        .padding(.top, HaloVisual.Auth.topPadding)
        .padding(.bottom, HaloVisual.Auth.bottomPadding)
      }
      if isWorking {
        SwarmLoadingState(label: "salvo profilo")
          .padding(.horizontal, SwarmHalo.s6)
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - subviews

  private var manifesto: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("HALO / IDENTITY")
        .haloEyebrow(SwarmHalo.inkSecondary, size: 9, tracking: 2.2)
      Text("crea il tuo profilo.")
        .font(HaloType.serif(34, weight: .regular))
        .foregroundStyle(SwarmHalo.ink)
      Text("Scegli handle, nome e avatar. Puoi cambiarli dopo.")
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(SwarmHalo.inkSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var avatarPicker: some View {
    PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
      ZStack {
        Circle()
          .fill(MoodPalette.auraColor(.chill, l: 0.55))
          .frame(width: HaloVisual.Auth.avatarSize, height: HaloVisual.Auth.avatarSize)
        if let data = avatarData, let img = UIImage(data: data) {
          Image(uiImage: img).resizable().scaledToFill()
            .frame(width: HaloVisual.Auth.avatarSize, height: HaloVisual.Auth.avatarSize)
            .clipShape(Circle())
        } else {
          PortraitView(personId: handle.isEmpty ? "halo|self" : handle, size: HaloVisual.Auth.avatarPortraitSize)
            .background(HaloTheme.portraitBacking, in: Circle())
        }
        Image(systemName: "camera.fill")
          .font(HaloType.system(12, weight: .bold))
          .foregroundStyle(SwarmHalo.background)
          .frame(width: HaloVisual.Auth.cameraBadgeSize, height: HaloVisual.Auth.cameraBadgeSize)
          .background(SwarmHalo.ink, in: Circle())
          .overlay(Circle().strokeBorder(SwarmHalo.background.opacity(0.4), lineWidth: 2))
          .offset(x: 38, y: 38)
      }
    }
    .frame(maxWidth: .infinity)
    .onChange(of: photo) { _, newItem in
      Task {
        if let data = try? await newItem?.loadTransferable(type: Data.self) {
          avatarData = data
        }
      }
    }
  }

  private var handleField: some View {
    HaloAuthField(label: "handle", hint: "solo lettere, numeri, punto o underscore") {
      HStack(spacing: 4) {
        Text("@").foregroundStyle(HaloInk.creamMute)
        TextField("handle", text: $handle)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .foregroundStyle(HaloInk.cream)
          .onChange(of: handle) { _, v in
            let cleaned = v.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
            handle = String(cleaned.prefix(24))
          }
      }
    }
  }

  private var nameField: some View {
    HaloAuthField(label: "nome visibile", hint: "il nome che vedono le tue persone") {
      TextField("come vuoi essere chiamato", text: $displayName)
        .foregroundStyle(HaloInk.cream)
    }
  }

  private var ctaButton: some View {
    let disabled = !canSubmit
    return Button {
      Task { await save() }
    } label: {
      Text("inizia")
        .font(HaloType.ui(15, weight: .semibold))
        .foregroundStyle(disabled ? HaloInk.creamMute : SwarmHalo.absoluteBlack)
        .frame(maxWidth: .infinity)
        .frame(minHeight: HaloVisual.Auth.controlMinHeight)
        .background(disabled ? SwarmHalo.inkWhisper : SwarmActivationRole.connected.color, in: RoundedRectangle(cornerRadius: HaloVisual.Auth.buttonRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HaloVisual.Auth.buttonRadius, style: .continuous).strokeBorder(disabled ? SwarmHalo.inkLine : SwarmActivationRole.connected.stroke, lineWidth: SwarmStroke.standard))
        .shadow(color: disabled ? .clear : SwarmActivationRole.connected.glow, radius: 12, y: 4)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }

  private var canSubmit: Bool {
    !handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  // MARK: - save

  @MainActor
  private func save() async {
    guard canSubmit else {
      errorMessage = "Compila handle e nome prima di continuare."
      return
    }

    isWorking = true; defer { isWorking = false }
    do {
      let normalizedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
      let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !normalizedHandle.isEmpty, !normalizedDisplayName.isEmpty else {
        errorMessage = "Compila handle e nome prima di continuare."
        return
      }

      if DemoMode.isActive {
        var profile = initialProfile
        profile.handle = normalizedHandle
        profile.displayName = normalizedDisplayName
        onDone(profile)
        return
      }

      let available = try await ProfilesService.shared.isHandleAvailable(normalizedHandle, excluding: initialProfile.id)
      guard available else {
        errorMessage = "Questo handle è già preso."
        return
      }

      var avatarPath: String? = initialProfile.avatarPath
      if let data = avatarData {
        avatarPath = try await StorageService.shared.uploadAvatar(data: data, contentType: "image/jpeg")
      }
      var profile = initialProfile
      profile.handle = normalizedHandle
      profile.displayName = normalizedDisplayName
      profile.avatarPath = avatarPath
      try await ProfilesService.shared.update(profile)
      onDone(profile)
    } catch {
      errorMessage = SupabaseErrorMessage.describe(
        error,
        fallback: "Non riesco a salvare il profilo. Riprova."
      )
    }
  }
}
