import SwiftUI
import UIKit
import HaloShared

struct InnerInviteSheet: View {
  @Environment(\.dismiss) private var dismiss

  let person: HaloPersonNode

  @State private var message: String = ""
  @State private var invite: HaloInvite?
  @State private var isCreating: Bool = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 0) {
      topRail
        .padding(.horizontal, HaloVisual.SocialSheet.horizontalPadding)
        .padding(.top, HaloVisual.SocialSheet.railTopPadding)
        .padding(.bottom, 10)

      ScrollView {
        VStack(alignment: .leading, spacing: HaloVisual.SocialSheet.sectionSpacing) {
          hero
          if let invite, let url = invite.deepLinkURL {
            createdState(url)
          } else {
            messageField
            if let errorMessage {
              errorText(errorMessage)
            }
          }
        }
        .padding(.horizontal, HaloVisual.SocialSheet.horizontalPadding)
        .padding(.bottom, 18)
      }
      .scrollIndicators(.hidden)

      footer
        .padding(.horizontal, HaloVisual.SocialSheet.footerHorizontalPadding)
        .padding(.vertical, 18)
    }
    .background(haloSocialSheetBackground())
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(HaloVisual.SocialSheet.background)
  }

  private var topRail: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("INNER / INVITE")
          .haloEyebrow(SwarmActivationRole.connected.color, size: 8.5, tracking: 2.3)
        Text(person.name.lowercased())
          .font(HaloType.serif(24, weight: .regular))
          .foregroundStyle(HaloInk.cream)
      }
      Spacer()
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(HaloType.system(12, weight: .semibold))
          .foregroundStyle(HaloInk.creamLow)
          .frame(width: HaloVisual.SocialSheet.closeButtonSize, height: HaloVisual.SocialSheet.closeButtonSize)
          .background(Circle().fill(SwarmHalo.inkWhisper))
          .overlay(Circle().strokeBorder(HaloInk.creamLine, lineWidth: 0.5))
      }
      .buttonStyle(.plain)
    }
  }

  private var hero: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        PortraitView(personId: person.id, size: HaloVisual.SocialSheet.portraitSize, grayscale: true)
          .background(HaloTheme.portraitBacking, in: Circle())
          .overlay(Circle().strokeBorder(SwarmActivationRole.connected.stroke, lineWidth: 0.8))
        VStack(alignment: .leading, spacing: 2) {
          Text("stai aprendo l'Inner.")
            .font(HaloType.serif(22, weight: .regular))
            .foregroundStyle(HaloInk.cream)
          Text("@\(person.handle) riceverà un link privato.")
            .font(HaloType.ui(12, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
        }
      }
      Text("Puoi aggiungere un messaggio. Il link scade tra 14 giorni.")
        .font(HaloType.ui(12, weight: .regular))
        .foregroundStyle(SwarmHalo.inkSecondary)
    }
    .padding(14)
    .haloSocialSurface(
      in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.panelRadius, style: .continuous),
      fill: HaloVisual.SocialSheet.surfaceFill,
      stroke: SwarmActivationRole.connected.stroke
    )
  }

  private var messageField: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader("messaggio")
      TextField("ti ho messo nel mio Inner.", text: $message, axis: .vertical)
        .textFieldStyle(.plain)
        .font(HaloType.serif(17, weight: .regular))
        .foregroundStyle(HaloInk.cream)
        .lineLimit(3, reservesSpace: true)
        .onChange(of: message) { _, newValue in
          if newValue.count > 160 { message = String(newValue.prefix(160)) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .haloSocialSurface(in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous))
      Text("\(message.count)/160")
        .font(HaloType.mono(10, weight: .medium))
        .foregroundStyle(HaloInk.creamMute)
    }
  }

  private func createdState(_ url: URL) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .strokeBorder(
              SwarmActivationRole.connected.stroke,
              style: StrokeStyle(lineWidth: SwarmStroke.standard, dash: [3, 5])
            )
            .frame(width: 58, height: 58)
          Circle()
            .fill(SwarmActivationRole.connected.color.opacity(0.18))
            .frame(width: 8, height: 8)
        }
        Text("invite pronto.")
          .font(HaloType.serif(24, weight: .regular))
          .foregroundStyle(HaloInk.cream)
        Text("manda il link a @\(person.handle). Scade tra 14 giorni.")
          .font(HaloType.ui(13, weight: .regular))
          .foregroundStyle(HaloInk.creamMute)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 26)
      .padding(.horizontal, 14)
      .haloSocialSurface(
        in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.panelRadius, style: .continuous),
        stroke: SwarmActivationRole.connected.stroke
      )
      Text(url.absoluteString)
        .font(HaloType.mono(11, weight: .medium))
        .foregroundStyle(HaloInk.creamLow)
        .lineLimit(3)
        .textSelection(.enabled)
        .padding(12)
        .haloSocialSurface(in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous))
    }
  }

  private var footer: some View {
    HStack {
      if let invite, let url = invite.deepLinkURL {
        Button("copia") {
          UIPasteboard.general.string = url.absoluteString
          HapticEngine.selection()
        }
        .font(HaloType.ui(14, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(HaloInk.creamMute)
        Spacer()
        ShareLink(item: url) {
          Label("condividi", systemImage: "square.and.arrow.up")
            .font(HaloType.ui(15, weight: .semibold))
            .foregroundStyle(HaloInk.cream)
            .padding(.horizontal, 20)
            .frame(minHeight: HaloVisual.SocialSheet.actionHeight)
            .haloSocialSurface(
              in: Capsule(),
              fill: SwarmActivationRole.connected.fill,
              stroke: SwarmActivationRole.connected.stroke
            )
        }
      } else {
        Button("annulla") { dismiss() }
          .font(HaloType.ui(14, weight: .medium))
          .buttonStyle(.plain)
          .foregroundStyle(HaloInk.creamMute)
        Spacer()
        Button {
          Task { await createInvite() }
        } label: {
          Text(isCreating ? "creo..." : "crea invito")
            .font(HaloType.ui(15, weight: .semibold))
            .foregroundStyle(SwarmHalo.background)
            .padding(.horizontal, 22)
            .frame(minHeight: HaloVisual.SocialSheet.actionHeight)
            .background(SwarmActivationRole.connected.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
      }
    }
  }

  private func sectionHeader(_ text: String) -> some View {
    HStack(spacing: 8) {
      Text(text)
        .haloEyebrow(HaloInk.creamMute, size: 8.5, tracking: 2.0)
      Rectangle()
        .fill(HaloInk.creamLine)
        .frame(height: 0.5)
    }
  }

  private func errorText(_ message: String) -> some View {
    Text(message)
      .font(HaloType.ui(12, weight: .regular))
      .foregroundStyle(SwarmHalo.attention)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .haloSocialSurface(
        in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous),
        fill: SwarmActivationRole.attention.fill,
        stroke: SwarmActivationRole.attention.stroke
      )
  }

  @MainActor
  private func createInvite() async {
    guard !isCreating else { return }
    if DemoMode.isActive {
      isCreating = true
      errorMessage = nil
      defer { isCreating = false }
      invite = Self.demoInvite(for: person, message: message)
      return
    }

    guard let userId = UUID(uuidString: person.id) else {
      errorMessage = "Questo profilo non può ricevere inviti."
      return
    }

    isCreating = true
    errorMessage = nil
    defer { isCreating = false }

    do {
      invite = try await InvitesService.shared.createInnerInvite(
        to: userId,
        message: message.isEmpty ? "ti ho messo nel mio Inner." : message
      )
    } catch {
      errorMessage = InviteSheetErrorCopy.describe(
        error,
        fallback: "Non riesco a creare l'invito. Riprova."
      )
    }
  }

  private static func demoInvite(for person: HaloPersonNode, message: String) -> HaloInvite {
    HaloInvite(
      id: fixedUUID("00000000-0000-4000-8000-000000080001"),
      token: "demo-inner-\(person.handle)",
      inviterId: fixedUUID("00000000-0000-4000-8000-000000080002"),
      inviteeId: fixedUUID("00000000-0000-4000-8000-000000080003"),
      tier: .inner,
      message: message.isEmpty ? "ti ho messo nel mio Inner." : message,
      status: "pending",
      createdAt: .now,
      expiresAt: Date.now.addingTimeInterval(14 * 24 * 3600),
      acceptedAt: nil
    )
  }

  private static func fixedUUID(_ rawValue: String) -> UUID {
    UUID(uuidString: rawValue) ?? UUID()
  }
}

struct InviteAcceptSheet: View {
  @Environment(\.dismiss) private var dismiss

  let token: String

  @State private var invite: HaloInvite?
  @State private var inviter: Profile?
  @State private var isLoading: Bool = true
  @State private var isAccepting: Bool = false
  @State private var didAccept: Bool = false
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 0) {
      topRail
        .padding(.horizontal, HaloVisual.SocialSheet.horizontalPadding)
        .padding(.top, HaloVisual.SocialSheet.railTopPadding)
        .padding(.bottom, 10)

      VStack(spacing: 14) {
        if isLoading {
          loadingState
        } else if didAccept {
          statusState(
            title: "Inner confermato.",
            message: "ora puoi chiudere questa finestra.",
            activation: .connected
          )
        } else if let errorMessage {
          statusState(
            title: "invite non valido.",
            message: errorMessage,
            activation: .attention
          )
        } else if let invite, let inviter {
          inviteBody(invite: invite, inviter: inviter)
        }
      }
      .padding(.horizontal, HaloVisual.SocialSheet.horizontalPadding)
      .frame(maxHeight: .infinity, alignment: .top)

      footer
        .padding(.horizontal, HaloVisual.SocialSheet.footerHorizontalPadding)
        .padding(.vertical, 18)
    }
    .background(haloSocialSheetBackground())
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(HaloTheme.sheetCornerRadius)
    .presentationBackground(HaloVisual.SocialSheet.background)
    .task {
      await load()
    }
  }

  private var topRail: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("HALO / INVITE")
          .haloEyebrow(SwarmActivationRole.connected.color, size: 8.5, tracking: 2.3)
        Text("richiesta Inner")
          .font(HaloType.serif(24, weight: .regular))
          .foregroundStyle(HaloInk.cream)
      }
      Spacer()
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(HaloType.system(12, weight: .semibold))
          .foregroundStyle(HaloInk.creamLow)
          .frame(width: HaloVisual.SocialSheet.closeButtonSize, height: HaloVisual.SocialSheet.closeButtonSize)
          .background(Circle().fill(SwarmHalo.inkWhisper))
          .overlay(Circle().strokeBorder(HaloInk.creamLine, lineWidth: 0.5))
      }
      .buttonStyle(.plain)
    }
  }

  private func inviteBody(invite: HaloInvite, inviter: Profile) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        PortraitView(personId: inviter.id.uuidString, size: 52, grayscale: true)
          .background(HaloTheme.portraitBacking, in: Circle())
          .overlay(Circle().strokeBorder(SwarmActivationRole.connected.stroke, lineWidth: 0.8))
        VStack(alignment: .leading, spacing: 3) {
          Text("\(inviter.displayName) ti ha messo nel suo Inner.")
            .font(HaloType.serif(24, weight: .regular))
            .foregroundStyle(HaloInk.cream)
            .fixedSize(horizontal: false, vertical: true)
          Text("@\(inviter.handle)")
            .font(HaloType.ui(12, weight: .regular))
            .foregroundStyle(HaloInk.creamMute)
        }
      }

      if let message = invite.message, !message.isEmpty {
        Text(message)
          .font(HaloType.serif(17, weight: .regular))
          .foregroundStyle(HaloInk.creamLow)
          .padding(14)
          .haloSocialSurface(in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.fieldRadius, style: .continuous))
      }
    }
    .padding(14)
    .haloSocialSurface(
      in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.panelRadius, style: .continuous),
      fill: HaloVisual.SocialSheet.surfaceFill,
      stroke: SwarmActivationRole.connected.stroke
    )
  }

  private var loadingState: some View {
    VStack(spacing: SwarmHalo.s3) {
      ProgressView()
        .tint(HaloInk.cream)
      Text("carico invite")
        .haloEyebrow(HaloInk.creamMute, size: 8, tracking: 1.8)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, SwarmHalo.s8)
    .haloSocialSurface(
      in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.panelRadius, style: .continuous)
    )
  }

  private func statusState(
    title: String,
    message: String,
    activation: SwarmActivationRole
  ) -> some View {
    VStack(spacing: SwarmHalo.s3) {
      ZStack {
        Circle()
          .strokeBorder(
            activation.stroke,
            style: StrokeStyle(lineWidth: SwarmStroke.standard, dash: [3, 5])
          )
          .frame(width: 68, height: 68)
        Circle()
          .fill(activation.color.opacity(0.16))
          .frame(width: 8, height: 8)
      }
      Text(title)
        .font(HaloType.serif(24, weight: .regular))
        .foregroundStyle(HaloInk.cream)
      Text(message)
        .font(HaloType.ui(13, weight: .regular))
        .foregroundStyle(HaloInk.creamMute)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, SwarmHalo.s8)
    .padding(.horizontal, SwarmHalo.s4)
    .haloSocialSurface(
      in: RoundedRectangle(cornerRadius: HaloVisual.SocialSheet.panelRadius, style: .continuous),
      fill: activation.fill,
      stroke: activation.stroke
    )
  }

  private var footer: some View {
    HStack {
      Button("chiudi") { dismiss() }
        .font(HaloType.ui(14, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(HaloInk.creamMute)
      Spacer()
      if !didAccept && errorMessage == nil && !isLoading {
        Button {
          Task { await accept() }
        } label: {
          Text(isAccepting ? "confermo..." : "conferma Inner")
            .font(HaloType.ui(15, weight: .semibold))
            .foregroundStyle(SwarmHalo.background)
            .padding(.horizontal, 22)
            .frame(minHeight: HaloVisual.SocialSheet.actionHeight)
            .background(SwarmActivationRole.connected.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isAccepting)
      }
    }
  }

  @MainActor
  private func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    if DemoMode.isActive {
      invite = Self.demoInvite(token: token)
      inviter = Self.demoInviter
      return
    }

    do {
      let invite = try await InvitesService.shared.invite(token: token)
      self.invite = invite
      self.inviter = try await InvitesService.shared.inviterProfile(for: invite)
      if !invite.isPending {
        errorMessage = "Questo invito è scaduto o è già stato usato."
      }
    } catch {
      errorMessage = InviteSheetErrorCopy.describe(
        error,
        fallback: "Questo invito non è valido o non è più disponibile."
      )
    }
  }

  @MainActor
  private func accept() async {
    guard !isAccepting else { return }
    isAccepting = true
    errorMessage = nil
    defer { isAccepting = false }

    if DemoMode.isActive {
      invite = Self.demoInvite(token: token, status: "accepted", acceptedAt: .now)
      didAccept = true
      return
    }

    do {
      invite = try await InvitesService.shared.accept(token: token)
      didAccept = true
    } catch {
      errorMessage = InviteSheetErrorCopy.describe(
        error,
        fallback: "Non riesco a confermare questo invito. Riprova."
      )
    }
  }

  private static func demoInvite(
    token: String,
    status: String = "pending",
    acceptedAt: Date? = nil
  ) -> HaloInvite {
    HaloInvite(
      id: fixedUUID("00000000-0000-4000-8000-000000080101"),
      token: token.isEmpty ? "demo-inner-you" : token,
      inviterId: demoInviter.id,
      inviteeId: fixedUUID("00000000-0000-4000-8000-000000080102"),
      tier: .inner,
      message: "ti ho messo nel mio Inner.",
      status: status,
      createdAt: .now,
      expiresAt: Date.now.addingTimeInterval(14 * 24 * 3600),
      acceptedAt: acceptedAt
    )
  }

  private static let demoInviter = Profile(
    id: fixedUUID("00000000-0000-4000-8000-000000080103"),
    handle: "gia",
    displayName: "Giacomo"
  )

  private static func fixedUUID(_ rawValue: String) -> UUID {
    UUID(uuidString: rawValue) ?? UUID()
  }
}

private enum InviteSheetErrorCopy {
  static func describe(_ error: Error, fallback: String) -> String {
    if let inviteError = error as? InvitesService.InviteError,
       let message = inviteError.errorDescription {
      return message
    }

    let described = SupabaseErrorMessage.describe(error, fallback: fallback)
    if described == SupabaseErrorMessage.connectivity {
      return described
    }

    return fallback
  }
}
