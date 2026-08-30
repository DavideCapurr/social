import Foundation
import Observation
import HaloShared

/// Demo/offline mode toggle, attivato passando `HALO_DEMO=1` come variabile
/// d'ambiente al processo (es. da Xcode scheme o `simctl launch`).
///
/// Quando attivo l'app bypassa auth + Supabase e idrata le superfici principali
/// con `SeedPeople`, così da poter ispezionare l'UI con contenuti realistici.
/// Non ha alcun effetto sulle build di produzione (variabile assente → `false`).
enum DemoMode {
  static let isActive: Bool = ProcessInfo.processInfo.environment["HALO_DEMO"] == "1"
  static let phaseOverride: String? = ProcessInfo.processInfo.environment["HALO_DEMO_PHASE"]
}

@Observable
@MainActor
final class AppState {
  enum Route: Hashable {
    case home
    case haloSpace(userId: UUID)
    case profile(userId: UUID)
    case invite(token: String)
    case memory
    case ring(id: UUID)
    case ringJoin(token: String)
    case report(userId: UUID)
  }

  enum Phase: Equatable {
    case launching     // verifica sessione iniziale
    case signedOut     // SignInView
    case onboarding    // handle / display / avatar
    case initialCircle // primi Inner
    case ready         // Home
  }

  var phase: Phase = .launching
  var currentProfile: Profile?
  var route: Route = .home
  var launchErrorMessage: String?

  var isAuthenticated: Bool { currentProfile != nil }

  private let initialCircleSkipPrefix = "halo.initialCircleSkipped."

  // MARK: - Bootstrap

  /// Ripristina lo stato della sessione all'avvio dell'app.
  /// - presente `currentUserId` → carica il profilo:
  ///     - se profilo trovato → `.ready`
  ///     - se profilo manca → `.onboarding` (Apple ha creato l'account ma non il profile)
  /// - assente → `.signedOut`
  func restore() async {
    launchErrorMessage = nil
    if DemoMode.isActive {
      currentProfile = Self.demoProfile
      switch DemoMode.phaseOverride {
      case "signedOut":
        currentProfile = nil
        phase = .signedOut
      case "onboarding":
        currentProfile = Profile(id: Self.demoProfile.id, handle: "halo_demo", displayName: "Halo")
        phase = .onboarding
      case "initialCircle":
        phase = .initialCircle
      default:
        phase = .ready
      }
      return
    }
    if AuthService.shared.currentUserId() != nil {
      do {
        let p = try await ProfilesService.shared.currentProfile()
        currentProfile = p
        await routeAfterAuthenticatedProfile(p)
      } catch ProfilesService.ProfilesError.notFound {
        phase = .onboarding
      } catch {
        launchErrorMessage = SupabaseErrorMessage.describe(
          error,
          fallback: "Non riesco a caricare il profilo. Riprova."
        )
        phase = .launching
      }
    } else {
      phase = .signedOut
    }
  }

  // MARK: - Mutations

  func didSignIn(_ profile: Profile) {
    launchErrorMessage = nil
    currentProfile = profile
    if profileNeedsOnboarding(profile) {
      phase = .onboarding
    } else {
      phase = .launching
      Task { await routeAfterAuthenticatedProfile(profile) }
    }
  }

  func didFinishOnboarding(_ profile: Profile) {
    launchErrorMessage = nil
    currentProfile = profile
    phase = .launching
    Task { await routeAfterAuthenticatedProfile(profile) }
  }

  func didFinishInitialCircle() {
    phase = .ready
  }

  func didSkipInitialCircle() {
    if let profileId = currentProfile?.id {
      UserDefaults.standard.set(true, forKey: initialCircleSkipKey(for: profileId))
    }
    phase = .ready
  }

  func didSignOut() {
    launchErrorMessage = nil
    currentProfile = nil
    phase = .signedOut
    route = .home
  }

  func refreshCurrentProfile() async {
    guard currentProfile != nil else { return }
    do {
      currentProfile = try await ProfilesService.shared.currentProfile()
    } catch {
      // Keep the previous cache if the refresh fails; visible surfaces can retry.
    }
  }

  // MARK: - Routing

  func handle(link: DeepLink) {
    switch link {
    case .haloSpace(let userId):
      route = .haloSpace(userId: userId)
    case .invite(let token):
      route = .invite(token: token)
    case .memory:
      route = .memory
    case .ring(let id):
      route = .ring(id: id)
    case .ringJoin(let token):
      route = .ringJoin(token: token)
    case .report(let userId):
      route = .report(userId: userId)
    }
  }

  // MARK: - Phase routing

  private func routeAfterAuthenticatedProfile(_ profile: Profile) async {
    currentProfile = profile

    if profileNeedsOnboarding(profile) {
      phase = .onboarding
      return
    }

    phase = await initialCircleNeeded(for: profile) ? .initialCircle : .ready
  }

  private func profileNeedsOnboarding(_ profile: Profile) -> Bool {
    profile.handle.hasPrefix("halo_") || profile.displayName == "Halo"
  }

  /// Serve quando l'utente non ha ancora scelto/proposto nessuno per Inner e
  /// non ha saltato esplicitamente il passaggio su questo device.
  private func initialCircleNeeded(for profile: Profile) async -> Bool {
    guard !UserDefaults.standard.bool(forKey: initialCircleSkipKey(for: profile.id)) else {
      return false
    }

    do {
      return try await !FollowsService.shared.hasStartedInnerCircle()
    } catch {
      return false
    }
  }

  private func initialCircleSkipKey(for profileId: UUID) -> String {
    "\(initialCircleSkipPrefix)\(profileId.uuidString.lowercased())"
  }

  private static let demoProfile = Profile(
    id: UUID(uuidString: "00000000-0000-4000-8000-000000000101") ?? UUID(),
    handle: "you",
    displayName: "Tu"
  )
}
