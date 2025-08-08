//
//  WedgeExampleApp.swift
//  WedgeExample
//
//  Created by Jeff LaPrade on 8/5/25.
//

import SwiftUI

@main
struct WedgeExampleApp: App {
    init() {
        // Configure app to reduce WebKit warnings
        configureApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func configureApp() {
        // Suppress WebKit networking warnings in debug builds
        #if DEBUG
        // Set environment variable to reduce WebKit warnings
        setenv("WEBKIT_DISABLE_COMPOSITING_MODE", "1", 1)
        #endif
        
        // Configure URL cache to reduce network warnings
        let cache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "webview_cache")
        URLCache.shared = cache
    }
}
