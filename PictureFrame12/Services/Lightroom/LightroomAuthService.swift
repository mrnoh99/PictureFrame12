import Foundation
import UIKit
import AuthenticationServices

/// iOS 12 compatible Lightroom OAuth service.
/// Replaces: @MainActor, @Published, async/await, CryptoKit, connectedScenes
final class LightroomAuthService: NSObject {
    private(set) var isAuthenticated: Bool = false {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .lightroomAuthChanged, object: self)
            }
        }
    }
    private(set) var lastError: String?

    private var accessToken: String?
    private var accessTokenExpiry: Date?
    private var refreshToken: String? {
        get { KeychainStore.get("lightroom_refresh_token") }
        set { KeychainStore.set(newValue, for: "lightroom_refresh_token") }
    }

    private var webAuthSession: ASWebAuthenticationSession?
    private var pkceVerifier: String?
    private var pendingSignInCompletion: ((Error?) -> Void)?

    override init() {
        super.init()
        isAuthenticated = refreshToken != nil
    }

    // MARK: - Sign In / Out

    func signIn(completion: @escaping (Error?) -> Void) {
        guard AppConfig.Lightroom.isConfigured else {
            completion(PhotoProviderError.notConfigured); return
        }
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        pkceVerifier = verifier
        pendingSignInCompletion = completion

        guard var components = URLComponents(string: AppConfig.Lightroom.authorizeURL) else {
            completion(PhotoProviderError.server("잘못된 인증 URL")); return
        }
        components.queryItems = [
            .init(name: "client_id", value: AppConfig.Lightroom.clientID),
            .init(name: "scope", value: AppConfig.Lightroom.scopes),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: AppConfig.Lightroom.redirectURI),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = components.url else {
            completion(PhotoProviderError.server("잘못된 인증 URL")); return
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: AppConfig.Lightroom.callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            if let error = error {
                if let asError = error as? ASWebAuthenticationSessionError,
                   asError.code == .canceledLogin {
                    self.finishSignIn(error: nil)
                } else {
                    self.finishSignIn(error: error)
                }
                return
            }
            if let callbackURL = callbackURL { self.exchangeCode(from: callbackURL) }
        }
        if #available(iOS 13.0, *) {
            session.presentationContextProvider = self
        }
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        session.start()
    }

    func signOut() {
        accessToken = nil; accessTokenExpiry = nil; refreshToken = nil; isAuthenticated = false
    }

    func handleRedirect(url: URL) {
        guard url.scheme == AppConfig.Lightroom.callbackScheme else { return }
        exchangeCode(from: url)
    }

    // MARK: - Token Exchange

    private func exchangeCode(from callbackURL: URL) {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            finishSignIn(error: PhotoProviderError.server("인증 코드를 찾을 수 없습니다."))
            return
        }
        var params = [
            "grant_type": "authorization_code",
            "client_id": AppConfig.Lightroom.clientID,
            "code": code,
            "redirect_uri": AppConfig.Lightroom.redirectURI
        ]
        if let verifier = pkceVerifier { params["code_verifier"] = verifier }
        requestToken(params: params) { [weak self] error in
            self?.finishSignIn(error: error)
        }
    }

    func validAccessToken(completion: @escaping (String?, Error?) -> Void) {
        if let token = accessToken, let expiry = accessTokenExpiry, expiry > Date().addingTimeInterval(60) {
            completion(token, nil); return
        }
        guard let refresh = refreshToken else { completion(nil, PhotoProviderError.notAuthenticated); return }
        requestToken(params: [
            "grant_type": "refresh_token",
            "client_id": AppConfig.Lightroom.clientID,
            "refresh_token": refresh
        ]) { [weak self] error in
            guard let self = self else { return }
            if let error = error { completion(nil, error) }
            else { completion(self.accessToken, nil) }
        }
    }

    private func requestToken(params: [String: String], completion: @escaping (Error?) -> Void) {
        guard let tokenURL = URL(string: AppConfig.Lightroom.tokenURL) else {
            completion(PhotoProviderError.server("잘못된 토큰 URL")); return
        }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error { DispatchQueue.main.async { completion(error) }; return }
            guard let data = data,
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                DispatchQueue.main.async { completion(PhotoProviderError.server("토큰 요청 실패 (\(body))")) }; return
            }
            guard let token = try? JSONDecoder().decode(LightroomTokenResponse.self, from: data) else {
                DispatchQueue.main.async { completion(PhotoProviderError.server("응답 디코딩 실패")) }; return
            }
            self.accessToken = token.accessToken
            self.accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
            if let newRefresh = token.refreshToken { self.refreshToken = newRefresh }
            self.isAuthenticated = true
            DispatchQueue.main.async { completion(nil) }
        }.resume()
    }

    private func finishSignIn(error: Error?) {
        if error == nil { lastError = nil } else { lastError = error?.localizedDescription }
        pendingSignInCompletion?(error)
        pendingSignInCompletion = nil
        webAuthSession = nil
        pkceVerifier = nil
    }

    // MARK: - PKCE (CommonCrypto)

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest) }
        return Data(digest).base64URLEncoded()
    }
}

// MARK: - Presentation context (iOS 13+, no-op on iOS 12)
@available(iOS 13.0, *)
extension LightroomAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - Token response model
private struct LightroomTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - Helpers
extension Notification.Name {
    static let lightroomAuthChanged = Notification.Name("lightroomAuthChanged")
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var s = CharacterSet.urlQueryAllowed; s.remove(charactersIn: "+&=?"); return s
    }()
}
