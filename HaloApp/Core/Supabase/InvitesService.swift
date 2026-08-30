import Foundation
import HaloShared
import Supabase

struct HaloInvite: Codable, Identifiable, Hashable {
  let id: UUID
  let token: String
  let inviterId: UUID
  /// `nil` per gli invite "con link" a chi non e ancora su Halo:
  /// l'invitee si aggancia alla riga al momento dell'accettazione.
  let inviteeId: UUID?
  let tier: FriendshipTier
  let message: String?
  let status: String
  let createdAt: Date
  let expiresAt: Date
  let acceptedAt: Date?

  var isPending: Bool { status == "pending" && expiresAt > .now }
  var deepLinkURL: URL? { DeepLink.invite(token: token).url }

  enum CodingKeys: String, CodingKey {
    case id, token, tier, message, status
    case inviterId = "inviter_id"
    case inviteeId = "invitee_id"
    case createdAt = "created_at"
    case expiresAt = "expires_at"
    case acceptedAt = "accepted_at"
  }
}

@MainActor
final class InvitesService {
  static let shared = InvitesService()
  private init() {}

  enum InviteError: LocalizedError {
    case notAuthenticated
    case invalidTarget
    case expired
    case alreadyHandled
    case missingLink

    var errorDescription: String? {
      switch self {
      case .notAuthenticated:
        return "Sessione non valida. Esci e rientra."
      case .invalidTarget:
        return "Questo invite non e per il tuo profilo."
      case .expired:
        return "Questo invite e scaduto."
      case .alreadyHandled:
        return "Questo invite e gia stato usato."
      case .missingLink:
        return "Non riesco a creare il link dell'invite."
      }
    }
  }

  private struct InviteInsert: Encodable {
    let inviterId: UUID
    let inviteeId: UUID?
    let tier: FriendshipTier
    let message: String?

    enum CodingKeys: String, CodingKey {
      case tier, message
      case inviterId = "inviter_id"
      case inviteeId = "invitee_id"
    }
  }

  private struct InviteAcceptUpdate: Encodable {
    /// Valorizzato solo per il claim di un invite aperto.
    var inviteeId: UUID? = nil
    let status: String = "accepted"
    let acceptedAt: Date = .now

    enum CodingKeys: String, CodingKey {
      case status
      case inviteeId = "invitee_id"
      case acceptedAt = "accepted_at"
    }
  }

  private var client: SupabaseClient { SupabaseClientProvider.shared }

  @discardableResult
  func createInnerInvite(to inviteeId: UUID, message: String?) async throws -> HaloInvite {
    guard let me = AuthService.shared.currentUserId() else {
      throw InviteError.notAuthenticated
    }
    guard me != inviteeId else {
      throw InviteError.invalidTarget
    }

    do {
      _ = try await FollowsService.shared.follow(inviteeId)
    } catch {
      // Existing follows are fine; the proposal update below is the important
      // operation for the formal invite.
    }
    try await FollowsService.shared.proposeTier(.inner, for: inviteeId)

    let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
    let row = InviteInsert(
      inviterId: me,
      inviteeId: inviteeId,
      tier: .inner,
      message: trimmed?.isEmpty == true ? nil : trimmed
    )

    let saved: HaloInvite = try await client
      .from("invites")
      .insert(row)
      .select()
      .single()
      .execute()
      .value
    Task {
      await AnalyticsService.shared.track(
        .inviteSent,
        targetUserId: inviteeId,
        inviteId: saved.id,
        tier: saved.tier
      )
    }
    return saved
  }

  /// Crea o recupera il link invito "aperto" per chi non e ancora su Halo:
  /// nessun invitee alla creazione, chi apre il link si aggancia al claim
  /// in `accept(token:)`. Riusa l'ultimo link pending ancora valido, cosi
  /// lo stesso URL puo girare su piu chat senza creare una riga per tap.
  @discardableResult
  func openInviteLink() async throws -> HaloInvite {
    guard let me = AuthService.shared.currentUserId() else {
      throw InviteError.notAuthenticated
    }

    let mine: [HaloInvite] = try await client
      .from("invites")
      .select()
      .eq("inviter_id", value: me)
      .eq("status", value: "pending")
      .order("created_at", ascending: false)
      .limit(20)
      .execute()
      .value
    if let existing = mine.first(where: { $0.inviteeId == nil && $0.isPending }) {
      return existing
    }

    let row = InviteInsert(
      inviterId: me,
      inviteeId: nil,
      tier: .inner,
      message: nil
    )

    let saved: HaloInvite = try await client
      .from("invites")
      .insert(row)
      .select()
      .single()
      .execute()
      .value
    Task {
      await AnalyticsService.shared.track(
        .inviteSent,
        inviteId: saved.id,
        tier: saved.tier
      )
    }
    return saved
  }

  func invite(token: String) async throws -> HaloInvite {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    let invite: HaloInvite = try await client
      .from("invites")
      .select()
      .eq("token", value: trimmed)
      .single()
      .execute()
      .value
    return invite
  }

  func inviterProfile(for invite: HaloInvite) async throws -> Profile {
    try await ProfilesService.shared.profile(id: invite.inviterId)
  }

  @discardableResult
  func accept(token: String) async throws -> HaloInvite {
    guard let me = AuthService.shared.currentUserId() else {
      throw InviteError.notAuthenticated
    }
    let invite = try await invite(token: token)
    if let inviteeId = invite.inviteeId {
      guard inviteeId == me else {
        throw InviteError.invalidTarget
      }
    } else {
      guard invite.inviterId != me else {
        throw InviteError.invalidTarget
      }
    }
    guard invite.expiresAt > .now else {
      throw InviteError.expired
    }
    guard invite.status == "pending" else {
      throw InviteError.alreadyHandled
    }

    if invite.inviteeId == nil {
      // Invite aperto: chi arriva dal link segue l'inviter e propone .inner,
      // lo stesso movimento dello step Initial Inner Circle (la controparte
      // conferma piu avanti). L'edge dell'inviter non si puo creare da qui.
      try await FollowsService.shared.addInitialInnerCandidate(invite.inviterId)
    } else {
      try await FollowsService.shared.acceptProposedTier(on: invite.inviterId)

      do {
        _ = try await FollowsService.shared.follow(invite.inviterId)
      } catch {
        // Already following is acceptable; accepting the proposal above is the
        // state change that confirms the formal Inner invite.
      }
    }

    let updated: HaloInvite = try await client
      .from("invites")
      .update(InviteAcceptUpdate(inviteeId: invite.inviteeId == nil ? me : nil))
      .eq("token", value: invite.token)
      .select()
      .single()
      .execute()
      .value
    Task {
      await AnalyticsService.shared.track(
        .inviteAccepted,
        targetUserId: invite.inviterId,
        inviteId: updated.id,
        tier: updated.tier
      )
    }
    return updated
  }
}
