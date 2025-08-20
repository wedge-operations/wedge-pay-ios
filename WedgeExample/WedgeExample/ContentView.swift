import SwiftUI
import wedge_pay_ios

struct ContentView: View {
    @State private var token: String = "demo-token-123"
    @State private var selectedEnvironment: String = "sandbox"
    @State private var selectedType: String = "onboarding"
    @State private var statusMessage: String = "Ready to start onboarding"
    @State private var statusColor: Color = .primary
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingOnboarding = false
    
    private let environments = ["integration", "sandbox", "production"]
    private let types = ["onboarding", "funding"]
    
    var body: some View {
        ZStack {
            // Main content
            NavigationView {
                VStack(spacing: 30) {
                    // Status Label
                    Text(statusMessage)
                        .font(.headline)
                        .foregroundColor(statusColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Environment Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Environment")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Environment", selection: $selectedEnvironment) {
                            ForEach(environments, id: \.self) { env in
                                Text(env.capitalized).tag(env)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    
                    // Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flow Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Type", selection: $selectedType) {
                            ForEach(types, id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    
                    // Type Description
                    Text(typeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Token Text Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Onboarding Token")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter onboarding token", text: $token)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // Start Button
                    Button(action: {
                        guard !token.isEmpty else {
                            showAlert(title: "Error", message: "Please enter an onboarding token")
                            return
                        }
                        showingOnboarding = true
                    }) {
                        Text("Start \(selectedType.capitalized)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 40)
                .navigationTitle("Wedge iOS SDK")
                .navigationBarTitleDisplayMode(.large)
                .alert(alertTitle, isPresented: $showingAlert) {
                    Button("OK") { }
                } message: {
                    Text(alertMessage)
                }
            }
            
            // Onboarding overlay with bottom slide
            if showingOnboarding {
                OnboardingView(
                    token: token,
                    env: selectedEnvironment,
                    type: selectedType,
                    onEvent: { event in
                        print("Event: \(event)")
                    },
                    onSuccess: { customerId in
                        handleOnboardingSuccess(customerId: customerId)
                        showingOnboarding = false
                    },
                    onClose: { _ in
                        handleOnboardingExit(status: "user_cancelled")
                        showingOnboarding = false
                    },
                    onLoad: { url in
                        print("Loaded: \(url)")
                    },
                    onError: { error in
                        handleOnboardingError(errorCode: "\(error)")
                        showingOnboarding = false
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingOnboarding)
    }
    
    private var typeDescription: String {
        switch selectedType {
        case "onboarding":
            return "Complete onboarding flow for new users"
        case "funding":
            return "Streamlined flow for existing users adding funding sources"
        default:
            return ""
        }
    }
    
    private func handleOnboardingSuccess(customerId: String) {
        statusMessage = "✅ Onboarding completed successfully!\nCustomer ID: \(customerId)"
        statusColor = .green
        showAlert(title: "Success", message: "Onboarding completed for customer: \(customerId)")
    }
    
    private func handleOnboardingError(errorCode: String) {
        statusMessage = "❌ Onboarding failed\nError: \(errorCode)"
        statusColor = .red
        showAlert(title: "Onboarding Failed", message: "Error code: \(errorCode)")
    }
    
    private func handleOnboardingExit(status: String) {
        // Enhanced logging for exit events
        var exitMessage = "⚠️ User exited onboarding"
        var exitColor: Color = .orange
        
        // Handle different exit scenarios
        switch status {
        case "error_exit":
            exitMessage = "❌ Onboarding failed and SDK exited\nError occurred during onboarding"
            exitColor = .red
        case "navigation_error", "provisional_navigation_error":
            exitMessage = "❌ Network error and SDK exited\nFailed to load onboarding"
            exitColor = .red
        case "user_cancelled":
            exitMessage = "⚠️ User cancelled onboarding\nUser manually closed the SDK"
            exitColor = .orange
        default:
            exitMessage = "⚠️ User exited onboarding\nStatus: \(status)"
            exitColor = .orange
        }
        
        statusMessage = exitMessage
        statusColor = exitColor
        showAlert(title: "Onboarding Exited", message: "Exit reason: \(status)")
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// Onboarding view as a full screen overlay
struct OnboardingView: View {
    let token: String
    let env: String
    let type: String
    let onEvent: (Any) -> ()
    let onSuccess: (String) -> ()
    let onClose: (Any) -> ()
    let onLoad: (Any) -> ()
    let onError: (Any) -> ()
    
    var body: some View {
        WedgePayIOS(
            token: token,
            env: env,
            type: type,
            onEvent: onEvent,
            onSuccess: onSuccess,
            onClose: onClose,
            onLoad: onLoad,
            onError: onError
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}