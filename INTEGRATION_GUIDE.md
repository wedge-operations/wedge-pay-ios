# Wedge Pay iOS SDK Integration Guide

## Overview

The Wedge Pay iOS SDK now supports a `type` parameter that determines the behavior and flow of the onboarding experience. This enhancement allows developers to provide different user experiences based on whether the user is new to the platform or an existing user who needs to add funding sources.

## Prerequisites

- iOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- An onboarding token from Wedge

## Installation

### Swift Package Manager (Recommended)

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter the repository URL: `https://github.com/wedge-operations/wedge-pay-ios.git`
3. Select the version you want to use (recommended: latest stable version)
4. Click **Add Package**

### Manual Installation

1. Clone the repository: `git clone https://github.com/wedge-operations/wedge-pay-ios.git`
2. Drag the `Sources/wedge_pay_ios` folder into your Xcode project
3. Ensure the files are added to your target

### Available Types

- **`"onboarding"`** (default): Complete onboarding flow for new users
  - Full identity verification
  - Account setup and configuration
  - Complete onboarding experience
- **`"funding"`**: Streamlined flow for existing users
  - Focused on adding payment methods
  - Funding source management
  - Relink funding accounts

### Behavior Changes

| Type | User Experience | Flow Focus | Use Case |
|------|----------------|------------|----------|
| `onboarding` | Complete setup | Full onboarding | New users, first-time setup |
| `funding` | Streamlined | Payment methods | Existing users, add funding |

### URL Construction

The SDK automatically appends the type parameter to the webapp URL:

```
https://{environment}.wedge-can.com?onboardingToken={token}&type={type}
```

**Examples:**
- Onboarding: `https://sandbox.wedge-can.com?onboardingToken=abc123&type=onboarding`
- Funding: `https://sandbox.wedge-can.com?onboardingToken=abc123&type=funding`

## Implementation

### Swift SDK Integration

#### Basic Usage

```swift
import SwiftUI
import WedgePayIOS

// For new user onboarding
WedgePayIOS(
    token: "your-onboarding-token",
    env: "sandbox",
    type: "onboarding", // Full onboarding flow
    onEvent: { event in
        print("Event: \(event)")
    },
    onSuccess: { customerId in
        print("Onboarding completed: \(customerId)")
    },
    onClose: { _ in
        print("User closed onboarding")
    },
    onLoad: { url in
        print("Webapp loaded: \(url)")
    },
    onError: { error in
        print("Error: \(error)")
    }
)

// For existing users adding funding
WedgePayIOS(
    token: "your-onboarding-token",
    env: "sandbox",
    type: "funding", // Funding-focused flow
    onEvent: { event in
        print("Event: \(event)")
    },
    onSuccess: { customerId in
        print("Funding setup completed: \(customerId)")
    },
    onClose: { _ in
        print("User closed funding setup")
    },
    onLoad: { url in
        print("Webapp loaded: \(url)")
    },
    onError: { error in
        print("Error: \(error)")
    }
)
```

#### Dynamic Type Selection

```swift
struct ContentView: View {
    @State private var userType: String = "onboarding"
    @State private var showingOnboarding = false
    
    var body: some View {
        VStack {
            // Type selection
            Picker("Flow Type", selection: $userType) {
                Text("New User").tag("onboarding")
                Text("Existing User").tag("funding")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("Start \(userType.capitalized)") {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            WedgePayIOS(
                token: "your-token",
                env: "sandbox",
                type: userType, // Dynamic type selection
                onEvent: { event in
                    print("Event: \(event)")
                },
                onSuccess: { customerId in
                    print("Success: \(customerId)")
                    showingOnboarding = false
                },
                onClose: { _ in
                    showingOnboarding = false
                },
                onLoad: { url in
                    print("Loaded: \(url)")
                },
                onError: { error in
                    print("Error: \(error)")
                    showingOnboarding = false
                }
            )
        }
    }
}
```

## Plaid Hosted Link (ASWebAuthenticationSession)

When the Web SDK receives a `hosted_link_url` from the backend, the iOS wrapper opens it using **ASWebAuthenticationSession** (not inside the WKWebView). This avoids OAuth return URLs being handled inside the SPA and causing 404s.

### Required iOS configuration

1. **Callback scheme** — Use your **app’s bundle identifier** as the Plaid completion redirect (recommended). If you omit `completionRedirectUri`, the SDK uses `Bundle.main.bundleIdentifier` (e.g. `com.yourapp.id` → `com.yourapp.id://plaid-link-complete`). Your backend should set `completion_redirect_uri` for mobile to that (e.g. `com.yourapp.id://plaid-link-complete`). You can override by passing `completionRedirectUri: "custom-scheme"` if needed.

2. **Register the URL scheme** in the app target (**Info → URL Types**). The scheme must match what the backend uses (your bundle ID when using the default, or your custom scheme). Example for bundle ID `com.yourapp.id`:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.yourapp.id</string>
           </array>
           <key>CFBundleURLName</key>
           <string>Plaid Hosted Link callback</string>
           <key>CFBundleTypeRole</key>
           <string>Editor</string>
       </dict>
   </array>
   ```

### Usage

```swift
WedgePayIOS(
    token: "your-token",
    env: "sandbox",
    type: "onboarding",
    // completionRedirectUri: omit to use the app's bundle ID (e.g. com.yourapp.id://complete)
    onEvent: { _ in },
    onSuccess: { _ in },
    onClose: { _ in },
    onLoad: { _ in },
    onError: { _ in }
)
```

### Plaid completion redirect URI – webapp config

The iOS SDK builds an app-specific redirect URI at runtime:
- If provided, uses `completionRedirectUri`.
- Otherwise uses the first URL scheme registered in `CFBundleURLTypes`.
- If unavailable, falls back to `Bundle.main.bundleIdentifier://plaid-link-complete`.

The SDK then provides the redirect URI to the web app through supported channels:

1. **Preferred (`setConfig`)** — Calls:
   `WedgeSDK.setConfig({ completionRedirectUri: "<uri>" })`
2. **Injected bridge object** — Sets both `window.WedgeSDKiOS` and `window.WedgeSDKIOS` with:
   - `getCompletionRedirectUri(): string`
   - `completionRedirectUri: string`
   - `plaidCompletionRedirectUri: string`
3. **URL query params** — Appends all accepted keys:
   - `completionRedirectUri`
   - `plaidCompletionRedirectUri`
   - `completion_redirect_uri`
   - `plaid_completion_redirect_uri`

Query values are URL-encoded by `URLComponents`.

### Bridge contract

- The Web SDK posts to the **`openHostedLink`** script message handler. The handler accepts either a **URL string** (`message.body` as the raw URL) or a **payload object** `{ url: "<hosted_link_url>" }` (or `{ type: "OPEN_HOSTED_LINK", url: "..." }`).
- The iOS SDK opens that URL in **ASWebAuthenticationSession** (with `callbackURLScheme` and a presentation context). The session is retained until the callback runs.
- When the provider redirects to your app (e.g. `myapp-plaid://complete?...`) or the user cancels, the iOS SDK calls **`window.__hostedLinkComplete(result)`** (no webview reload). Result:
  - `result.status`: `"success"` or `"cancel"`
  - `result.callbackUrl`: the redirect URL on success (optional string)
  - The SDK can also support sending a callback URL string containing a `status`/`result` query parameter if your web app consumes the string form.

The Web SDK is responsible for registering `window.__hostedLinkComplete` and refreshing backend state on success or showing cancel/error UI on cancel.

**How the SDK does it:** The SDK’s coordinator conforms to **WKScriptMessageHandler**, registers the **`openHostedLink`** handler when creating the WKWebView, and keeps a strong reference to the **ASWebAuthenticationSession** until the callback runs. It does **not** reload the webview after the provider redirects; it notifies the web app via `__hostedLinkComplete` so the web app can continue without a full page reload. If you implement your own view controller instead of using `WedgePayIOS`, you can either use the same callback contract or, after redirects, reload the webview with your current onboarding URL (the same base URL you load in the webview) so the web app can continue.

### Rules

- Do **not** open `hosted_link_url` inside the WKWebView.
- Always use **ASWebAuthenticationSession** for the Hosted Link URL.
- The session is retained until completion; concurrent `openHostedLink` calls are ignored while a session is active.

### Common issues

| Issue | Check |
|-------|--------|
| Callback never fires | Scheme in Info.plist and `completionRedirectUri` match backend `completion_redirect_uri`; session is not released early. |
| 404 / SPA reload | Hosted Link was opened in WKWebView; ensure only the native bridge opens it in ASWebAuthenticationSession. |
| Multiple sessions | SDK blocks concurrent Hosted Link opens; wait for completion before opening again. |

---

### API Reference

#### WedgePayIOS Initializer

```swift
public init(
    token: String,
    env: String,
    type: String = "onboarding",
    completionRedirectUri: String? = nil,
    onEvent: @escaping (Any) -> Void,
    onSuccess: @escaping (String) -> Void,
    onClose: @escaping (Any) -> Void,
    onLoad: @escaping (Any) -> Void,
    onError: @escaping (Any) -> Void
)
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `token` | String | Required | Your onboarding token |
| `env` | String | Required | Environment ("development", "integration", "sandbox", "production") |
| `type` | String | "onboarding" | Flow type ("onboarding" or "funding") |
| `completionRedirectUri` | String? | nil | If set, used as the full redirect URI. If nil, SDK derives it from app URL scheme (`CFBundleURLTypes`) and falls back to bundle identifier, then appends `://plaid-link-complete`. |
| `onEvent` | Closure | Required | General event handler |
| `onSuccess` | Closure | Required | Success completion handler |
| `onClose` | Closure | Required | Close/cancel handler |
| `onLoad` | Closure | Required | Webapp load handler |
| `onError` | Closure | Required | Error handler |

## Backward Compatibility

### Existing Code

**All existing implementations continue to work without changes.** The `type` parameter defaults to `"onboarding"`, maintaining the current behavior for existing code.

```swift
// This existing code continues to work exactly as before
WedgePayIOS(
    token: "your-token",
    env: "sandbox",
    // type defaults to "onboarding"
    onEvent: { event in ... },
    onSuccess: { customerId in ... },
    onClose: { _ in ... },
    onLoad: { url in ... },
    onError: { error in ... }
)
```

### Migration Path

#### For Existing SDKs

1. **No immediate action required** - existing code continues to work
2. **Optional enhancement** - add type parameter when ready
3. **Gradual rollout** - implement type selection based on user context

#### For New SDKs

1. **Implement type selection logic** - determine user context
2. **Add type parameter** - pass appropriate type value
3. **Test both flows** - ensure proper behavior for each type

## Testing

### Test URLs

Use these test URLs to verify the type parameter functionality:

#### Development Environment (local)
- Base URL: `http://localhost:3000` (same query format as other environments)
- Onboarding: `http://localhost:3000?onboardingToken=test&type=onboarding`
- Funding: `http://localhost:3000?onboardingToken=test&type=funding`

#### Integration Environment
- Onboarding: `https://onboarding-integration.wedge-can.com?onboardingToken=test&type=onboarding`
- Funding: `https://onboarding-integration.wedge-can.com?onboardingToken=test&type=funding`

#### Sandbox Environment
- Onboarding: `https://onboarding-sandbox.wedge-can.com?onboardingToken=test&type=onboarding`
- Funding: `https://onboarding-sandbox.wedge-can.com?onboardingToken=test&type=funding`

### Expected Behavior

| Test Case | Expected Result |
|-----------|-----------------|
| `type=onboarding` | Full onboarding flow |
| `type=funding` | Streamlined funding flow |
| Missing type parameter | Defaults to onboarding flow |
| Invalid type value | Falls back to onboarding flow |

## Error Handling

### Type Parameter Errors

- **Invalid type values**: Automatically fall back to `"onboarding"`
- **Missing type parameter**: Defaults to `"onboarding"`
- **Network errors**: Standard error handling applies

### Error Scenarios

```swift
onError: { error in
    if let errorString = error as? String {
        switch errorString {
        case let str where str.contains("type"):
            print("Type parameter error: \(str)")
        case let str where str.contains("network"):
            print("Network error: \(str)")
        default:
            print("General error: \(str)")
        }
    }
}
```

## Best Practices

### Type Selection Logic

```swift
func determineUserType(user: User) -> String {
    if user.hasCompletedOnboarding {
        return "funding"
    } else {
        return "onboarding"
    }
}

func determineUserTypeFromContext(context: OnboardingContext) -> String {
    switch context {
    case .newUser:
        return "onboarding"
    case .existingUser:
        return "funding"
    case .returningUser:
        return "funding"
    }
}
```

### User Experience

1. **Clear labeling**: Use descriptive text for type selection
2. **Context awareness**: Automatically select type based on user state
3. **Fallback handling**: Always provide a default experience
4. **User feedback**: Explain what each flow type means

### Performance Considerations

1. **Lazy loading**: Only load the appropriate flow type
2. **Caching**: Cache user type selection when appropriate
3. **Analytics**: Track which flow types are used most

## Version Information

- **SDK Version**: 1.2.0
- **Minimum iOS Version**: 14.0+
- **Swift Version**: 5.9+
- **Xcode Version**: 15.0+

## Support

For questions about implementing the type parameter functionality:

1. **Documentation**: Check this integration guide
2. **Example Project**: Review `WedgeExample/` project
3. **Issues**: Create an issue in the repository
4. **Team Support**: Contact the Wedge team directly

## Changelog

### Version 1.2.0
- ✨ **NEW**: Runtime app-specific completion redirect URI resolution (explicit URI, URL scheme, or bundle ID fallback)
- ✨ **NEW**: Webapp redirect propagation through `WedgeSDK.setConfig`, `window.WedgeSDKiOS/window.WedgeSDKIOS`, and supported URL query params
- ✨ **NEW**: Hosted Link completion callback contract maintained via `window.__hostedLinkComplete(...)`
- 📚 **DOCUMENTATION**: Updated integration guidance for redirect/channel requirements

### Version 1.1.0
- ✨ **NEW**: Added `type` parameter support
- ✨ **NEW**: Support for "onboarding" and "funding" flow types
- ✨ **NEW**: Plaid Hosted Link via ASWebAuthenticationSession (`completionRedirectUri`)
- 🔄 **ENHANCED**: URL construction includes type parameter
- ✅ **BACKWARD COMPATIBLE**: Existing code continues to work
- 📚 **DOCUMENTATION**: Comprehensive integration guide

### Version 1.0.0
- 🎯 **INITIAL**: First release of Wedge Pay iOS SDK
- 🎨 **FEATURE**: Native SwiftUI integration
- 🔄 **FEATURE**: Bidirectional communication
- ⚙️ **FEATURE**: Multi-environment support 