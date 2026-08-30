import SwiftUI
import AVFoundation

/// Registratore audio max 60s. Salva in temp directory come m4a (AAC).
/// Visualizza una waveform live durante la registrazione e una statica
/// in playback. Non si occupa della upload; emette `onFinished(url, duration)`
/// quando l'utente conferma.
struct AudioRecorderView: View {
  var onFinished: (URL, TimeInterval) -> Void = { _, _ in }
  var onCancel: () -> Void = {}

  @State private var phase: Phase = .idle
  @State private var levels: [CGFloat] = []
  @State private var elapsed: TimeInterval = 0
  @State private var recorder: AVAudioRecorder?
  @State private var player: AVAudioPlayer?
  @State private var meterTimer: Timer?
  @State private var fileURL: URL?
  @State private var errorMessage: String?

  enum Phase { case idle, recording, recorded, playing }

  private let maxDuration: TimeInterval = 60

  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 5) {
        Text(headerText)
          .font(HaloType.eyebrow(11))
          .kerning(2.4)
          .textCase(.uppercase)
          .foregroundStyle(HaloInk.creamMute)
        statusLine
      }

      waveform
        .frame(height: HaloVisual.AudioRecorder.waveformHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)

      Text(timerText)
        .font(HaloType.mono(28, weight: .medium))
        .foregroundStyle(HaloInk.cream)

      controls
    }
    .padding(.vertical, 22)
    .padding(.horizontal, 14)
    .frame(maxWidth: .infinity)
    .background(
      HaloVisual.AudioRecorder.surfaceFill,
      in: RoundedRectangle(cornerRadius: HaloVisual.AudioRecorder.panelRadius, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: HaloVisual.AudioRecorder.panelRadius, style: .continuous)
        .strokeBorder(HaloVisual.AudioRecorder.stroke, lineWidth: 0.6)
    )
    .onDisappear { cleanup() }
  }

  // MARK: - subviews

  private var headerText: String {
    switch phase {
    case .idle: return "audio · max 60s"
    case .recording: return "in registrazione"
    case .recorded: return "audio pronto"
    case .playing: return "playback"
    }
  }

  private var statusText: String {
    switch phase {
    case .idle: return "tocca il microfono e parla."
    case .recording: return "tocca stop quando hai finito."
    case .recorded: return "riascolta, rifai o conferma."
    case .playing: return "stai ascoltando la registrazione."
    }
  }

  @ViewBuilder
  private var statusLine: some View {
    if let errorMessage {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(HaloType.system(11, weight: .semibold))
        Text(errorMessage)
          .font(HaloType.ui(12, weight: .medium))
          .lineLimit(2)
          .minimumScaleFactor(0.78)
          .fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(SwarmHalo.attention)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
    } else {
      Text(statusText)
        .font(HaloType.ui(12, weight: .regular))
        .foregroundStyle(HaloInk.creamLow)
        .multilineTextAlignment(.center)
    }
  }

  private var timerText: String {
    let total = phase == .playing ? (player?.currentTime ?? 0) : elapsed
    let m = Int(total) / 60
    let s = Int(total) % 60
    return String(format: "%01d:%02d", m, s)
  }

  /// Waveform: capsule colorate. In rec, rolling buffer dei level live.
  /// In playback, statica con i level catturati.
  private var waveform: some View {
    GeometryReader { geo in
      let count = max(levels.count, 24)
      let spacing: CGFloat = 3
      let width = (geo.size.width - CGFloat(count - 1) * spacing) / CGFloat(count)
      HStack(alignment: .center, spacing: spacing) {
        ForEach(0..<count, id: \.self) { i in
          let v = i < levels.count ? levels[i] : 0.05
          Capsule()
            .fill(SwarmHalo.ink.opacity(0.20 + Double(v) * 0.65))
            .frame(width: max(2, width), height: max(4, geo.size.height * v))
        }
      }
      .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
    }
  }

  @ViewBuilder
  private var controls: some View {
    HStack(spacing: 24) {
      switch phase {
      case .idle:
        circleButton(
          icon: "mic.fill",
          accessibilityLabel: "Registra audio",
          color: SwarmHalo.ink,
          bg: SwarmHalo.ink.opacity(0.12)
        ) { startRecording() }
      case .recording:
        circleButton(
          icon: "stop.fill",
          accessibilityLabel: "Ferma registrazione",
          color: SwarmHalo.background,
          bg: SwarmHalo.attention.opacity(0.85)
        ) { stopRecording() }
      case .recorded:
        Button("ripeti") { reset() }
          .buttonStyle(.plain)
          .font(HaloType.ui(14, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
        circleButton(
          icon: "play.fill",
          accessibilityLabel: "Ascolta audio",
          color: SwarmHalo.ink,
          bg: SwarmHalo.ink.opacity(0.18)
        ) { play() }
        Button("conferma") { confirm() }
          .buttonStyle(.plain)
          .font(HaloType.ui(14, weight: .semibold))
          .foregroundStyle(HaloInk.cream)
      case .playing:
        circleButton(
          icon: "pause.fill",
          accessibilityLabel: "Ferma playback",
          color: SwarmHalo.ink,
          bg: SwarmHalo.ink.opacity(0.18)
        ) { stopPlayback() }
      }
    }
  }

  private func circleButton(
    icon: String,
    accessibilityLabel: String,
    color: Color,
    bg: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(HaloType.system(HaloVisual.AudioRecorder.iconSize, weight: .bold))
        .foregroundStyle(color)
        .frame(width: HaloVisual.AudioRecorder.controlSize, height: HaloVisual.AudioRecorder.controlSize)
        .background(HaloVisual.AudioRecorder.controlFill, in: Circle())
        .overlay(Circle().strokeBorder(bg, lineWidth: 1.1))
        .shadow(color: bg.opacity(0.55), radius: 10, y: 4)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: - record

  @MainActor
  private func startRecording() {
    errorMessage = nil
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .denied:
        errorMessage = "Microfono bloccato. Apri Impostazioni."
      case .undetermined:
        AVAudioApplication.requestRecordPermission { granted in
          handlePermissionResponse(granted)
        }
      case .granted:
        startRecordingAfterPermission()
      @unknown default:
        errorMessage = "Non riesco a leggere il permesso del microfono."
      }
    } else {
      startRecordingAfterPermission()
    }
  }

  private func handlePermissionResponse(_ granted: Bool) {
    Task { @MainActor in
      if granted {
        startRecordingAfterPermission()
      } else {
        errorMessage = "Microfono bloccato. Apri Impostazioni."
      }
    }
  }

  @MainActor
  private func startRecordingAfterPermission() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      errorMessage = "Non riesco ad attivare il microfono. Riprova."
      return
    }

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("halo-\(UUID().uuidString).m4a")
    fileURL = url

    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    do {
      recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder?.isMeteringEnabled = true
      guard recorder?.record(forDuration: maxDuration) == true else {
        errorMessage = "La registrazione non è partita. Riprova."
        cleanup()
        return
      }
      phase = .recording
      elapsed = 0
      levels = []
      meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
        Task { @MainActor in tickMeter() }
      }
    } catch {
      errorMessage = "Non riesco a salvare l'audio. Riprova."
      phase = .idle
    }
  }

  @MainActor
  private func tickMeter() {
    guard let rec = recorder, rec.isRecording else {
      stopRecording()
      return
    }
    rec.updateMeters()
    let db = rec.averagePower(forChannel: 0)         // -160…0
    let normalized = max(0, min(1, (db + 60) / 60))   // 0…1
    levels.append(CGFloat(normalized))
    if levels.count > 80 { levels.removeFirst(levels.count - 80) }
    elapsed = rec.currentTime
    if elapsed >= maxDuration { stopRecording() }
  }

  private func stopRecording() {
    recorder?.stop()
    meterTimer?.invalidate()
    meterTimer = nil
    phase = .recorded
  }

  // MARK: - playback

  private func play() {
    guard let url = fileURL else { return }
    errorMessage = nil
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      player = try AVAudioPlayer(contentsOf: url)
      player?.play()
      phase = .playing
      Task { @MainActor in
        while player?.isPlaying == true {
          try? await Task.sleep(nanoseconds: 200_000_000)
        }
        if phase == .playing { phase = .recorded }
      }
    } catch {
      errorMessage = "Non riesco a riprodurre questo audio."
      phase = .recorded
    }
  }

  private func stopPlayback() {
    player?.stop()
    phase = .recorded
  }

  // MARK: - control flow

  private func reset() {
    cleanup()
    phase = .idle
    elapsed = 0
    levels = []
    fileURL = nil
    errorMessage = nil
  }

  private func confirm() {
    guard let url = fileURL, elapsed > 0 else {
      errorMessage = "Registra almeno un secondo di audio."
      return
    }
    onFinished(url, elapsed)
  }

  private func cleanup() {
    meterTimer?.invalidate()
    meterTimer = nil
    recorder?.stop()
    recorder = nil
    player?.stop()
    player = nil
  }
}

#Preview {
  ZStack {
    SwarmHalo.background.ignoresSafeArea()
    AudioRecorderView()
      .padding(20)
  }
  .preferredColorScheme(.dark)
}
