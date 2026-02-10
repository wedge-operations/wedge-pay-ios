import SwiftUI
import WebKit
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

// SDK Version
public let WEDGE_PAY_IOS_VERSION = "1.1.0"

var environments = [
    "development": "http://localhost:3000",
    "integration": "https://onboarding-integration.wedge-can.com",
    "sandbox": "https://onboarding-sandbox.wedge-can.com",
    "production": "https://onboarding-production.wedge-can.com"
]

#if os(iOS) && canImport(AuthenticationServices)
/// Coordinates opening Plaid Hosted Link in ASWebAuthenticationSession and notifying the Web SDK on completion.
/// The session is strongly retained until completion to prevent early deallocation.
@available(iOS 12.0, *)
final class PlaidHostedLinkCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private weak var webView: WKWebView?
    private let callbackScheme: String

    init(webView: WKWebView, callbackScheme: String) {
        self.webView = webView
        self.callbackScheme = callbackScheme
    }

    /// Opens the Hosted Link URL in ASWebAuthenticationSession. Ignores concurrent calls while a session is active.
    func open(hostedLinkURL: URL) {
        guard session == nil else { return }

        let s = ASWebAuthenticationSession(
            url: hostedLinkURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            // Helpful debugging during integration
            // print("ASWebAuthenticationSession finished callbackURL:", callbackURL?.absoluteString ?? "nil",
            //       "error:", error?.localizedDescription ?? "nil")

            if let callbackURL = callbackURL {
                self.notifyWeb(status: "success", callbackURL: callbackURL)
            } else {
                self.notifyWeb(status: "cancel", callbackURL: nil)
            }
            self.session = nil
        }

        s.presentationContextProvider = self
        s.prefersEphemeralWebBrowserSession = false

        session = s
        s.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    private func notifyWeb(status: String, callbackURL: URL?) {
        guard let webView = webView else { return }

        let callback = callbackURL?.absoluteString ?? ""
        let safeCallback = callback
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let js = """
        (function() {
            if (window.__plaidHostedLinkComplete) {
                window.__plaidHostedLinkComplete({
                    status: "\(status)",
                    callbackUrl: "\(safeCallback)"
                });
            }
        })();
        """

        DispatchQueue.main.async {
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
#endif

#if os(iOS)
@available(iOS 14.0, *)
public struct WedgePayIOS: UIViewRepresentable {
    var token: String
    var env: String
    var type: String
    /// Callback URL scheme for Plaid Hosted Link (e.g. completion_redirect_uri "myapp://complete").
    /// If nil, the app's **bundle identifier** is used (e.g. "com.yourapp.id" → "com.yourapp.id://complete").
    var plaidCallbackScheme: String?

    /// Scheme used for Plaid: plaidCallbackScheme if set, otherwise the app's bundle identifier.
    var effectivePlaidCallbackScheme: String? {
        if let s = plaidCallbackScheme, !s.isEmpty { return s }
        return Bundle.main.bundleIdentifier
    }
    var onEvent: (Any) -> ()
    var onSuccess: (String) -> ()
    var onClose: (Any) -> ()
    var onLoad: (Any) -> ()
    var onError: (Any) -> ()

    public init(
        token: String,
        env: String,
        type: String = "onboarding",
        plaidCallbackScheme: String? = nil,
        onEvent: @escaping (Any) -> Void,
        onSuccess: @escaping (String) -> Void,
        onClose: @escaping (Any) -> Void,
        onLoad: @escaping (Any) -> Void,
        onError: @escaping (Any) -> Void
    ) {
        self.token = token
        self.env = env
        self.type = type
        self.plaidCallbackScheme = plaidCallbackScheme
        self.onEvent = onEvent
        self.onSuccess = onSuccess
        self.onClose = onClose
        self.onLoad = onLoad
        self.onError = onError
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Configure WebView preferences for iOS 14+
        if #available(iOS 14.0, *) {
            let prefs = WKWebpagePreferences()
            prefs.allowsContentJavaScript = true
            config.defaultWebpagePreferences = prefs
        } else {
            config.preferences.javaScriptEnabled = true
        }

        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = true
        webView.scrollView.bounces = true
        webView.scrollView.maximumZoomScale = 3.0
        webView.scrollView.minimumZoomScale = 0.5
        webView.isUserInteractionEnabled = true

        // Capture console.log output and send to iOS (optional)
        let source = """
        (function() {
            function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); }
            window.console.log = captureLog;
        })();
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)

        // Register bridge handlers
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let coordinator = context.coordinator
        webView.configuration.userContentController.add(coordinator, name: "onClose")
        webView.configuration.userContentController.add(coordinator, name: "logHandler")
        webView.configuration.userContentController.add(coordinator, name: "onEvent")
        webView.configuration.userContentController.add(coordinator, name: "onError")
        webView.configuration.userContentController.add(coordinator, name: "onSuccess")
        webView.configuration.userContentController.add(coordinator, name: "openPlaidHostedLink")

        coordinator.webView = webView
        if let scheme = effectivePlaidCallbackScheme, #available(iOS 12.0, *) {
            coordinator.plaidHostedLinkCoordinator = PlaidHostedLinkCoordinator(webView: webView, callbackScheme: scheme)
        }

        // Build initial URL and optional plaidCompletionRedirectUri for webapp config
        let completionRedirectUri = effectivePlaidCallbackScheme.map { "\($0)://complete" } ?? ""

        guard let baseUrlString = environments[env] else {
            print("Error: Environment '\(env)' not found. Available environments: \(environments.keys.joined(separator: ", "))")

            let fallbackUrl = environments["sandbox"]!
            if var components = URLComponents(string: fallbackUrl) {
                var items = [
                    URLQueryItem(name: "onboardingToken", value: token),
                    URLQueryItem(name: "type", value: type)
                ]
                if !completionRedirectUri.isEmpty {
                    items.append(URLQueryItem(name: "plaidCompletionRedirectUri", value: completionRedirectUri))
                }
                components.queryItems = items
                if let url = components.url {
                    webView.load(URLRequest(url: url))
                }
            }
            return webView
        }

        guard var components = URLComponents(string: baseUrlString) else {
            print("Error: Invalid base URL for environment '\(env)'")
            return webView
        }

        var queryItems = [
            URLQueryItem(name: "onboardingToken", value: token),
            URLQueryItem(name: "type", value: type)
        ]
        if !completionRedirectUri.isEmpty {
            queryItems.append(URLQueryItem(name: "plaidCompletionRedirectUri", value: completionRedirectUri))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            print("Error: Failed to build URL with token and type")
            return webView
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(wrapper: self)
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {

        var wrapper: WedgePayIOS
        weak var webView: WKWebView?
        var plaidHostedLinkCoordinator: PlaidHostedLinkCoordinator?

        init(wrapper: WedgePayIOS) {
            self.wrapper = wrapper
        }

        // MARK: - JS Bridge

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

            case "openPlaidHostedLink":
                handleOpenPlaidHostedLink(message.body)

            case "logHandler":
                // Optional: forward logs for debugging
                // print("WEB:", message.body)
                break

            default:
                break
            }
        }

        private func handleOpenPlaidHostedLink(_ body: Any) {
            guard let coordinator = plaidHostedLinkCoordinator else {
                // print("openPlaidHostedLink received but plaidHostedLinkCoordinator is nil. Did you set plaidCallbackScheme?")
                return
            }

            let urlString: String?
            if let dict = body as? [String: Any] {
                urlString = dict["url"] as? String
            } else if let str = body as? String {
                urlString = str
            } else {
                urlString = nil
            }

            guard let urlString = urlString, !urlString.isEmpty, let url = URL(string: urlString) else { return }
            coordinator.open(hostedLinkURL: url)
        }

        // MARK: - Navigation Policy

        /// IMPORTANT:
        /// If the Plaid completion redirect (custom scheme) ever attempts to load in WKWebView, cancel it.
        /// The completion should be intercepted by ASWebAuthenticationSession instead.
        public func webView(_ webView: WKWebView,
                            decidePolicyFor navigationAction: WKNavigationAction,
                            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            if let url = navigationAction.request.url,
               let scheme = wrapper.effectivePlaidCallbackScheme,
               url.scheme?.lowercased() == scheme.lowercased() {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView,
                            decidePolicyFor navigationResponse: WKNavigationResponse,
                            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(.allow)
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }

            wrapper.onLoad("\(url)")

            let triggerEventScript = """
            (function() {
                var event = new CustomEvent('iOSReady', { detail: 'iOS Ready' });
                window.dispatchEvent(event);
            })();
            """
            webView.evaluateJavaScript(triggerEventScript) { (_, error) in
                if let error = error {
                    print("Error triggering event: \(error)")
                }
            }
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
            wrapper.onError("Navigation failed: \(error.localizedDescription)")
            wrapper.onClose("navigation_error")
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
            wrapper.onError("Provisional navigation failed: \(error.localizedDescription)")
            wrapper.onClose("provisional_navigation_error")
        }

        // MARK: - target=_blank / window.open handling

        /// IMPORTANT CHANGE:
        /// Do NOT punt target=_blank links to Safari. Keep them in the same WKWebView.
        /// This avoids breaking Hosted Link/OAuth flows and avoids Safari "invalid address" screens.
        public func webView(_ webView: WKWebView,
                            createWebViewWith configuration: WKWebViewConfiguration,
                            for navigationAction: WKNavigationAction,
                            windowFeatures: WKWindowFeatures) -> WKWebView? {

            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url else {
                return nil
            }

            // Allow certain schemes to open externally
            let scheme = (url.scheme ?? "").lowercased()
            if scheme == "tel" || scheme == "mailto" {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return nil
            }

            // Otherwise, load inside the same WKWebView
            webView.load(URLRequest(url: url))
            return nil
        }
    }
}
#endif
