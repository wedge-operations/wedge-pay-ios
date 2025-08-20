# Wedge Example App

This example project demonstrates how to integrate the Wedge Pay iOS SDK using Swift Package Manager.

## Setup Instructions

### 1. Open the Project
Open `WedgeExample.xcodeproj` in Xcode.

### 2. Add Swift Package Dependency
1. In Xcode, go to **File** → **Add Package Dependencies**
2. In the search bar, paste the repository URL:
   ```
   https://github.com/wedge-operations/wedge-pay-ios.git
   ```
3. Click **Add Package**
4. Select the `WedgeExample` target and click **Add Package**

### 3. Build and Run
1. Select your target device or simulator
2. Press **Cmd + R** to build and run
3. The app will launch and you can test the onboarding flow

## What This Example Demonstrates

- **SDK Integration**: How to import and use the `WedgePayIOS` component
- **Callback Handling**: Examples of all SDK callbacks (onSuccess, onError, onClose, etc.)
- **Custom Presentation**: Bottom slide transition instead of default side navigation
- **Error Handling**: Comprehensive error handling and user feedback
- **Environment Switching**: Support for integration, sandbox, and production environments

## Type Parameter Functionality

The SDK now supports a `type` parameter that determines the onboarding flow:

### Available Types

- **`"onboarding"`** (default): Complete onboarding flow for new users
- **`"funding"`**: Streamlined flow for existing users adding funding sources

### Usage Examples

```swift
// For new user onboarding
WedgePayIOS(
    token: "your-token",
    env: "sandbox",
    type: "onboarding", // Full onboarding flow
    // ... other parameters
)

// For existing users adding funding
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

## Features

- **Demo Token**: Uses a demo token for testing
- **Environment Picker**: Switch between different environments
- **Status Display**: Real-time status updates during onboarding
- **Custom UI**: Clean, modern interface with proper error handling

## Testing

1. **Start Onboarding**: Tap the "Start Onboarding" button
2. **Watch Transitions**: See the bottom slide animation
3. **Test Callbacks**: Monitor console output for SDK events
4. **Environment Testing**: Try different environments if you have valid tokens

## Troubleshooting

### Build Errors
- Ensure the Swift Package dependency is properly added
- Check that the package is added to your target
- Clean build folder (Cmd + Shift + K) and rebuild

### Import Issues
- Verify the package is added to your target
- Check that the package resolved successfully
- Restart Xcode if needed

### Runtime Issues
- Check console output for SDK events
- Verify the demo token is working
- Test with different environments

## Requirements

- iOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Next Steps

After testing the example app:
1. Integrate the SDK into your own project
2. Replace the demo token with your actual onboarding token
3. Customize the UI and callbacks for your needs
4. Test in your target environment (sandbox/production)

For more information, see the main [README.md](../README.md) in the repository root.
