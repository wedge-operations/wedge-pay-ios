# Wedge Pay iOS

A SwiftUI SDK that wraps the Wedge onboarding webapp inside a native iOS drawer component with bidirectional communication capabilities.

**Version**: 1.1.0

## Features

- 🎯 **Native SwiftUI Integration**: Built with SwiftUI and UIViewRepresentable for modern iOS apps
- 🔄 **Bidirectional Communication**: Real-time messaging between the webapp and native SDK
- ⚙️ **Configurable**: Support for integration, sandbox, and production environments
- 🎨 **Modern UI**: Clean, native iOS design with smooth animations
- 📱 **iOS 14+ Support**: Built for modern iOS applications
- 🔒 **Security**: HTTPS-only navigation, input validation, and secure communication
- ♿ **Accessibility**: Full VoiceOver support and accessibility labels
- 🔄 **Error Handling**: Comprehensive error handling with retry mechanisms
- 🧹 **Memory Management**: Proper cleanup and memory leak prevention

## Type Parameter Functionality

The SDK now supports a `type` parameter that determines the behavior and flow of the onboarding experience:

### Available Types

- **`"onboarding"`** (default): Full onboarding flow for new users
- **`"funding"`**: Streamlined flow for existing users who need to add funding sources

### Behavior Changes

- **Onboarding Mode**: Complete identity verification and account setup
- **Funding Mode**: Focused on adding payment methods and relinking funding sources


### Implementation

```swift
// For new user onboarding
WedgePayIOS(
    token: "your-token",
    env: "sandbox",
    type: "onboarding", // Full onboarding flow
    // ... other parameters
)

// For existing users making changes to linked funding accounts
WedgePayIOS(
    token: "your-token", 
    env: "sandbox",
    type: "funding", // Funding-focused flow
    // ... other parameters
)
```

### Backward Compatibility

- Existing code continues to work without changes
- `type` parameter defaults to `"onboarding"` if not specified
- No breaking changes to existing implementations

## Installation

### Swift Package Manager (Recommended)

The Wedge Pay iOS SDK is available via Swift Package Manager, which is the preferred installation method.

#### Option 1: Add Package in Xcode

1. In Xcode, go to **File** → **Add Package Dependencies**
2. In the search bar, paste the repository URL:
   ```
   https://github.com/wedge-operations/wedge-pay-ios.git
   ```
3. Click **Add Package**
4. Select your target and click **Add Package**

#### Option 2: Add to Package.swift

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/wedge-operations/wedge-pay-ios.git", exact: "1.1.0")
]
```

### Manual Installation (Not Recommended)

1. Clone the repository: `git clone https://github.com/wedge-operations/wedge-pay-ios.git`
2. Drag the `Sources/wedge_pay_ios` folder into your Xcode project
3. Ensure the files are added to your target

## Quick Start

### 1. Import the SDK

```swift
import SwiftUI
import WedgePayIOS
```

### 2. Use the SwiftUI View

```swift
WedgePayIOS(
    token: "your-onboarding-token",
    env: "sandbox", // or "integration", "production"
    type: "onboarding", // or "funding" for changes to linked bank accounts
    onEvent: { event in
        // Handle general events
        print("Event: \(event)")
    },
    onSuccess: { customerId in
        // Handle successful onboarding completion
        print("Onboarding completed for customer: \(customerId)")
    },
    onClose: { _ in
        // Handle user close/cancel
        print("User closed onboarding")
    },
    onLoad: { url in
        // Handle webapp load
        print("Webapp loaded: \(url)")
    },
    onError: { error in
        // Handle errors
        print("Onboarding error: \(error)")
    }
)
```

## Complete SwiftUI Example

```swift
import SwiftUI
import WedgePayIOS

struct ContentView: View {
    @State private var showingOnboarding = false
    @State private var statusMessage = "Ready to start onboarding"
    
    var body: some View {
        VStack {
            Text(statusMessage)
                .padding()
            
            Button("Start Onboarding") {
                showingOnboarding = true
            }
            .sheet(isPresented: $showingOnboarding) {
                WedgePayIOS(
                    token: "your-onboarding-token-here",
                    env: "sandbox",
                    type: "onboarding", // or "funding" for changes to linked bank accounts
                    onEvent: { event in
                        print("Event: \(event)")
                    },
                    onSuccess: { customerId in
                        statusMessage = "✅ Success! Customer ID: \(customerId)"
                        showingOnboarding = false
                    },
                    onClose: { _ in
                        statusMessage = "⚠️ User closed onboarding"
                        showingOnboarding = false
                    },
                    onLoad: { url in
                        print("Loaded: \(url)")
                    },
                    onError: { error in
                        statusMessage = "❌ Error: \(error)"
                        showingOnboarding = false
                    }
                )
            }
        }
    }
}
```

## Example Project

The repository includes a complete example project (`WedgeExample/`) that demonstrates how to integrate the SDK using Swift Package Manager. The example shows:

- **SDK Integration**: How to import and use the `WedgePayIOS` component
- **Callback Handling**: Examples of all SDK callbacks (onSuccess, onError, onClose, etc.)
- **Error Handling**: Comprehensive error handling and user feedback
- **Environment Switching**: Support for sandbox and production environments

To run the example:
1. Open `WedgeExample/WedgeExample.xcodeproj` in Xcode
2. Add the Swift Package dependency (see `WedgeExample/README.md` for detailed setup)
3. Build and run the project
4. Pass in onboarding token to test the onboarding flow

**Note**: The example project is configured to use Swift Package Manager, demonstrating the proper integration method for production use.

## API Reference

### WedgePayIOS

Main SwiftUI view for the SDK.

```swift
public struct WedgePayIOS: UIViewRepresentable {
    public init(
        shouldDismiss: Bool = false,
        token: String,
        env: String,
        type: String = "onboarding",
        onEvent: @escaping (Any) -> Void,
        onSuccess: @escaping (String) -> Void,
        onClose: @escaping (Any) -> Void,
        onLoad: @escaping (Any) -> Void,
        onError: @escaping (Any) -> Void
    )
}
```

### Parameters

- `token`: Your onboarding token
- `env`: Environment ("integration", "sandbox", "production")
- `type`: Flow type ("onboarding" for new users, "funding" for existing user bank adjustments)
- `onEvent`: Called for general events
- `onSuccess`: Called when onboarding completes successfully
- `onClose`: Called when user closes/cancels
- `onLoad`: Called when webapp loads
- `onError`: Called when errors occur

### Available Environments

```swift
var environments = [
    "integration": "https://onboarding-integration.wedge-can.com",
    "sandbox": "https://onboarding-sandbox.wedge-can.com",
    "production": "https://onboarding.wedge-can.com"
]
```

## WebApp Communication

The SDK communicates with the webapp using `WKScriptMessageHandler`. The webapp should send messages using the global `window.wedgeOnboarding` object.

### Message Format

```javascript
// Success event
window.wedgeOnboarding.postMessage({
    event: "onSuccess",
    customerId: "customer-123"
});

// Error event
window.wedgeOnboarding.postMessage({
    event: "onError",
    errorCode: "verification_failed"
});

// Close event
window.wedgeOnboarding.postMessage({
    event: "onClose",
    reason: "user_cancelled"
});
```

### Available Events

- `onSuccess`: Triggered when onboarding completes successfully
  - Required: `customerId` (String)
- `onError`: Triggered when identity verification fails
  - Required: `errorCode` (String)
- `onClose`: Triggered when user closes/cancels
  - Optional: `reason` (String)

### JavaScript API

The SDK automatically injects a global `window.wedgeOnboarding` object into the webapp with the following API:

```javascript
// Check if the bridge is available
if (window.wedgeOnboarding) {
    // Send a message to the native SDK
    window.wedgeOnboarding.postMessage({
        event: "onSuccess",
        customerId: "customer-123"
    });
}
```

## Security & Best Practices

### Security Features
- **HTTPS Only**: All navigation is restricted to HTTPS URLs
- **Domain Validation**: Only allows navigation to authorized domains
- **Input Validation**: Validates all inputs and tokens before processing
- **Non-Persistent Storage**: Uses non-persistent website data store for privacy

### Error Handling
- **Retry Mechanism**: Automatic retry with configurable limits
- **Graceful Degradation**: Handles network failures and invalid states
- **Comprehensive Logging**: Detailed error logging for debugging
- **User Feedback**: Clear error messages and loading states

### Memory Management
- **Proper Cleanup**: Removes message handlers and clears webview on dismissal
- **No Memory Leaks**: Implements proper lifecycle management
- **Resource Management**: Efficient handling of webview resources

## Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions, please contact the Wedge team or create an issue in this repository. 