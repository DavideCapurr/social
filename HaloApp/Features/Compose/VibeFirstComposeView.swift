import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import HaloShared

/// Compose flow vibe-first: mood (obbligatorio) → nota (opzionale) → Moment
/// (foto/testo/audio/salta) → tier (default Inner) → CTA "Manda".
/// Anti-cringe: parte sempre col tier più ristretto; il tier selector mostra
/// numeri reali e dà un warning soft quando si allarga.
struct VibeFirstComposeView: View {
  enum Step: Int, CaseIterable { case mood = 0, nota = 1, momento = 2, tier = 3 }
  enum Momento { case foto, testo, audio, salta }

  /// Conteggi delle proprie cerchie (per il tier selector). Vengono passati dall'esterno.
  let tierCounts: [FriendshipTier: Int]

  var onSend: (ComposeResult) -> Void = { _ in }
  var onClose: () -> Void = {}

  /// Output di ritorno della compose.
  enum MediaPayload {
    case data(Data, contentType: String)
    case file(URL, contentType: String)
  }

  struct ComposeResult {
    var mood: Mood
    var note: String
    var momento: Momento
    var tier: FriendshipTier
    var media: MediaPayload?
  }

  @State private var step: Step = .mood
  @State private var mood: Mood = .chill
  @State private var note: String = ""
  @State private var momento: Momento = .salta
  @State private var tier: FriendshipTier = .inner
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var selectedPhotoData: Data?
  @State private var selectedPhotoContentType: String = "image/jpeg"
  @State private var selectedPhotoPreview: UIImage?
  @State private var isLoadingPhoto: Bool = false
  @State private var photoError: String?
  @State private var audioFileURL: URL?
  @State private var audioDuration: TimeInterval?

  init(tierCounts: [FriendshipTier: Int],
       initialMood: Mood = .chill,
       onSend: @escaping (ComposeResult) -> Void = { _ in },
       onClose: @escaping () -> Void = {}) {
    self.tierCounts = tierCounts
    self.onSend = onSend
    self.onClose = onClose
    self._mood = State(initialValue: initialMood)
  }

  var body: some View {
    VStack(spacing: 0) {
      composeTopRail
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)

      // Stage centrata verticalmente: gli step corti (es. mood) non lasciano
      // più un vuoto in fondo, quelli lunghi (foto/audio) scorrono comunque.
      GeometryReader { geo in
        ScrollView {
          HStack(alignment: .top, spacing: 12) {
            stepRail
              .padding(.leading, 18)

            stageCard
              .padding(.trailing, 18)
          }
          .padding(.vertical, 8)
          .frame(minHeight: geo.size.height, alignment: .center)
        }
        .scrollIndicators(.hidden)
      }
      .frame(maxHeight: .infinity)

      footer
        .padding(.horizontal, 22).padding(.bottom, 22).padding(.top, 8)
    }
    .background(haloSheetBackground())
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(.clear)
  }

  // MARK: - progress

  private var composeTopRail: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("COMPOSE / VIBE")
          .haloEyebrow(SwarmHalo.inkSecondary, size: 8.5, tracking: 2.3)
        Text(step.shortTitle)
          .font(HaloType.ui(13, weight: .semibold))
          .foregroundStyle(HaloInk.cream)
      }

      Rectangle()
        .fill(HaloInk.creamLine)
        .frame(height: 0.5)

      Text("\(step.rawValue + 1)/4")
        .font(HaloType.mono(10, weight: .semibold))
        .kerning(1.2)
        .foregroundStyle(HaloInk.creamLow)

      Button(action: onClose) {
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

  private var stepRail: some View {
    VStack(spacing: 8) {
      ForEach(Step.allCases, id: \.self) { item in
        VStack(spacing: 6) {
          Circle()
            .fill(item.rawValue <= step.rawValue ? MoodPalette.auraColor(mood, l: 0.78) : SwarmHalo.strokeRest)
            .frame(width: item == step ? 11 : 7, height: item == step ? 11 : 7)
            .shadow(color: item == step ? MoodPalette.auraRing(mood, alpha: 0.35) : .clear, radius: 6)

          if item != .tier {
            Rectangle()
              .fill(item.rawValue < step.rawValue ? MoodPalette.auraColor(mood, l: 0.52) : HaloInk.creamLine)
              .frame(width: 0.5, height: 34)
          }
        }
        .frame(width: 22)
        .contentShape(Rectangle())
        .onTapGesture {
          guard item.rawValue <= step.rawValue else { return }
          UISelectionFeedbackGenerator().selectionChanged()
          step = item
        }
      }
    }
    .padding(.vertical, 12)
    .haloContentGlass(
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      stroke: HaloInk.creamHair
    )
  }

  private var stageCard: some View {
    VStack(spacing: 18) {
      switch step {
      case .mood:    moodStep
      case .nota:    notaStep
      case .momento: momentoStep
      case .tier:    tierStep
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .haloContentGlass(
      in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous),
      stroke: HaloInk.creamHair,
      lineWidth: 0.6
    )
  }

  private var progressBar: some View {
    HStack(spacing: 6) {
      ForEach(0..<4) { idx in
        Capsule()
          .fill(idx <= step.rawValue
            ? MoodPalette.auraColor(mood, l: 0.78)
            : SwarmHalo.strokeRest)
          .frame(height: 3)
      }
    }
    .animation(SwarmHalo.easeSwarm(0.25), value: step)
  }

  // MARK: - step 1: mood

  private var moodStep: some View {
    VStack(alignment: .leading, spacing: 12) {
      stepHeading(eyebrow: "STEP 1 · MOOD", title: "che colore hai oggi?")
      // Preview hero
      heroPreview
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(Mood.allCases, id: \.self) { m in
            moodChip(m)
          }
        }
        .padding(.horizontal, 2)
      }
    }
  }

  private var heroPreview: some View {
    ZStack {
      TimelineView(.animation(minimumInterval: 1.0 / 24)) { ctx in
        let t = ctx.date.timeIntervalSinceReferenceDate
        let phase = sin((t / 3.2) * .pi * 2)
        Circle()
          .fill(
            RadialGradient(
              colors: [MoodPalette.auraRing(mood, alpha: 0.6), .clear],
              center: .center, startRadius: 0, endRadius: 110
            )
          )
          .frame(width: 220, height: 220)
          .blur(radius: 4)
          .scaleEffect(1.0 + 0.05 * phase)
      }
      Circle()
        .fill(MoodPalette.auraColor(mood, l: 0.78))
        .frame(width: 130, height: 130)
        .shadow(color: MoodPalette.auraRing(mood, alpha: 0.5), radius: 25)
      PortraitView(personId: "self|hero", size: 122)
        .background(HaloTheme.portraitBacking, in: Circle())
    }
    .frame(width: 220, height: 220)
    .frame(maxWidth: .infinity)
  }

  private func moodChip(_ m: Mood) -> some View {
    let on = m == mood
    return Button {
      mood = m
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(MoodPalette.auraColor(m, l: 0.8))
          .frame(width: 7, height: 7)
          .shadow(color: MoodPalette.auraRing(m, alpha: 0.6), radius: 3)
        Text(m.rawValue)
          .font(HaloType.ui(14, weight: on ? .semibold : .medium))
          .foregroundStyle(on ? HaloInk.cream : HaloInk.creamLow)
      }
      .padding(.horizontal, 16).padding(.vertical, 9)
      .haloGlass(in: Capsule(), tint: on ? MoodPalette.auraColor(m, l: 0.55) : nil, interactive: true)
    }
    .buttonStyle(.plain)
  }

  // MARK: - step 2: nota

  private var notaStep: some View {
    VStack(alignment: .leading, spacing: 12) {
      stepHeading(eyebrow: "STEP 2 · NOTA", title: "una riga, se ti va")
      VStack(alignment: .leading, spacing: 6) {
        TextField("una nota breve (opzionale)", text: $note, axis: .vertical)
          .textFieldStyle(.plain)
          .font(HaloType.serif(17, weight: .regular))
          .foregroundStyle(HaloInk.cream)
          .lineLimit(3, reservesSpace: true)
          .onChange(of: note) { _, newValue in
            if newValue.count > 60 { note = String(newValue.prefix(60)) }
          }
        Text("\(note.count)/60")
          .font(HaloType.mono(10, weight: .medium))
          .kerning(1.0)
          .foregroundStyle(HaloInk.creamMute)
      }
      .padding(.horizontal, 14).padding(.vertical, 12)
      .haloContentGlass(in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput))

      Button { note = ""; advance() } label: {
        Text("salta")
          .font(HaloType.ui(14, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - step 3: Moment

  private var momentoStep: some View {
    VStack(alignment: .leading, spacing: 12) {
      stepHeading(eyebrow: "STEP 3 · MOMENT", title: "vuoi aggiungere un Moment?")
      Text("se non aggiungi nulla, condividi solo la presenza.")
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)

      momentoOptions
      if momento == .foto {
        photoPickerPanel
      } else if momento == .audio {
        audioRecorderPanel
      } else if momento == .testo {
        TextField("scrivi qui qualcosa…", text: $note, axis: .vertical)
          .textFieldStyle(.plain)
          .font(HaloType.serif(17, weight: .regular))
          .foregroundStyle(HaloInk.cream)
          .lineLimit(6, reservesSpace: true)
          .padding(.horizontal, 14).padding(.vertical, 12)
          .haloContentGlass(in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput))
      }
    }
  }

  @ViewBuilder
  private var momentoOptions: some View {
    let items: [(Momento, String, String)] = [
      (.foto,  "Foto",  "photo"),
      (.testo, "Testo", "text.alignleft"),
      (.audio, "Audio", "mic.fill"),
      (.salta, "Salta", "forward.end")
    ]
    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
      ForEach(items, id: \.0) { (kind, label, icon) in
        let on = momento == kind
        Button {
          selectMomento(kind)
          UISelectionFeedbackGenerator().selectionChanged()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: icon)
              .font(HaloType.system(16, weight: .regular))
              .foregroundStyle(on ? SwarmHalo.ink : SwarmHalo.inkMuted)
              .frame(width: 22)
            Text(label)
              .font(HaloType.ui(15, weight: on ? .semibold : .medium))
              .foregroundStyle(on ? HaloInk.cream : HaloInk.creamLow)
            Spacer()
          }
          .padding(.horizontal, 14).padding(.vertical, 14)
          .haloGlass(in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput), tint: on ? MoodPalette.auraColor(mood, l: 0.55) : nil, interactive: true)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var photoPickerPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
        HStack(spacing: 10) {
          Image(systemName: "photo.on.rectangle")
            .font(HaloType.system(16, weight: .semibold))
            .foregroundStyle(SwarmHalo.ink)
            .frame(width: 30, height: 30)
            .background(MoodPalette.auraColor(mood, l: 0.58).opacity(0.24), in: Circle())

          VStack(alignment: .leading, spacing: 2) {
            Text(selectedPhotoData == nil ? "scegli una foto" : "foto pronta")
              .font(HaloType.ui(14, weight: .semibold))
              .foregroundStyle(HaloInk.cream)
            Text(isLoadingPhoto ? "carico..." : selectedPhotoData == nil ? "dal rullino" : selectedPhotoContentType)
              .font(HaloType.ui(11, weight: .regular))
              .foregroundStyle(HaloInk.creamMute)
          }

          Spacer()

          Text(selectedPhotoData == nil ? "scegli" : "cambia")
            .font(HaloType.ui(12, weight: .semibold))
            .foregroundStyle(HaloInk.creamLow)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .haloContentGlass(in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput))
      }
      .buttonStyle(.plain)
      .onChange(of: selectedPhotoItem) { _, newItem in
        Task {
          await loadSelectedPhoto(newItem)
        }
      }

      if let selectedPhotoPreview {
        Image(uiImage: selectedPhotoPreview)
          .resizable()
          .scaledToFill()
          .frame(height: 180)
          .frame(maxWidth: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous)
              .strokeBorder(HaloInk.creamHair, lineWidth: 0.6)
          )
      }

      if let photoError {
        Text(photoError)
          .font(HaloType.ui(12, weight: .medium))
          .foregroundStyle(SwarmHalo.attention)
      }
    }
  }

  @ViewBuilder
  private var audioRecorderPanel: some View {
    if let audioFileURL {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(MoodPalette.auraColor(mood, l: 0.70))
          Image(systemName: "waveform")
            .font(HaloType.system(14, weight: .bold))
            .foregroundStyle(SwarmHalo.background)
        }
        .frame(width: 38, height: 38)

        VStack(alignment: .leading, spacing: 2) {
          Text("audio pronto")
            .font(HaloType.ui(14, weight: .semibold))
            .foregroundStyle(HaloInk.cream)
          Text(audioDurationText(audioDuration) + " · " + audioFileURL.lastPathComponent)
            .font(HaloType.ui(11, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
            .lineLimit(1)
        }

        Spacer()

        Button("rifai") {
          clearAudioSelection()
        }
        .buttonStyle(.plain)
        .font(HaloType.ui(13, weight: .semibold))
        .foregroundStyle(HaloInk.creamLow)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .haloContentGlass(in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput))
    } else {
      AudioRecorderView { url, duration in
        audioFileURL = url
        audioDuration = duration
      }
    }
  }

  // MARK: - step 4: tier — anti-cringe, mostra conteggi reali

  private var tierStep: some View {
    VStack(alignment: .leading, spacing: 12) {
      stepHeading(eyebrow: "STEP 4 · CON CHI", title: "condividi con…")
      Text("Halo parte da Inner. Allargare è una scelta.")
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)

      VStack(spacing: 8) {
        // `.asteroid` non è un'audience: non si pubblica verso i depriorizzati.
        ForEach(FriendshipTier.allCases.reversed().filter { $0 != .asteroid }, id: \.self) { t in
          tierRow(t)
        }
      }

      if let warning = wideningWarning {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.circle")
            .foregroundStyle(SwarmHalo.attention)
          Text(warning)
            .font(HaloType.ui(12, weight: .regular))
            .foregroundStyle(HaloInk.creamLow)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .haloGlass(in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput), tint: SwarmHalo.attention.opacity(0.22))
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .animation(SwarmHalo.easeSwarm(0.20), value: tier)
  }

  private func tierRow(_ t: FriendshipTier) -> some View {
    let on = t == tier
    let n = tierCounts[t] ?? 0
    let state = t.swarmHaloState
    return Button {
      tier = t
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      HStack(spacing: 12) {
        Circle()
          .fill(on ? state.accent : state.stroke)
          .frame(width: 9, height: 9)
          .shadow(color: on ? state.glow : .clear, radius: 4)
        VStack(alignment: .leading, spacing: 2) {
          Text(t.label)
            .font(HaloType.ui(15, weight: on ? .semibold : .medium))
            .foregroundStyle(on ? HaloInk.cream : HaloInk.creamLow)
          Text(audienceLabel(for: t, count: n))
            .font(HaloType.ui(11, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
        }
        Spacer()
        Text("\(n)")
          .font(HaloType.mono(13, weight: .medium))
          .kerning(1.0)
          .foregroundStyle(on ? HaloInk.cream : HaloInk.creamMute)
      }
      .padding(.horizontal, 14).padding(.vertical, 12)
      .haloGlass(in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput), tint: on ? state.accent.opacity(0.18) : nil, interactive: true)
    }
    .buttonStyle(.plain)
  }

  private func audienceLabel(for t: FriendshipTier, count: Int) -> String {
    switch t {
    case .inner:  return "i tuoi \(count) di Inner"
    case .close:  return "Inner + i tuoi \(count) di Close"
    case .orbit:  return "Inner + Close + i tuoi \(count) in Orbita"
    case .nebula: return "Inner + Close + Orbita + \(count) in Nebula"
    case .asteroid: return ""
    }
  }

  /// Warning soft quando si sale di tier (più persone vedranno).
  private var wideningWarning: String? {
    guard tier != .inner else { return nil }
    let inner = tierCounts[.inner] ?? 0
    let now = tierCounts[tier] ?? 0
    let extras = max(now - inner, 0)
    guard extras > 0 else { return nil }
    return "anche \(extras) persone in più lo vedranno"
  }

  // MARK: - footer (back / next / send)

  private var footer: some View {
    HStack {
      if step != .mood {
        Button { back() } label: {
          Text("indietro")
            .font(HaloType.ui(14, weight: .medium))
            .foregroundStyle(HaloInk.creamMute)
        }
        .buttonStyle(.plain)
      }
      Spacer()
      Button {
        guard footerEnabled else { return }
        if step == .tier { send() } else { advance() }
      } label: {
        Text(footerTitle)
          .font(HaloType.ui(15, weight: .semibold))
          .foregroundStyle(MoodPalette.onAccent(mood, l: 0.78))
          .padding(.horizontal, 22).padding(.vertical, 12)
          .background(
            LinearGradient(
              colors: [MoodPalette.auraColor(mood, l: 0.78), MoodPalette.auraColor(mood, l: 0.55)],
              startPoint: .top, endPoint: .bottom
            ),
            in: Capsule()
          )
          .shadow(color: MoodPalette.auraRing(mood, alpha: 0.4), radius: 10, y: 4)
          .haloGlass(in: Capsule(), tint: MoodPalette.auraColor(mood, l: 0.55), interactive: true)
      }
      .buttonStyle(.plain)
      .disabled(!footerEnabled)
      .opacity(footerEnabled ? 1 : 0.46)
    }
  }

  // MARK: - helpers

  private func stepHeading(eyebrow: String, title: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(eyebrow)
        .font(HaloType.eyebrow(11))
        .kerning(2.4)
        .textCase(.uppercase)
        .foregroundStyle(HaloInk.creamMute)
      Text(title)
        .font(HaloType.serif(28, weight: .regular))
        .foregroundStyle(HaloInk.cream)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func advance() {
    guard step != .momento || selectedMomentIsReady else { return }
    let next = min(step.rawValue + 1, Step.tier.rawValue)
    step = Step(rawValue: next) ?? step
  }

  private func back() {
    let prev = max(step.rawValue - 1, Step.mood.rawValue)
    step = Step(rawValue: prev) ?? step
  }

  private func send() {
    guard selectedMomentIsReady else { return }
    onSend(.init(mood: mood, note: note, momento: momento, tier: tier, media: mediaPayload))
  }

  private var footerEnabled: Bool {
    if step == .tier { return selectedMomentIsReady }
    if step == .momento { return selectedMomentIsReady }
    return true
  }

  private var footerTitle: String {
    if step == .tier { return "manda" }
    if step == .momento, isLoadingPhoto { return "carico..." }
    return "avanti"
  }

  private var selectedMomentIsReady: Bool {
    switch momento {
    case .foto:
      return selectedPhotoData != nil
    case .audio:
      return audioFileURL != nil
    case .testo, .salta:
      return true
    }
  }

  private var mediaPayload: MediaPayload? {
    switch momento {
    case .foto:
      guard let selectedPhotoData else { return nil }
      return .data(selectedPhotoData, contentType: selectedPhotoContentType)
    case .audio:
      guard let audioFileURL else { return nil }
      return .file(audioFileURL, contentType: "audio/m4a")
    case .testo, .salta:
      return nil
    }
  }

  private func selectMomento(_ kind: Momento) {
    guard momento != kind else { return }
    momento = kind
    if kind != .foto { clearPhotoSelection() }
    if kind != .audio { clearAudioSelection() }
  }

  @MainActor
  private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
    photoError = nil
    guard let item else {
      clearPhotoSelection()
      return
    }

    isLoadingPhoto = true
    defer { isLoadingPhoto = false }

    do {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        selectedPhotoData = nil
        selectedPhotoPreview = nil
        photoError = "Foto non disponibile."
        return
      }

      selectedPhotoData = data
      selectedPhotoContentType = item.supportedContentTypes
        .first(where: { $0.conforms(to: .image) })?
        .preferredMIMEType ?? "image/jpeg"
      selectedPhotoPreview = UIImage(data: data)
    } catch {
      selectedPhotoData = nil
      selectedPhotoPreview = nil
      photoError = "Non riesco a leggere questa foto."
    }
  }

  private func clearPhotoSelection() {
    selectedPhotoItem = nil
    selectedPhotoData = nil
    selectedPhotoContentType = "image/jpeg"
    selectedPhotoPreview = nil
    isLoadingPhoto = false
    photoError = nil
  }

  private func clearAudioSelection() {
    audioFileURL = nil
    audioDuration = nil
  }

  private func audioDurationText(_ duration: TimeInterval?) -> String {
    let total = max(0, Int(duration ?? 0))
    return String(format: "%01d:%02d", total / 60, total % 60)
  }
}

private extension VibeFirstComposeView.Step {
  var shortTitle: String {
    switch self {
    case .mood: return "mood"
    case .nota: return "nota"
    case .momento: return "Moment"
    case .tier: return "con chi"
    }
  }
}

#Preview {
  VibeFirstComposeView(
    tierCounts: [.inner: 4, .close: 12, .orbit: 28, .nebula: 84]
  )
}
