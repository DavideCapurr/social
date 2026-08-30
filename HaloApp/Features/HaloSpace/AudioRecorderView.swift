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

  enum Phase { case idle, recording, recorded, playing }

  private let maxDuration: TimeInterval = 60

  var body: some View {
    VStack(spacing: 18) {
      Text(headerText)
        .font(HaloType.eyebrow(11))
        .kerning(2.4)
        .textCase(.uppercase)
        .foregroundStyle(HaloInk.creamMute)

      waveform
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)

      Text(timerText)
        .font(HaloType.mono(28, weight: .medium))
        .foregroundStyle(HaloInk.cream)

      controls
    }
    .padding(.vertical, 22)
    .frame(maxWidth: .infinity)
    .haloContentGlass(in: RoundedRectangle(cornerRadius: HaloVisual.HaloSpace.cardRadius))
    .onDisappear { cleanup() }
  }

  // MARK: - subviews

  private var headerText: String {
    switch phase {
    case .idle: return "premi per registrare · max 60s"
    case .recording: return "in registrazione"
    case .recorded: return "pronto"
    case .playing: return "playback"
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
        circleButton(icon: "mic.fill", color: SwarmHalo.ink, bg: SwarmHalo.ink.opacity(0.12)) { startRecording() }
      case .recording:
        circleButton(icon: "stop.fill", color: SwarmHalo.background, bg: SwarmHalo.attention.opacity(0.85)) { stopRecording() }
      case .recorded:
        Button("ripeti") { reset() }
          .buttonStyle(.plain)
          .font(HaloType.ui(14, weight: .medium))
          .foregroundStyle(HaloInk.creamMute)
        circleButton(icon: "play.fill", color: SwarmHalo.ink, bg: SwarmHalo.ink.opacity(0.18)) { play() }
        Button("conferma") { confirm() }
          .buttonStyle(.plain)
          .font(HaloType.ui(14, weight: .semibold))
          .foregroundStyle(HaloInk.cream)
      case .playing:
        circleButton(icon: "pause.fill", color: SwarmHalo.ink, bg: SwarmHalo.ink.opacity(0.18)) { stopPlayback() }
      }
    }
  }

  private func circleButton(icon: String, color: Color, bg: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(HaloType.system(22, weight: .bold))
        .foregroundStyle(color)
        .frame(width: 64, height: 64)
        .haloGlass(in: Circle(), tint: bg, interactive: true)
    }
    .buttonStyle(.plain)
  }

  // MARK: - record

  private func startRecording() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
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
      recorder?.record(forDuration: maxDuration)
      phase = .recording
      elapsed = 0
      levels = []
      meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
        Task { @MainActor in tickMeter() }
      }
    } catch {
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
  }

  private func confirm() {
    guard let url = fileURL else { return }
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
