import SwiftUI
import AuthenticationServices
import CryptoKit
import HaloShared
import Security

/// Sign in con Apple + fallback email/password. Bridge ad `AuthService`.
struct SignInView: View {
  var onSignedIn: (Profile) -> Void = { _ in }

  @State private var showEmail: Bool = false
  @State private var email: String = ""
  @State private var password: String = ""
  @State private var errorMessage: String?
  @State private var isWorking: Bool = false
  @State private var appleNonce: String = ""

  var body: some View {
    ZStack {
      WelcomeManifestoView {
        signInControls
      }

      if isWorking {
        SwarmLoadingState(label: "accesso")
          .padding(.horizontal, SwarmHalo.s6)
      }
    }
    .preferredColorScheme(.dark)
    .animation(.easeInOut(duration: 0.25), value: showEmail)
  }

  // MARK: - email block

  private var signInControls: some View {
    VStack(spacing: SwarmHalo.s3) {
      SignInWithAppleButton(
        onRequest: { request in
          prepareAppleRequest(request)
        },
        onCompletion: { result in
          handleApple(result)
        }
      )
      .signInWithAppleButtonStyle(.white)
      .frame(height: 52)

      Button {
        showEmail.toggle()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: showEmail ? "chevron.up" : "envelope.fill")
            .font(HaloType.system(12, weight: .semibold))
          Text(showEmail ? "nascondi email" : "email e password")
            .font(HaloType.ui(14, weight: .medium))
        }
        .foregroundStyle(HaloInk.cream)
        .frame(maxWidth: .infinity)
        .frame(minHeight: HaloVisual.Auth.controlMinHeight)
        .background(SwarmHalo.inkWhisper, in: Capsule())
        .overlay(Capsule().strokeBorder(SwarmHalo.strokeSoft, lineWidth: SwarmStroke.standard))
      }
      .buttonStyle(.plain)

      if showEmail {
        emailBlock
          .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      if let err = errorMessage {
        Text(err)
          .font(HaloType.ui(12, weight: .regular))
          .foregroundStyle(SwarmHalo.attention)
          .multilineTextAlignment(.center)
      }
    }
  }

  @ViewBuilder
  private var emailBlock: some View {
    let disabled = !canSubmitEmail || isWorking
    VStack(alignment: .leading, spacing: HaloVisual.Auth.formSpacing) {
      HaloAuthField(label: "email", hint: "usa l'email del tuo account Halo") {
        TextField("nome@email.com", text: $email)
          .textFieldStyle(.plain)
          .font(HaloType.ui(15, weight: .regular))
          .foregroundStyle(HaloInk.cream)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }

      HaloAuthField(label: "password", hint: "minimo 6 caratteri") {
        SecureField("password", text: $password)
          .textFieldStyle(.plain)
          .font(HaloType.ui(15, weight: .regular))
          .foregroundStyle(HaloInk.cream)
          .textContentType(.password)
      }

      Button {
        Task { await signInWithEmail() }
      } label: {
        Text("accedi")
          .font(HaloType.ui(15, weight: .semibold))
          .foregroundStyle(disabled ? HaloInk.creamMute : SwarmHalo.absoluteBlack)
          .frame(maxWidth: .infinity)
          .frame(minHeight: HaloVisual.Auth.controlMinHeight)
          .background(
            disabled ? SwarmHalo.inkWhisper : SwarmActivationRole.connected.color,
            in: RoundedRectangle(cornerRadius: HaloVisual.Auth.buttonRadius, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: HaloVisual.Auth.buttonRadius, style: .continuous)
              .strokeBorder(disabled ? SwarmHalo.inkLine : SwarmActivationRole.connected.stroke, lineWidth: SwarmStroke.standard)
          )
      }
      .buttonStyle(.plain)
      .disabled(disabled)
    }
    .padding(12)
    .swarmSurface(.panel, in: RoundedRectangle(cornerRadius: HaloVisual.Auth.panelRadius, style: .continuous), activation: .connected)
  }

  private var canSubmitEmail: Bool {
    !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  // MARK: - actions

  private func handleApple(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .failure(let e):
      let description = e.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
      errorMessage = description.isEmpty ? "Accesso Apple annullato o non riuscito." : description
    case .success(let auth):
      isWorking = true
      let nonce = appleNonce
      Task {
        defer { isWorking = false }
        do {
          let profile = try await AuthService.shared.signInWithApple(authorization: auth, nonce: nonce)
          onSignedIn(profile)
        } catch {
          errorMessage = "Sign in fallito. Riprova."
        }
      }
    }
  }

  private func signInWithEmail() async {
    guard canSubmitEmail else {
      errorMessage = "Inserisci email e password per continuare."
      return
    }
    isWorking = true; defer { isWorking = false }
    do {
      let profile = try await AuthService.shared.signInWithEmail(
        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password
      )
      onSignedIn(profile)
      errorMessage = nil
    } catch {
      errorMessage = message(for: error)
    }
  }

  private func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
    let nonce = randomNonce()
    appleNonce = nonce
    request.requestedScopes = [.fullName, .email]
    request.nonce = sha256(nonce)
  }

  private func randomNonce(length: Int = 32) -> String {
    precondition(length > 0)
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    result.reserveCapacity(length)

    while result.count < length {
      var bytes = [UInt8](repeating: 0, count: 16)
      let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
      guard status == errSecSuccess else {
        fatalError("Impossibile generare un nonce sicuro.")
      }

      for byte in bytes {
        if result.count == length { break }
        if byte < charset.count {
          result.append(charset[Int(byte)])
        }
      }
    }

    return result
  }

  private func sha256(_ input: String) -> String {
    let digest = SHA256.hash(data: Data(input.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private func message(for error: Error) -> String {
    if let error = error as? AuthService.EmailSignInError,
       let description = error.errorDescription {
      return description
    }
    let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    return description.isEmpty ? "Non riesco ad accedere. Riprova." : description
  }
}
