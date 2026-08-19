import HaloShared
import SwiftUI
import UIKit

struct ClubRingView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  private let allowedKinds: [RingKind] = [.club, .course, .founder]

  @State private var selectedKind: RingKind
  @State private var rings: [HaloRing] = []
  @State private var selectedRing: HaloRing?
  @State private var members: [RingMember] = []
  @State private var subscriptions: [RingSubscription] = []
  @State private var billing: [ClubBilling] = []
  @State private var showCreate = false
  @State private var isLoading = false
  @State private var isJoining = false
  @State private var isStartingCheckout = false
  @State private var isOpeningPortal = false
  @State private var statusMessage: String?
  @State private var errorMessage: String?

  init(kind: RingKind = .club) {
    _selectedKind = State(initialValue: [.club, .course, .founder].contains(kind) ? kind : .club)
  }

  var body: some View {
    ZStack {
      DeepSpaceBackground()
      ScrollView {
        VStack(alignment: .leading, spacing: SwarmHalo.s4) {
          rail
          kindPicker
          selectedPanel
          ringList
        }
        .padding(.horizontal, SwarmHalo.s4)
        .padding(.top, SwarmHalo.s3)
        .padding(.bottom, SwarmHalo.s8)
      }
      .scrollIndicators(.hidden)
    }
    .presentationDetents([.large])
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(.clear)
    .task { await load() }
    .onChange(of: selectedKind) { _, _ in
      selectedRing = nil
      Task { await load() }
    }
    .sheet(isPresented: $showCreate) {
      RingCreateSheet(kind: selectedKind) { ring in
        selectedRing = ring
        Task { await load() }
      }
    }
  }

  private var rail: some View {
    SwarmOperationalRail(
      title: "HALO / RINGS",
      context: selectedKind.label,
      activation: role
    ) {
      HStack(spacing: SwarmHalo.s2) {
        Button(action: { showCreate = true }) {
          Image(systemName: "plus")
            .font(HaloType.system(12, weight: .semibold))
            .foregroundStyle(role.color)
            .swarmIconFrame(active: true, activation: role)
        }
        .buttonStyle(.plain)

        Button(action: { dismiss() }) {
          Image(systemName: "xmark")
            .font(HaloType.system(12, weight: .semibold))
            .foregroundStyle(SwarmHalo.inkSecondary)
            .swarmIconFrame()
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var kindPicker: some View {
    HaloSegmentedControl(
      selection: $selectedKind,
      segments: allowedKinds.map { HaloSegment($0, title: $0.label) },
      accent: role.color
    )
  }

  @ViewBuilder
  private var selectedPanel: some View {
    if isLoading && selectedRing == nil {
      SwarmLoadingState(label: "rings")
    } else if let ring = selectedRing {
      VStack(alignment: .leading, spacing: SwarmHalo.s4) {
        HStack(alignment: .top, spacing: SwarmHalo.s3) {
          RingKindBadge(kind: ring.kind)
          VStack(alignment: .leading, spacing: SwarmHalo.s2) {
            Text(ring.title.lowercased())
              .font(HaloType.serif(36, weight: .regular))
              .foregroundStyle(SwarmHalo.ink)
              .fixedSize(horizontal: false, vertical: true)
            Text(ring.subtitle ?? panelFallback(for: ring))
              .font(HaloType.ui(13, weight: .regular))
              .foregroundStyle(SwarmHalo.inkSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
        }

        RingScheduleRow(ring: ring)

        HStack(spacing: 0) {
          SwarmMetricTile(label: "members", value: twoDigits(members.count), activation: .connected, active: !members.isEmpty)
          Rectangle().fill(SwarmHalo.inkLine).frame(width: SwarmStroke.hairline, height: 28)
          SwarmMetricTile(label: "active", value: twoDigits(activeSubscriptions), activation: .operational, active: activeSubscriptions > 0)
          Rectangle().fill(SwarmHalo.inkLine).frame(width: SwarmStroke.hairline, height: 28)
          SwarmMetricTile(label: "billing", value: money(totalPaidCents, currency: ring.currency), activation: .attention, active: totalPaidCents > 0)
        }
        .padding(.vertical, SwarmHalo.s3)
        .swarmSurface(.rail, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous))

        HStack(alignment: .top, spacing: SwarmHalo.s3) {
          Image(systemName: "building.2")
            .font(HaloType.system(14, weight: .semibold))
            .foregroundStyle(role.color)
            .swarmIconFrame(active: true, activation: role)
          VStack(alignment: .leading, spacing: 4) {
            Text(billingTitle(for: ring))
              .font(HaloType.ui(14, weight: .semibold))
              .foregroundStyle(SwarmHalo.ink)
            Text(billingCopy(for: ring))
              .font(HaloType.ui(12, weight: .regular))
              .foregroundStyle(SwarmHalo.inkSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
        }
        .padding(SwarmHalo.s3)
        .swarmSurface(.control, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous), activation: role)

        if canManageSelectedRing && !StripeBillingPlan.available(for: ring.kind).isEmpty {
          billingActionPanel(for: ring)
        }

        HStack(spacing: SwarmHalo.s3) {
          SwarmCommandButton(
            label: isJoining ? "join" : "join",
            icon: ring.isPublic ? "person.badge.plus" : "link",
            activation: role,
            isProminent: ring.isPublic
          ) {
            Task { await join(ring) }
          }
          .disabled(isJoining)
          .opacity(isJoining ? 0.55 : 1)

          if let url = ring.joinURL {
            ShareLink(item: url) {
              Label("share", systemImage: "square.and.arrow.up")
                .font(HaloType.ui(13, weight: .semibold))
                .foregroundStyle(SwarmHalo.ink)
                .padding(.horizontal, SwarmHalo.s4)
                .padding(.vertical, 10)
                .background(role.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(role.stroke, lineWidth: SwarmStroke.standard))
            }
          }

          Button {
            UIPasteboard.general.string = ring.joinToken
            statusMessage = "token copiato."
          } label: {
            Image(systemName: "doc.on.doc")
              .font(HaloType.system(14, weight: .semibold))
              .foregroundStyle(SwarmHalo.ink)
              .swarmIconFrame()
          }
          .buttonStyle(.plain)
        }

        if let errorMessage {
          Text(errorMessage)
            .font(HaloType.ui(12, weight: .regular))
            .foregroundStyle(SwarmActivationRole.attention.color)
        } else if let statusMessage {
          Text(statusMessage)
            .font(HaloType.ui(12, weight: .regular))
            .foregroundStyle(SwarmHalo.inkSecondary)
        }

        if let payload = ring.joinURL?.absoluteString {
          HStack(spacing: SwarmHalo.s4) {
            RingQRCode(payload: payload)
              .frame(width: 102, height: 102)
            VStack(alignment: .leading, spacing: SwarmHalo.s2) {
              Text("TOKEN")
                .haloEyebrow(role.color, size: 8.5, tracking: 2.0)
              Text(ring.joinToken)
                .font(HaloType.mono(11, weight: .medium))
                .foregroundStyle(SwarmHalo.inkSecondary)
                .lineLimit(3)
                .textSelection(.enabled)
            }
            Spacer()
          }
          .padding(SwarmHalo.s3)
          .swarmSurface(.card, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous), activation: role)
        }
      }
      .padding(SwarmHalo.s4)
      .swarmSurface(.sheet, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous), activation: role)
    } else {
      SwarmEmptyState(
        title: emptyTitle,
        message: "crea un ring o entra con token.",
        activation: role
      )
    }
  }

  private var ringList: some View {
    VStack(alignment: .leading, spacing: SwarmHalo.s3) {
      sectionHeader("index")
      ForEach(rings) { ring in
        Button {
          selectedRing = ring
          Task { await loadSelectedMetadata() }
        } label: {
          RingListRow(
            ring: ring,
            isSelected: selectedRing?.id == ring.id,
            accessory: accessory(for: ring)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var role: SwarmActivationRole {
    switch selectedKind {
    case .club: return .operational
    case .course: return .connected
    case .founder: return .rest
    case .event: return .attention
    }
  }

  private var emptyTitle: String {
    switch selectedKind {
    case .club: return "nessun club."
    case .course: return "nessun corso."
    case .founder: return "nessun founder circle."
    case .event: return "nessun ring."
    }
  }

  private var activeSubscriptions: Int {
    subscriptions.filter { ["active", "trialing", "comped"].contains($0.status) }.count
  }

  private var totalPaidCents: Int {
    billing
      .filter { $0.status == "paid" }
      .reduce(0) { $0 + $1.amountCents }
  }

  private var activePlan: String? {
    subscriptions.first { ["active", "trialing", "comped"].contains($0.status) }?.plan
  }

  private var canManageSelectedRing: Bool {
    guard let userId = AuthService.shared.currentUserId() else { return false }
    return members.contains {
      $0.userId == userId
        && $0.status == .active
        && [.owner, .admin, .host, .founder].contains($0.role)
    }
  }

  private var activeStripeCustomerId: String? {
    subscriptions.first {
      $0.provider == "stripe"
        && ["active", "trialing", "past_due", "incomplete"].contains($0.status)
        && $0.providerCustomerId != nil
    }?.providerCustomerId ?? subscriptions.first {
      $0.provider == "stripe" && $0.providerCustomerId != nil
    }?.providerCustomerId
  }

  private func billingActionPanel(for ring: HaloRing) -> some View {
    VStack(alignment: .leading, spacing: SwarmHalo.s3) {
      sectionHeader("stripe")

      VStack(spacing: SwarmHalo.s2) {
        ForEach(StripeBillingPlan.available(for: ring.kind)) { plan in
          billingPlanButton(plan, ring: ring)
        }
      }

      SwarmCommandButton(
        label: isOpeningPortal ? "portal" : "portal",
        icon: "creditcard",
        activation: role
      ) {
        Task { await openBillingPortal(for: ring) }
      }
      .disabled(isOpeningPortal || activeStripeCustomerId == nil)
      .opacity((isOpeningPortal || activeStripeCustomerId == nil) ? 0.55 : 1)
    }
    .padding(SwarmHalo.s3)
    .swarmSurface(.card, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusCard, style: .continuous), activation: role)
  }

  private func billingPlanButton(_ plan: StripeBillingPlan, ring: HaloRing) -> some View {
    Button {
      Task { await startCheckout(plan, for: ring) }
    } label: {
      HStack(spacing: SwarmHalo.s3) {
        Image(systemName: isStartingCheckout ? "clock" : "arrow.up.right")
          .font(HaloType.system(13, weight: .semibold))
          .foregroundStyle(role.color)
          .swarmIconFrame(active: true, activation: role)
        VStack(alignment: .leading, spacing: 2) {
          Text(plan.title.lowercased())
            .font(HaloType.ui(13, weight: .semibold))
            .foregroundStyle(SwarmHalo.ink)
          Text(plan.subtitle)
            .font(HaloType.ui(11, weight: .regular))
            .foregroundStyle(SwarmHalo.inkMuted)
        }
        Spacer()
        Text(plan.priceText)
          .font(HaloType.mono(10, weight: .medium))
          .foregroundStyle(SwarmHalo.inkSecondary)
      }
      .padding(SwarmHalo.s2)
      .swarmSurface(.control, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous), activation: role)
    }
    .buttonStyle(.plain)
    .disabled(isStartingCheckout || isOpeningPortal)
    .opacity((isStartingCheckout || isOpeningPortal) ? 0.58 : 1)
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

  @MainActor
  private func load() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let loaded = try await RingsService.shared.rings(kind: selectedKind)
      rings = loaded.sorted { $0.createdAt > $1.createdAt }
      if let selectedRing,
         let fresh = rings.first(where: { $0.id == selectedRing.id }) {
        self.selectedRing = fresh
      } else {
        selectedRing = rings.first
      }
      await loadSelectedMetadata()
      errorMessage = nil
    } catch {
      errorMessage = SupabaseErrorMessage.describe(error, fallback: "Non riesco a caricare i ring.")
    }
  }

  @MainActor
  private func loadSelectedMetadata() async {
    guard let selectedRing else {
      members = []
      subscriptions = []
      billing = []
      return
    }

    async let membersTask = RingsService.shared.members(for: selectedRing.id)
    async let subscriptionsTask = RingsService.shared.subscriptions(for: selectedRing.id)
    async let billingTask = RingsService.shared.billing(for: selectedRing.id)
    do {
      members = try await membersTask
      subscriptions = try await subscriptionsTask
      billing = try await billingTask
    } catch {
      members = []
      subscriptions = []
      billing = []
    }
  }

  @MainActor
  private func join(_ ring: HaloRing) async {
    isJoining = true
    defer { isJoining = false }
    errorMessage = nil
    statusMessage = nil

    do {
      let joined: HaloRing
      if ring.isPublic {
        joined = try await RingsService.shared.joinPublic(ringId: ring.id)
      } else {
        joined = try await RingsService.shared.join(token: ring.joinToken)
      }
      selectedRing = joined
      statusMessage = "sei dentro \(joined.title)."
      await load()
    } catch {
      errorMessage = SupabaseErrorMessage.describe(error, fallback: "Join non riuscito.")
    }
  }

  @MainActor
  private func startCheckout(_ plan: StripeBillingPlan, for ring: HaloRing) async {
    isStartingCheckout = true
    defer { isStartingCheckout = false }
    errorMessage = nil
    statusMessage = nil

    do {
      let url = try await BillingService.shared.checkout(ringId: ring.id, plan: plan)
      openURL(url)
      statusMessage = "checkout Stripe aperto."
    } catch {
      errorMessage = SupabaseErrorMessage.describe(error, fallback: "Checkout Stripe non riuscito.")
    }
  }

  @MainActor
  private func openBillingPortal(for ring: HaloRing) async {
    isOpeningPortal = true
    defer { isOpeningPortal = false }
    errorMessage = nil
    statusMessage = nil

    do {
      let url = try await BillingService.shared.customerPortal(
        ringId: ring.id,
        stripeCustomerId: activeStripeCustomerId
      )
      openURL(url)
      statusMessage = "portal Stripe aperto."
    } catch {
      errorMessage = SupabaseErrorMessage.describe(error, fallback: "Portal Stripe non disponibile.")
    }
  }

  private func panelFallback(for ring: HaloRing) -> String {
    switch ring.kind {
    case .club:
      return ring.priceCents == nil ? "club privato" : "club \(money(ring.priceCents ?? 0, currency: ring.currency))"
    case .course:
      return "course ring"
    case .founder:
      return "founder circle"
    case .event:
      return "event ring"
    }
  }

  private func billingTitle(for ring: HaloRing) -> String {
    switch ring.kind {
    case .club:
      return activeSubscriptions > 0 ? "checkout club attivo" : "checkout club pronto"
    case .course:
      return activeSubscriptions > 0 ? "checkout corso attivo" : "checkout corso pronto"
    case .founder:
      return "billing founder manuale"
    case .event:
      return "checkout evento pronto"
    }
  }

  private func billingCopy(for ring: HaloRing) -> String {
    let plan = activePlan.map { " · \($0.replacingOccurrences(of: "_", with: " "))" } ?? ""
    let paid = totalPaidCents > 0 ? " · incassato \(money(totalPaidCents, currency: ring.currency))" : ""
    return "Checkout e ricevute passano da Stripe; il portal si abilita quando arriva il customer dal webhook\(plan)\(paid)."
  }

  private func accessory(for ring: HaloRing) -> String {
    if let price = ring.priceCents, price > 0 {
      return money(price, currency: ring.currency)
    }
    return ring.isPublic ? "public" : "token"
  }

  private func money(_ cents: Int, currency: String) -> String {
    let amount = Double(cents) / 100
    let symbol = currency.lowercased() == "eur" ? "EUR" : currency.uppercased()
    if amount >= 100 {
      return "\(symbol) \(Int(amount))"
    }
    return "\(symbol) \(String(format: "%.2f", amount))"
  }

  private func twoDigits(_ value: Int) -> String {
    String(format: "%02d", value)
  }
}
