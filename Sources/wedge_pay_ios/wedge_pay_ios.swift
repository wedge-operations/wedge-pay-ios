import SwiftUI
import WebKit

// SDK Version
public let WEDGE_PAY_IOS_VERSION = "1.0.0"

var environments = ["integration": "https://onboarding-integration.wedge-can.com",
                    "sandbox": "https://onboarding-sandbox.wedge-can.com",
                    "production": "https://onboarding-production.wedge-can.com"]

#if os(iOS)
@available(iOS 14.0, *)
public struct WedgePayIOS: UIViewRepresentable {
    var token: String
    var env: String
    var onEvent: (Any) -> ()
    var onSuccess: (String) -> ()
    var onClose: (Any) -> ()
    var onLoad: (Any) -> ()
    var onError: (Any) -> ()
    
    public init(token: String, env: String, onEvent: @escaping (Any) -> Void, onSuccess: @escaping (String) -> Void, onClose: @escaping (Any) -> Void, onLoad: @escaping (Any) -> Void, onError: @escaping (Any) -> Void) {
        self.token = token
        self.env = env
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
        
        // Configure WebView to reduce constraint conflicts
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Disable autoresizing mask to prevent constraint conflicts
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure WebView appearance for page-based navigation
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // Show scroll indicators for better UX in page navigation
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.scrollView.showsHorizontalScrollIndicator = true
        webView.scrollView.bounces = true
        
        // Allow zoom for better accessibility
        webView.scrollView.maximumZoomScale = 3.0
        webView.scrollView.minimumZoomScale = 0.5
        
        // inject JS to capture console.log output and send to iOS
        let source = "function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); } window.console.log = captureLog;"
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        
        // register the bridge script that listens for the output
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView.configuration.userContentController.add(Coordinator(wrapper: self), name: "onClose")
        webView.configuration.userContentController.add(Coordinator(wrapper: self), name: "logHandler")
        webView.configuration.userContentController.add(Coordinator(wrapper: self), name: "onEvent")
        webView.configuration.userContentController.add(Coordinator(wrapper: self), name: "onError")
        webView.configuration.userContentController.add(Coordinator(wrapper: self), name: "onSuccess")

        context.coordinator.webView = webView

        // Configure gesture handling for page-based navigation
        // Note: Back/forward gestures are handled by the WebView's built-in navigation
        webView.isUserInteractionEnabled = true

        guard let environmentUrl = environments[env] else {
            print("Error: Environment '\(env)' not found. Available environments: \(environments.keys.joined(separator: ", "))")
            // Fallback to sandbox if environment is invalid
            let fallbackUrl = environments["sandbox"]!
            let url = URL(string: "\(fallbackUrl)?onboardingToken=\(token)")
            let request = URLRequest(url: url!)
            webView.load(request)
            return webView
        }
        
        let url = URL(string: "\(environmentUrl)?onboardingToken=\(token)")

        let request = URLRequest(url: url!)
        webView.load(request)
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // No modal-specific updates needed for page-based navigation
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(wrapper: self)
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        
        var wrapper: WedgePayIOS
        var webView: WKWebView?
        
        init(wrapper: WedgePayIOS) {
            self.wrapper = wrapper
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
                case "onError":
                    wrapper.onError(message.body)
                    // Automatically trigger onClose when an error occurs to allow SDK exit
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
                default:
                    break
            }
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(.allow)
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            
            wrapper.onLoad("\(url)")
            
            let triggerEventScript = """
                var event = new CustomEvent('iOSReady', { detail: 'iOS Ready' });
                window.dispatchEvent(event);
            """
            webView.evaluateJavaScript(triggerEventScript) { (result, error) in
                if let error = error {
                    print("Error triggering event: \(error)")
                } else {
                    print("Event triggered successfully")
                }
            }
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
            wrapper.onError("Navigation failed: \(error.localizedDescription)")
            // Allow SDK exit on navigation failure
            wrapper.onClose("navigation_error")
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
            wrapper.onError("Provisional navigation failed: \(error.localizedDescription)")
            // Allow SDK exit on provisional navigation failure
            wrapper.onClose("provisional_navigation_error")
        }
        
        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                if navigationAction.targetFrame == nil {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
            return nil
        }
    }
}
#endif 