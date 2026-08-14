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
        SwarmLoadingState(label: "auth")
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
      .signInWithAppleButtonStyle(.black)
      .frame(height: 52)

      Button {
        showEmail.toggle()
      } label: {
        Text(showEmail ? "nascondi email" : "entra con email")
          .foregroundStyle(HaloInk.creamMute)
          .font(HaloType.ui(14, weight: .medium))
          .swarmChip()
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
    VStack(spacing: 10) {
      TextField("la tua email", text: $email)
        .textFieldStyle(.plain)
        .font(HaloType.ui(15, weight: .regular))
        .foregroundStyle(HaloInk.cream)
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .padding(.horizontal, 14).padding(.vertical, 12)
        .swarmSurface(.control, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous))

      SecureField("password", text: $password)
        .textFieldStyle(.plain)
        .font(HaloType.ui(15, weight: .regular))
        .foregroundStyle(HaloInk.cream)
        .textContentType(.password)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .swarmSurface(.control, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous))

      Button {
        Task { await signInWithEmail() }
      } label: {
        Text("entra")
          .font(HaloType.ui(15, weight: .semibold))
          .foregroundStyle(HaloInk.cream)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .swarmSurface(.control, in: RoundedRectangle(cornerRadius: SwarmHalo.radiusInput, style: .continuous), activation: .connected)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - actions

  private func handleApple(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .failure(let e):
      errorMessage = e.localizedDescription
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
    isWorking = true; defer { isWorking = false }
    do {
      let profile = try await AuthService.shared.signInWithEmail(email: email, password: password)
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
