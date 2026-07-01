import Foundation

/// 앱 전역 설정 및 외부 서비스 연동에 필요한 상수 모음.
enum AppConfig {

    enum Lightroom {
        static let clientID = "107a55d89a31478c84f2f0f313a4ab22"
        static let redirectURI = "adobe+fea1fa140a9c3f2ceeff3aeff353ce1efda56c0d://adobeid/107a55d89a31478c84f2f0f313a4ab22"
        static let callbackScheme = "adobe+fea1fa140a9c3f2ceeff3aeff353ce1efda56c0d"
        static let authorizeURL = "https://ims-na1.adobelogin.com/ims/authorize/v2"
        static let tokenURL = "https://ims-na1.adobelogin.com/ims/token/v3"
        static let apiBaseURL = "https://lr.adobe.io/v2"
        static let scopes = "openid,AdobeID,lr_partner_apis,lr_partner_rendition_apis,offline_access"

        static var isConfigured: Bool {
            !clientID.isEmpty && clientID != "YOUR_ADOBE_CLIENT_ID"
        }

        static let partnerApprovalPending = true
    }

    static let defaultSlideInterval: TimeInterval = 8
}
