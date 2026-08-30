import Foundation
import HaloShared
import Supabase

struct HaloInvite: Codable, Identifiable, Hashable {
  let id: UUID
  let token: String
  let inviterId: UUID
  let inviteeId: UUID
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
        return "Questo invito non è per il tuo profilo."
      case .expired:
        return "Questo invito è scaduto."
      case .alreadyHandled:
        return "Questo invito è già stato usato."
      case .missingLink:
        return "Non riesco a creare il link dell'invito."
      }
    }
  }

  private struct InviteInsert: Encodable {
    let inviterId: UUID
    let inviteeId: UUID
    let tier: FriendshipTier
    let message: String?

    enum CodingKeys: String, CodingKey {
      case tier, message
      case inviterId = "inviter_id"
      case inviteeId = "invitee_id"
    }
  }

  private struct InviteAcceptUpdate: Encodable {
    let status: String = "accepted"
    let acceptedAt: Date = .now

    enum CodingKeys: String, CodingKey {
      case status
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
    guard invite.inviteeId == me else {
      throw InviteError.invalidTarget
    }
    guard invite.expiresAt > .now else {
      throw InviteError.expired
    }
    guard invite.status == "pending" else {
      throw InviteError.alreadyHandled
    }

    try await FollowsService.shared.acceptProposedTier(on: invite.inviterId)

    do {
      _ = try await FollowsService.shared.follow(invite.inviterId)
    } catch {
      // Already following is acceptable; accepting the proposal above is the
      // state change that confirms the formal Inner invite.
    }

    let updated: HaloInvite = try await client
      .from("invites")
      .update(InviteAcceptUpdate())
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
