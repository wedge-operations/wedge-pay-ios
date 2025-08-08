import XCTest
@testable import wedge_pay_ios

final class WedgePayIOSTests: XCTestCase {
    
    func testWedgeEnvironmentURLs() {
        let environments = ["integration": "https://onboarding-integration.wedge-can.com",
                           "sandbox": "https://onboarding-sandbox.wedge-can.com",
                           "production": "https://onboarding.wedge-can.com"]
        
        XCTAssertEqual(environments["integration"], "https://onboarding-integration.wedge-can.com")
        XCTAssertEqual(environments["sandbox"], "https://onboarding-sandbox.wedge-can.com")
        XCTAssertEqual(environments["production"], "https://onboarding-production.wedge-can.com")
    }
    
    #if os(iOS)
    @available(iOS 14.0, *)
    func testWedgePayIOSInitialization() {
        var successCalled = false
        var errorCalled = false
        var closeCalled = false
        var loadCalled = false
        var eventCalled = false
        
        let sdk = WedgePayIOS(
            token: "test-token-123",
            env: "sandbox",
            theme: "light",
            onEvent: { event in
                eventCalled = true
                XCTAssertNotNil(event)
            },
            onSuccess: { customerId in
                successCalled = true
                XCTAssertEqual(customerId, "test-customer-id")
            },
            onClose: { _ in
                closeCalled = true
            },
            onLoad: { url in
                loadCalled = true
                XCTAssertNotNil(url)
            },
            onError: { error in
                errorCalled = true
                XCTAssertNotNil(error)
            }
        )
        
        XCTAssertNotNil(sdk)
        
        // Test callbacks
        sdk.onSuccess("test-customer-id")
        sdk.onError("test-error")
        sdk.onClose("test-close")
        sdk.onLoad("test-url")
        sdk.onEvent("test-event")
        
        XCTAssertTrue(successCalled)
        XCTAssertTrue(errorCalled)
        XCTAssertTrue(closeCalled)
        XCTAssertTrue(loadCalled)
        XCTAssertTrue(eventCalled)
    }
    #endif
    
    func testPackageCompilation() {
        // This test ensures the package compiles successfully
        XCTAssertTrue(true, "Package compiles successfully")
    }
} 