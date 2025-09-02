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

### API Reference

#### WedgePayIOS Initializer

```swift
public init(
    shouldDismiss: Bool = false,
    token: String,
    env: String,
    type: String = "onboarding", // New parameter
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
| `env` | String | Required | Environment ("integration", "sandbox", "production") |
| `type` | String | "onboarding" | Flow type ("onboarding" or "funding") |
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

- **SDK Version**: 1.1.0
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

### Version 1.1.0
- ✨ **NEW**: Added `type` parameter support
- ✨ **NEW**: Support for "onboarding" and "funding" flow types
- 🔄 **ENHANCED**: URL construction includes type parameter
- ✅ **BACKWARD COMPATIBLE**: Existing code continues to work
- 📚 **DOCUMENTATION**: Comprehensive integration guide

### Version 1.0.0
- 🎯 **INITIAL**: First release of Wedge Pay iOS SDK
- 🎨 **FEATURE**: Native SwiftUI integration
- 🔄 **FEATURE**: Bidirectional communication
- ⚙️ **FEATURE**: Multi-environment support 