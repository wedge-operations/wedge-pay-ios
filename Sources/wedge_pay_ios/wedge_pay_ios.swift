import SwiftUI
import WebKit
import UIKit
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

public let WEDGE_PAY_IOS_VERSION = "1.2.0"

private let environments: [String: String] = [
    "development": "http://localhost:3000",
    "integration": "https://onboarding-integration.wedge-can.com",
    "sandbox": "https://onboarding-sandbox.wedge-can.com",
    "production": "https://onboarding-production.wedge-can.com"
]

#if os(iOS) && canImport(AuthenticationServices)
@available(iOS 12.0, *)
final class HostedLinkCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private weak var webView: WKWebView?
    private let callbackScheme: String

    init(webView: WKWebView, callbackScheme: String) {
        self.webView = webView
        self.callbackScheme = callbackScheme
    }

    func open(hostedLinkURL: URL) {
        guard session == nil else { return }

        let authSession = ASWebAuthenticationSession(
            url: hostedLinkURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, _ in
            guard let self else { return }

            if let callbackURL {
                self.notifyWeb(status: "success", callbackURL: callbackURL.absoluteString)
            } else {
                self.notifyWeb(status: "cancel", callbackURL: nil)
            }

            self.session = nil
        }

        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = false

        session = authSession
        authSession.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    private func notifyWeb(status: String, callbackURL: String?) {
        guard let webView else { return }

        let js: String
        if let callbackURL {
            let escaped = callbackURL
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            js = """
            (function() {
              if (window.__hostedLinkComplete) {
                window.__hostedLinkComplete({ status: "\(status)", callbackUrl: "\(escaped)" });
              }
            })();
            """
        } else {
            js = """
            (function() {
              if (window.__hostedLinkComplete) {
                window.__hostedLinkComplete({ status: "\(status)" });
              }
            })();
            """
        }

        DispatchQueue.main.async {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
#endif

#if os(iOS)
@available(iOS 14.0, *)
public struct WedgePayIOS: UIViewRepresentable {
    public var token: String
    public var env: String
    public var type: String
    public var hostedLinkRedirectUri: String?

    public var onEvent: (Any) -> Void
    public var onSuccess: (String) -> Void
    public var onClose: (Any) -> Void
    public var onLoad: (Any) -> Void
    public var onError: (Any) -> Void

    public init(
        token: String,
        env: String,
        type: String = "onboarding",
        hostedLinkRedirectUri: String? = nil,
        onEvent: @escaping (Any) -> Void,
        onSuccess: @escaping (String) -> Void,
        onClose: @escaping (Any) -> Void,
        onLoad: @escaping (Any) -> Void,
        onError: @escaping (Any) -> Void
    ) {
        self.token = token
        self.env = env
        self.type = type
        self.hostedLinkRedirectUri = hostedLinkRedirectUri
        self.onEvent = onEvent
        self.onSuccess = onSuccess
        self.onClose = onClose
        self.onLoad = onLoad
        self.onError = onError

        precondition(URL(string: resolvedHostedLinkRedirectUri)?.scheme != nil,
                     "hostedLinkRedirectUri must include a valid URL scheme.")
    }

    private var resolvedHostedLinkRedirectUri: String {
        let explicit = hostedLinkRedirectUri?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicit, !explicit.isEmpty { return explicit }

        if let configuredScheme = Bundle.main.firstConfiguredURLScheme, !configuredScheme.isEmpty {
            return "\(configuredScheme)://plaid-complete"
        }

        if let bundleIdentifier = Bundle.main.bundleIdentifier, !bundleIdentifier.isEmpty {
            return "\(bundleIdentifier)://plaid-complete"
        }

        return "wedge.WedgeExample://plaid-complete"
    }

    private var hostedLinkCallbackScheme: String? {
        URL(string: resolvedHostedLinkRedirectUri)?.scheme
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true

        registerBridgeScripts(on: webView)
        registerMessageHandlers(on: webView, coordinator: context.coordinator)

        context.coordinator.webView = webView
        if let scheme = hostedLinkCallbackScheme, #available(iOS 12.0, *) {
            context.coordinator.hostedLinkCoordinator = HostedLinkCoordinator(
                webView: webView,
                callbackScheme: scheme
            )
        }

        guard let baseURL = environments[env], var components = URLComponents(string: baseURL) else {
            let fallback = environments["sandbox"]!
            var fallbackComponents = URLComponents(string: fallback)!
            fallbackComponents.queryItems = queryItems()
            if let url = fallbackComponents.url {
                webView.load(URLRequest(url: url))
            }
            return webView
        }

        components.queryItems = queryItems()
        if let url = components.url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(wrapper: self)
    }

    private func queryItems() -> [URLQueryItem] {
        [
            URLQueryItem(name: "onboardingToken", value: token),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "hostedLinkRedirectUri", value: resolvedHostedLinkRedirectUri),
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "supportsHostedLink", value: "true")
        ]
    }

    private func registerBridgeScripts(on webView: WKWebView) {
        let safeRedirect = resolvedHostedLinkRedirectUri
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        (function() {
          var redirectUri = "\(safeRedirect)";
          var config = {
            hostedLinkRedirectUri: redirectUri,
            platform: 'ios',
            supportsHostedLink: true
          };
          var bridge = {
            getHostedLinkRedirectUri: function() { return redirectUri; },
            hostedLinkRedirectUri: redirectUri,
            platform: 'ios',
            supportsHostedLink: true
          };

          window.WedgeSDKIOS = bridge;

          var configApplied = false;
          var attempts = 0;
          var maxAttempts = 40;
          var retryDelayMs = 50;

          function applyConfig() {
            if (configApplied) return;
            if (window.WedgeSDK && typeof window.WedgeSDK.setConfig === 'function') {
              window.WedgeSDK.setConfig(config);
              configApplied = true;
              return;
            }
            attempts += 1;
            if (attempts < maxAttempts) {
              setTimeout(applyConfig, retryDelayMs);
            }
          }

          applyConfig();

          window.dispatchEvent(new CustomEvent('iOSReady', {
            detail: {
              hostedLinkRedirectUri: redirectUri,
              platform: 'ios',
              supportsHostedLink: true
            }
          }));
        })();
        """

        webView.configuration.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
    }

    private func registerMessageHandlers(on webView: WKWebView, coordinator: Coordinator) {
        let ucc = webView.configuration.userContentController
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        ucc.add(coordinator, name: "onClose")
        ucc.add(coordinator, name: "onEvent")
        ucc.add(coordinator, name: "onError")
        ucc.add(coordinator, name: "onSuccess")
        ucc.add(coordinator, name: "openHostedLink")
    }

    public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        var wrapper: WedgePayIOS
        weak var webView: WKWebView?
        var hostedLinkCoordinator: HostedLinkCoordinator?

        init(wrapper: WedgePayIOS) {
            self.wrapper = wrapper
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "onError":
                wrapper.onError(message.body)
                wrapper.onClose("error_exit")

            case "onEvent":
                wrapper.onEvent(message.body)

            case "onSuccess":
                if let body = message.body as? String {
                    wrapper.onSuccess(body)
                } else {
                    wrapper.onSuccess("\(message.body)")
                }

            case "onClose":
                wrapper.onClose("Closed")

            case "openHostedLink":
                handleOpenHostedLink(message.body)

            default:
                break
            }
        }

        private func handleOpenHostedLink(_ body: Any) {
            guard let hostedLinkCoordinator else { return }

            let urlString: String?
            if let dict = body as? [String: Any] {
                urlString = dict["url"] as? String
            } else if let str = body as? String {
                urlString = str
            } else {
                urlString = nil
            }

            guard let raw = urlString, let url = URL(string: raw), !raw.isEmpty else { return }
            hostedLinkCoordinator.open(hostedLinkURL: url)
        }

        public func webView(_ webView: WKWebView,
                            decidePolicyFor navigationAction: WKNavigationAction,
                            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let scheme = wrapper.hostedLinkCallbackScheme,
               url.scheme?.lowercased() == scheme.lowercased() {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView,
                            createWebViewWith configuration: WKWebViewConfiguration,
                            for navigationAction: WKNavigationAction,
                            windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url else {
                return nil
            }

            let scheme = (url.scheme ?? "").lowercased()
            if scheme == "tel" || scheme == "mailto" {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return nil
            }

            webView.load(URLRequest(url: url))
            return nil
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            wrapper.onLoad(url.absoluteString)
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            wrapper.onError("Navigation failed: \(error.localizedDescription)")
            wrapper.onClose("navigation_error")
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            wrapper.onError("Provisional navigation failed: \(error.localizedDescription)")
            wrapper.onClose("provisional_navigation_error")
        }
    }
}
#endif

private extension Bundle {
    var firstConfiguredURLScheme: String? {
        guard let urlTypes = object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }

        for urlType in urlTypes {
            if let schemes = urlType["CFBundleURLSchemes"] as? [String],
               let first = schemes.first,
               !first.isEmpty {
                return first
            }
        }

        return nil
    }
}