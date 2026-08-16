import SwiftUI
import HaloShared

/// "Stato" — il tuo halo, in un colpo d'occhio.
///
/// Snapshot mood-clustered del proprio halo: headline grande derivata dal mood
/// dominante, ticker live, griglia 2-col di cluster mood con portrait stacked,
/// footer dei silenziosi e sheet di dettaglio per ciascun cluster.
///
/// Compagna di Pulse: Pulse = feed temporale, Stato = mappa di stati.
struct StatoView: View {
  let people: [HaloPersonNode]
  let onTapPerson: (HaloPersonNode) -> Void

  @State private var selectedCluster: MoodCluster? = nil

  private var mutuals: [HaloPersonNode] {
    people.filter { $0.isMutual && $0.tier != .asteroid }
  }

  private var active: [HaloPersonNode] {
    mutuals.filter { person in
      guard person.hasActiveVibe else { return false }
      guard let last = person.lastPostAt else { return false }
      return Date.now.timeIntervalSince(last) < 72 * 3600
    }
  }

  private var silent: [HaloPersonNode] {
    mutuals.filter { person in
      guard person.hasActiveVibe else { return true }
      guard let last = person.lastPostAt else { return true }
      return Date.now.timeIntervalSince(last) >= 72 * 3600
    }
  }

  private var peopleByMood: [Mood: [HaloPersonNode]] {
    var map: [Mood: [HaloPersonNode]] = [:]
    for person in active {
      map[person.mood, default: []].append(person)
    }
    for key in map.keys {
      map[key]?.sort { lhs, rhs in
        StatoView.minutesSince(lhs.lastPostAt) < StatoView.minutesSince(rhs.lastPostAt)
      }
    }
    return map
  }

  private var clusters: [MoodCluster] {
    MoodCluster.order
      .compactMap { mood -> MoodCluster? in
        guard let list = peopleByMood[mood], !list.isEmpty else { return nil }
        return MoodCluster(mood: mood, people: list)
      }
      .sorted { $0.people.count > $1.people.count }
  }

  private var dominantMood: Mood? {
    clusters.first?.mood
  }

  var body: some View {
    ZStack {
      HaloVisual.Palette.warmBlack.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        StatoHeadline(dominantMood: dominantMood)
        StatoTicker(active: active.count, silent: silent.count)

        ScrollView(.vertical, showsIndicators: false) {
          VStack(alignment: .leading, spacing: 0) {
            StatoGrid(
              clusters: clusters,
              onTapCluster: { cluster in selectedCluster = cluster }
            )
            .padding(.top, 20)

            StatoSilenziosi(people: silent, onTapPerson: onTapPerson)
              .padding(.top, 24)

            // Clearance per la tab bar fluttuante: l'ultima card della griglia
            // mood resta interamente leggibile sopra il dock.
            Color.clear.frame(height: 148)
          }
        }
      }
    }
    .preferredColorScheme(.dark)
    .sheet(item: $selectedCluster) { cluster in
      StatoDetailSheet(
        cluster: cluster,
        onTapPerson: { person in
          selectedCluster = nil
          onTapPerson(person)
        },
        onClose: { selectedCluster = nil }
      )
    }
  }

  fileprivate static func minutesSince(_ date: Date?) -> Double {
    guard let date else { return .infinity }
    return Date.now.timeIntervalSince(date) / 60
  }
}

// MARK: - Cluster model

struct MoodCluster: Identifiable, Hashable {
  let mood: Mood
  let people: [HaloPersonNode]

  var id: String { mood.rawValue }

  /// Visual ordering — mirrors v3 `MM_MOOD_ORDER`.
  static let order: [Mood] = [.warm, .electric, .focused, .wild, .chill, .soft, .blue, .lost]

  var headline: String {
    switch mood {
    case .warm:     return "è caldo."
    case .electric: return "è elettrico."
    case .focused:  return "è concentrato."
    case .wild:     return "è indomabile."
    case .chill:    return "è calmo."
    case .soft:     return "è morbido."
    case .blue:     return "è malinconico."
    case .lost:     return "è sospeso."
    }
  }

  var label: String {
    switch mood {
    case .warm:     return "caldo"
    case .electric: return "elettrico"
    case .focused:  return "concentrato"
    case .wild:     return "indomabile"
    case .chill:    return "calmo"
    case .soft:     return "morbido"
    case .blue:     return "malinconico"
    case .lost:     return "sospeso"
    }
  }
}

// MARK: - Time formatter

private enum StatoTime {
  static func ago(from date: Date?) -> String {
    guard let date else { return "" }
    let minutes = Date.now.timeIntervalSince(date) / 60
    if minutes < 1 { return "adesso" }
    if minutes < 60 { return "\(Int(minutes.rounded())) min" }
    let hours = Int(minutes / 60)
    if hours < 24 { return "\(hours)h" }
    return "\(hours / 24)g"
  }

  static func now() -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "it_IT")
    f.dateFormat = "HH:mm"
    return f.string(from: .now)
  }
}

// MARK: - Headline

private struct StatoHeadline: View {
  let dominantMood: Mood?

  private var verb: String {
    guard let dominantMood else { return "è silenzioso." }
    return MoodCluster(mood: dominantMood, people: []).headline
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("il tuo halo")
        .font(HaloType.serif(17, weight: .regular))
        .foregroundStyle(HaloVisual.Palette.creamLow)
        .kerning(-0.085)

      Text(verb)
        .font(HaloType.serif(54, weight: .regular))
        .foregroundStyle(HaloVisual.Palette.cream)
        .kerning(-1.35)
        .lineSpacing(0)
    }
    .padding(.horizontal, 22)
    .padding(.top, 8)
  }
}

// MARK: - Ticker

private struct StatoTicker: View {
  let active: Int
  let silent: Int

  var body: some View {
    HStack(spacing: 10) {
      TimelineView(.animation(minimumInterval: 1.0 / 18, paused: false)) { ctx in
        let phase = (sin(ctx.date.timeIntervalSinceReferenceDate * .pi / 1.2 - .pi / 2) + 1) / 2

        Circle()
          .fill(HaloVisual.Palette.bronze)
          .frame(width: 6, height: 6)
          .shadow(color: HaloVisual.Palette.bronze, radius: 6)
          .opacity(0.9 - 0.5 * phase)
      }
      .frame(width: 6, height: 6)

      Text("\(String(format: "%02d", active)) vibrano")
        .font(HaloType.mono(10, weight: .medium))
        .kerning(0.6)
        .foregroundStyle(HaloVisual.Palette.cream)

      Text("· \(String(format: "%02d", silent)) silenziosi")
        .font(HaloType.mono(10, weight: .regular))
        .kerning(0.6)
        .foregroundStyle(HaloVisual.Palette.creamMute)

      Rectangle()
        .fill(HaloVisual.Palette.creamLine)
        .frame(height: 0.5)
        .frame(maxWidth: .infinity)

      Text(StatoTime.now())
        .font(HaloType.mono(10, weight: .regular))
        .kerning(1.0)
        .foregroundStyle(HaloVisual.Palette.creamMute)
    }
    .padding(.horizontal, 22)
    .padding(.top, 16)
  }
}

// MARK: - Grid

private struct StatoGrid: View {
  let clusters: [MoodCluster]
  let onTapCluster: (MoodCluster) -> Void

  private let columns: [GridItem] = [
    GridItem(.flexible(), spacing: 10),
    GridItem(.flexible(), spacing: 10),
  ]

  var body: some View {
    if clusters.isEmpty {
      VStack(spacing: 10) {
        Text("nessuno vibra.")
          .font(HaloType.serif(24, weight: .regular))
          .foregroundStyle(HaloVisual.Palette.creamMute)

        Text("il tuo halo è in silenzio")
          .haloEyebrow(HaloVisual.Palette.creamMute, size: 9, tracking: 2.6)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 40)
    } else {
      LazyVGrid(columns: columns, spacing: 10) {
        ForEach(clusters) { cluster in
          Button {
            onTapCluster(cluster)
          } label: {
            StatoCard(cluster: cluster)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(cluster.label), \(cluster.people.count) persone")
          .accessibilityHint("Apre il dettaglio del gruppo")
        }
      }
      .padding(.horizontal, 22)
    }
  }
}

// MARK: - Cluster card

private struct StatoCard: View {
  let cluster: MoodCluster

  private var moodColor: Color { MoodPalette.auraColor(cluster.mood) }

  private var minHeight: CGFloat {
    let count = cluster.people.count
    if count >= 4 { return 184 }
    if count >= 2 { return 168 }
    return 148
  }

  private var portraitSize: CGFloat {
    let count = cluster.people.count
    if count <= 1 { return 40 }
    if count <= 3 { return 34 }
    return 30
  }

  private var hint: HaloPersonNode? {
    cluster.people.first(where: { !$0.note.isEmpty })
  }

  private var recentAgo: String {
    let latest = cluster.people.map { StatoView.minutesSince($0.lastPostAt) }.min() ?? .infinity
    guard latest.isFinite,
          let dateMin = cluster.people.compactMap(\.lastPostAt).max() else { return "" }
    let ago = StatoTime.ago(from: dateMin)
    return ago == "adesso" ? ago : "\(ago) fa"
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    let visiblePortraits = Array(cluster.people.prefix(5).enumerated())
    let extraCount = max(cluster.people.count - 5, 0)

    return VStack(alignment: .leading, spacing: 0) {
      // header: label, freshness and open affordance
      VStack(alignment: .leading, spacing: 6) {
        Text(cluster.label)
          .font(HaloType.serif(22, weight: .regular))
          .foregroundStyle(HaloVisual.Palette.cream)
          .kerning(-0.11)
          .lineLimit(1)
          .minimumScaleFactor(0.78)
          .layoutPriority(1)

        HStack(alignment: .center, spacing: 8) {
          Text(recentAgo.isEmpty ? " " : recentAgo)
            .font(HaloType.mono(9, weight: .regular))
            .kerning(0.54)
            .foregroundStyle(HaloVisual.Palette.creamMute)
            .lineLimit(1)

          Spacer(minLength: 4)

          countBadge
        }
      }

      // stacked portraits
      ZStack(alignment: .topLeading) {
        ForEach(visiblePortraits, id: \.element.id) { index, person in
          ClusterPortrait(person: person, size: portraitSize, moodColor: moodColor)
            .offset(x: CGFloat(index) * portraitSize * 0.55)
            .zIndex(Double(5 - index))
        }

        if extraCount > 0 {
          Text("+\(extraCount)")
            .font(HaloType.mono(10, weight: .regular))
            .foregroundStyle(HaloVisual.Palette.creamLow)
            .offset(x: CGFloat(visiblePortraits.count) * portraitSize * 0.55 + 6,
                    y: portraitSize / 2 - 7)
        }
      }
      .frame(height: portraitSize, alignment: .topLeading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 12)

      Spacer(minLength: 0)

      if let hint, !hint.note.isEmpty {
        Text("“\(hint.note)”")
          .font(HaloType.serif(13, weight: .regular))
          .foregroundStyle(HaloVisual.Palette.creamLow)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .padding(.top, 8)
      } else {
        Color.clear.frame(height: 4)
      }
    }
    .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    .haloGlass(
      in: shape,
      tint: moodColor.opacity(0.22),
      stroke: moodColor.opacity(0.42)
    )
    .contentShape(shape)
  }

  private var countBadge: some View {
    HStack(spacing: 6) {
      Text(String(format: "%02d", cluster.people.count))
        .font(HaloType.mono(11, weight: .medium))
        .kerning(0.44)
      Image(systemName: "chevron.right")
        .font(HaloType.system(10, weight: .semibold))
    }
    .foregroundStyle(HaloVisual.Palette.cream)
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(HaloVisual.Palette.creamWhisper, in: Capsule())
    .overlay(Capsule().strokeBorder(HaloVisual.Palette.creamHair, lineWidth: 0.5))
  }
}

private struct ClusterPortrait: View {
  let person: HaloPersonNode
  let size: CGFloat
  let moodColor: Color

  var body: some View {
    ZStack {
      Circle().fill(HaloVisual.Palette.nightSurface)

      Circle()
        .fill(
          RadialGradient(
            colors: [moodColor.opacity(0.45), .clear],
            center: UnitPoint(x: 0.32, y: 0.28),
            startRadius: 0,
            endRadius: size * 0.70
          )
        )

      Text(String(person.name.prefix(1)))
        .font(HaloType.serif((size * 0.42).rounded(), weight: .regular))
        .foregroundStyle(HaloVisual.Palette.cream)
    }
    .frame(width: size, height: size)
    .overlay(Circle().strokeBorder(moodColor.opacity(0.68), lineWidth: 1))
    .shadow(color: moodColor.opacity(0.55), radius: 10)
    .overlay(Circle().strokeBorder(HaloVisual.Palette.nightSurface, lineWidth: 2).padding(-2))
  }
}

// MARK: - Silenziosi

private struct StatoSilenziosi: View {
  let people: [HaloPersonNode]
  let onTapPerson: (HaloPersonNode) -> Void

  var body: some View {
    if people.isEmpty {
      EmptyView()
    } else {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Text("silenziosi")
            .haloEyebrow(HaloVisual.Palette.cream, size: 9, tracking: 2.6)

          Text("· \(String(format: "%02d", people.count))")
            .font(HaloType.mono(9, weight: .regular))
            .kerning(0.54)
            .foregroundStyle(HaloVisual.Palette.creamLow)

          Rectangle()
            .fill(HaloVisual.Palette.creamLine)
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
        }

        FlowLayout(spacing: 14) {
          ForEach(people) { person in
            Button(action: { onTapPerson(person) }) {
              HStack(spacing: 8) {
                Circle()
                  .fill(HaloVisual.Palette.nightSurface)
                  .frame(width: 24, height: 24)
                  .overlay(Circle().strokeBorder(HaloVisual.Palette.creamHair, lineWidth: 0.5))
                  .overlay(
                    Text(String(person.name.prefix(1)))
                      .font(HaloType.serif(11, weight: .regular))
                      .foregroundStyle(HaloVisual.Palette.cream)
                  )

                Text(person.name)
                  .font(HaloType.serif(14, weight: .regular))
                  .foregroundStyle(HaloVisual.Palette.creamLow)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 8)
              .background(HaloVisual.Palette.creamWhisper, in: Capsule())
              .overlay(Capsule().strokeBorder(HaloVisual.Palette.creamHair, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(person.name), silenzioso")
          }
        }
      }
      .padding(.horizontal, 22)
    }
  }
}

// MARK: - Detail sheet

private struct StatoDetailSheet: View {
  let cluster: MoodCluster
  let onTapPerson: (HaloPersonNode) -> Void
  let onClose: () -> Void

  private var moodColor: Color { MoodPalette.auraColor(cluster.mood) }

  private var sorted: [HaloPersonNode] {
    cluster.people.sorted { lhs, rhs in
      StatoView.minutesSince(lhs.lastPostAt) < StatoView.minutesSince(rhs.lastPostAt)
    }
  }

  var body: some View {
    ZStack {
      HaloVisual.Palette.warmBlack.ignoresSafeArea()

      ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) {
          HStack {
            HStack(spacing: 8) {
              Circle()
                .fill(moodColor)
                .frame(width: 7, height: 7)
                .shadow(color: moodColor, radius: 6)

              Text("\(cluster.label) · \(String(format: "%02d", cluster.people.count))")
                .haloEyebrow(HaloVisual.Palette.creamLow, size: 9, tracking: 2.6)
            }

            Spacer()

            Button("chiudi", action: onClose)
              .font(HaloType.ui(14, weight: .regular))
              .foregroundStyle(HaloVisual.Palette.creamMute)
              .buttonStyle(.plain)
          }
          .padding(.top, 6)
          .padding(.bottom, 6)

          Text(cluster.headline)
            .font(HaloType.serif(38, weight: .regular))
            .foregroundStyle(HaloVisual.Palette.cream)
            .kerning(-0.57)
            .padding(.bottom, 22)

          ForEach(Array(sorted.enumerated()), id: \.element.id) { index, person in
            Button(action: { onTapPerson(person) }) {
              StatoDetailRow(person: person, moodColor: moodColor)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
              if index > 0 {
                Rectangle()
                  .fill(HaloVisual.Palette.creamLine)
                  .frame(height: 0.5)
              }
            }
          }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
      }
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(SwarmHalo.radiusSheet)
    .presentationBackground(HaloVisual.Palette.warmBlack)
  }
}

private struct StatoDetailRow: View {
  let person: HaloPersonNode
  let moodColor: Color

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      ClusterPortrait(person: person, size: 42, moodColor: moodColor)

      VStack(alignment: .leading, spacing: 3) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(person.name)
            .font(HaloType.serif(19, weight: .regular))
            .foregroundStyle(HaloVisual.Palette.cream)

          Text("· \(tierLabel(person.tier))")
            .haloEyebrow(HaloVisual.Palette.creamMute, size: 8.5, tracking: 2.4)

          Spacer(minLength: 4)

          Text("\(StatoTime.ago(from: person.lastPostAt)) fa")
            .font(HaloType.mono(9, weight: .regular))
            .kerning(0.54)
            .foregroundStyle(HaloVisual.Palette.creamMute)
            .lineLimit(1)
        }

        if person.note.isEmpty {
          Text("solo presenza.")
            .font(HaloType.serif(13, weight: .regular))
            .foregroundStyle(HaloVisual.Palette.creamMute)
        } else {
          Text("“\(person.note)”")
            .font(HaloType.serif(16, weight: .regular))
            .foregroundStyle(HaloVisual.Palette.creamLow)
            .lineSpacing(2)
        }
      }
    }
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }

  private func tierLabel(_ tier: FriendshipTier) -> String {
    switch tier {
    case .inner:  return "inner"
    case .close:  return "close"
    case .orbit:  return "orbita"
    case .nebula: return "nebula"
    case .asteroid: return "asteroidi"
    }
  }
}

// MARK: - Flow layout

/// Minimal wrap-flow layout — used by the silenziosi footer.
private struct FlowLayout: Layout {
  var spacing: CGFloat = 12

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
    let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: maxWidth.isFinite ? maxWidth : rows.map(\.width).max() ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
    var y = bounds.minY

    for row in rows {
      var x = bounds.minX
      for item in row.items {
        let size = item.size
        item.subview.place(
          at: CGPoint(x: x, y: y),
          anchor: .topLeading,
          proposal: ProposedViewSize(size)
        )
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var items: [(subview: LayoutSubview, size: CGSize)] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = [Row()]

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      let lastIndex = rows.count - 1
      let candidateWidth = rows[lastIndex].width + (rows[lastIndex].items.isEmpty ? 0 : spacing) + size.width

      if candidateWidth > maxWidth && !rows[lastIndex].items.isEmpty {
        rows.append(Row())
      }

      let idx = rows.count - 1
      let needsSpacing = !rows[idx].items.isEmpty
      rows[idx].items.append((subview, size))
      rows[idx].width += (needsSpacing ? spacing : 0) + size.width
      rows[idx].height = max(rows[idx].height, size.height)
    }

    return rows
  }
}

#Preview {
  StatoView(
    people: SeedPeople.all + SeedPeople.asteroids,
    onTapPerson: { _ in }
  )
}
