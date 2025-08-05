# Wedge Pay iOS Integration Guide

This guide provides detailed instructions for integrating the Wedge iOS SDK into your SwiftUI iOS application.

## Overview

The Wedge iOS SDK provides a SwiftUI component that hosts your onboarding webapp with bidirectional communication capabilities. The SDK handles the presentation, dismissal, and communication between your native app and the webapp using modern SwiftUI patterns.

## Prerequisites

- iOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- An onboarding token from Wedge

## Installation

### Swift Package Manager (Recommended)

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter the repository URL: `https://github.com/your-org/wedge-pay-ios.git`
3. Select the version you want to use (recommended: latest stable version)
4. Click **Add Package**

### Manual Installation

1. Clone the repository: `git clone https://github.com/your-org/wedge-pay-ios.git`
2. Drag the `Sources/wedge_pay_ios` folder into your Xcode project
3. Ensure the files are added to your target

## Basic Integration

### 1. Import the SDK

```swift
import SwiftUI
import WedgePayIOS
```

### 2. Use the SwiftUI View

```swift
WedgePayIOS(
    token: "your-onboarding-token",
    env: "sandbox", // Use "production" for live environment
    theme: "light", // or "dark"
    onEvent: { event in
        // Handle general events
        print("Event: \(event)")
    },
    onSuccess: { customerId in
        // Handle successful onboarding completion
        print("Onboarding completed for customer: \(customerId)")
        // Update your app state, navigate to next screen, etc.
    },
    onClose: { _ in
        // Handle user close/cancel
        print("User closed onboarding")
        // Track analytics, show exit confirmation, etc.
    },
    onLoad: { url in
        // Handle webapp load
        print("Webapp loaded: \(url)")
    },
    onError: { error in
        // Handle errors
        print("Onboarding error: \(error)")
        // Show error message, retry, etc.
    }
)
```

## Complete Integration Example

```swift
import SwiftUI
import WedgePayIOS

struct OnboardingView: View {
    @State private var showingOnboarding = false
    @State private var statusMessage = "Ready to start onboarding"
    @State private var customerId: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text(statusMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Start Onboarding") {
                showingOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $showingOnboarding) {
                WedgePayIOS(
                    token: "your-onboarding-token-here",
                    env: "sandbox",
                    theme: "light",
                    onEvent: { event in
                        print("Event: \(event)")
                    },
                    onSuccess: { customerId in
                        self.customerId = customerId
                        statusMessage = "✅ Success! Customer ID: \(customerId)"
                        showingOnboarding = false
                        handleOnboardingSuccess(customerId: customerId)
                    },
                    onClose: { _ in
                        statusMessage = "⚠️ User closed onboarding"
                        showingOnboarding = false
                        handleOnboardingExit()
                    },
                    onLoad: { url in
                        print("Loaded: \(url)")
                    },
                    onError: { error in
                        statusMessage = "❌ Error: \(error)"
                        showingOnboarding = false
                        handleOnboardingError(error: "\(error)")
                    }
                )
            }
            
            if let customerId = customerId {
                Text("Customer ID: \(customerId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private func handleOnboardingSuccess(customerId: String) {
        // Store customer ID
        UserDefaults.standard.set(customerId, forKey: "wedgeCustomerId")
        
        // Navigate to success screen or update app state
        print("Onboarding completed successfully")
    }
    
    private func handleOnboardingError(error: String) {
        // Show error alert or handle error
        print("Onboarding failed with error: \(error)")
    }
    
    private func handleOnboardingExit() {
        // Track analytics or handle exit
        print("User exited onboarding")
    }
}
```

## WebApp Communication

Your webapp needs to communicate with the native SDK using the provided JavaScript API.

### JavaScript API

The SDK automatically injects a global `window.wedgeOnboarding` object into your webapp.

```javascript
// Check if the bridge is available
if (window.wedgeOnboarding) {
    console.log('Wedge iOS SDK bridge is ready');
} else {
    console.log('Wedge iOS SDK bridge not available');
}
```

### Sending Events

```javascript
// Success event - call when onboarding completes successfully
window.wedgeOnboarding.postMessage({
    event: "onSuccess",
    customerId: "customer-123"
});

// Error event - call when identity verification fails
window.wedgeOnboarding.postMessage({
    event: "onError",
    errorCode: "verification_failed"
});

// Close event - call when user closes/cancels
window.wedgeOnboarding.postMessage({
    event: "onClose",
    reason: "user_cancelled"
});
```

### Event Reference

| Event | Description | Required Fields |
|-------|-------------|-----------------|
| `onSuccess` | Onboarding completed successfully | `customerId` (String) |
| `onError` | Identity verification failed | `errorCode` (String) |
| `onClose` | User closed/cancelled | `reason` (String, optional) |

### Example WebApp Integration

```javascript
// In your webapp
class OnboardingFlow {
    constructor() {
        this.customerId = null;
        this.setupBridge();
    }
    
    setupBridge() {
        // Wait for bridge to be available
        const checkBridge = () => {
            if (window.wedgeOnboarding) {
                console.log('Bridge ready');
                this.bridge = window.wedgeOnboarding;
            } else {
                setTimeout(checkBridge, 100);
            }
        };
        checkBridge();
    }
    
    completeOnboarding(customerId) {
        this.customerId = customerId;
        
        if (this.bridge) {
            this.bridge.postMessage({
                event: "onSuccess",
                customerId: customerId
            });
        } else {
            console.error('Bridge not available');
        }
    }
    
    handleError(errorCode) {
        if (this.bridge) {
            this.bridge.postMessage({
                event: "onError",
                errorCode: errorCode
            });
        }
    }
    
    closeOnboarding(reason = "user_cancelled") {
        if (this.bridge) {
            this.bridge.postMessage({
                event: "onClose",
                reason: reason
            });
        }
    }
}

// Usage
const onboarding = new OnboardingFlow();

// When user completes onboarding
onboarding.completeOnboarding("customer-123");

// When verification fails
onboarding.handleError("verification_failed");

// When user closes
onboarding.closeOnboarding("user_cancelled");
```

## Environment Configuration

### Available Environments

```swift
var environments = [
    "integration": "https://onboarding-integration.wedge-can.com",
    "sandbox": "https://onboarding-sandbox.wedge-can.com",
    "production": "https://onboarding.wedge-can.com"
]
```

### Integration Environment

Use the integration environment for development and testing:

```swift
WedgePayIOS(
    token: "integration-token",
    env: "integration",
    theme: "light",
    // ... callbacks
)
```

### Sandbox Environment

Use the sandbox environment for testing:

```swift
WedgePayIOS(
    token: "sandbox-token",
    env: "sandbox",
    theme: "light",
    // ... callbacks
)
```

### Production Environment

Use the production environment for live applications:

```swift
WedgePayIOS(
    token: "production-token",
    env: "production",
    theme: "light",
    // ... callbacks
)
```

## Error Handling

### Common Error Codes

| Error Code | Description | Recommended Action |
|------------|-------------|-------------------|
| `verification_failed` | Identity verification failed | Retry verification |
| `document_invalid` | Document is invalid or unclear | Request new document |
| `network_error` | Network connectivity issue | Check connection and retry |
| `timeout` | Request timed out | Retry the operation |

### Error Handling Best Practices

```swift
private func handleOnboardingError(error: String) {
    switch error {
    case let e where e.contains("verification_failed"):
        showRetryAlert(message: "Identity verification failed. Please try again.")
    case let e where e.contains("document_invalid"):
        showRetryAlert(message: "Document is unclear. Please upload a clearer image.")
    case let e where e.contains("network_error"):
        showRetryAlert(message: "Network error. Please check your connection and try again.")
    case let e where e.contains("timeout"):
        showRetryAlert(message: "Request timed out. Please try again.")
    default:
        showRetryAlert(message: "An error occurred. Please try again.")
    }
}

private func showRetryAlert(message: String) {
    // In SwiftUI, you can use @State to show alerts
    // or integrate with your alert system
    print("Error: \(message)")
}
```

## Testing

### Unit Testing

```swift
import XCTest
@testable import wedge_pay_ios

class WedgeIOSSDKTests: XCTestCase {
    
    func testSDKInitialization() {
        var successCalled = false
        var errorCalled = false
        var closeCalled = false
        
        let sdk = WedgePayIOS(
            token: "test-token",
            env: "sandbox",
            theme: "light",
            onEvent: { _ in },
            onSuccess: { _ in successCalled = true },
            onClose: { _ in closeCalled = true },
            onLoad: { _ in },
            onError: { _ in errorCalled = true }
        )
        
        XCTAssertNotNil(sdk)
        XCTAssertEqual(sdk.token, "test-token")
        XCTAssertEqual(sdk.env, "sandbox")
        XCTAssertEqual(sdk.theme, "light")
    }
    
    func testCallbacks() {
        var successCalled = false
        var errorCalled = false
        var closeCalled = false
        
        let sdk = WedgePayIOS(
            token: "test-token",
            env: "sandbox",
            theme: "light",
            onEvent: { _ in },
            onSuccess: { _ in successCalled = true },
            onClose: { _ in closeCalled = true },
            onLoad: { _ in },
            onError: { _ in errorCalled = true }
        )
        
        sdk.onSuccess("test-customer")
        sdk.onError("test-error")
        sdk.onClose("test-close")
        
        XCTAssertTrue(successCalled)
        XCTAssertTrue(errorCalled)
        XCTAssertTrue(closeCalled)
    }
}
```

### Integration Testing

1. Use the provided example app to test the SDK
2. Test all environments (integration, sandbox, production)
3. Test all callback scenarios (success, error, close)
4. Test network connectivity issues
5. Test different onboarding tokens
6. Test theme switching (light/dark)

## Troubleshooting

### Common Issues

**SDK not initializing**
- Ensure you're using iOS 14.0 or later
- Check that the package is properly added to your target
- Verify the import statement is correct

**Webapp not loading**
- Check the onboarding token is valid
- Verify the environment configuration
- Ensure network connectivity

**Communication not working**
- Check that the JavaScript bridge is properly injected
- Verify the message format is correct
- Ensure the webapp is calling the correct API

**Build errors**
- Update to the latest version of the SDK
- Check Xcode and Swift versions
- Clean and rebuild the project

**SwiftUI integration issues**
- Ensure you're using SwiftUI properly
- Check that the view is presented correctly
- Verify state management is working

### Getting Help

If you encounter issues:

1. Check the [README.md](README.md) for basic usage
2. Review the example app for implementation details
3. Create an issue in the repository with:
   - iOS version
   - Xcode version
   - Error message
   - Steps to reproduce

## Security Considerations

- Never hardcode onboarding tokens in your app
- Store tokens securely (e.g., in Keychain)
- Use environment-specific tokens
- Validate all data received from the webapp
- Implement proper error handling

## Analytics and Tracking

Consider implementing analytics to track:

- Onboarding completion rates
- Drop-off points
- Error frequencies
- User journey patterns

```swift
private func trackOnboardingEvent(_ event: String, properties: [String: Any]) {
    Analytics.track("wedge_onboarding_\(event)", properties: properties)
}

// Usage
trackOnboardingEvent("started", properties: [:])
trackOnboardingEvent("completed", properties: ["customer_id": customerId])
trackOnboardingEvent("failed", properties: ["error_code": errorCode])
trackOnboardingEvent("closed", properties: ["reason": reason])
```

## Support

For technical support and questions:

- Create an issue in the repository
- Contact the Wedge team
- Check the documentation and examples

---

This integration guide should help you successfully integrate the Wedge iOS SDK into your SwiftUI iOS application. For additional support, please refer to the main [README.md](README.md) or contact the Wedge team. 