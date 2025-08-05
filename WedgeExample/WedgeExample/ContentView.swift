import SwiftUI
import wedge_pay_ios

struct ContentView: View {
    @State private var token: String = "demo-token-123"
    @State private var selectedEnvironment: String = "sandbox"
    @State private var statusMessage: String = "Ready to start onboarding"
    @State private var statusColor: Color = .primary
    @State private var showingOnboarding = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private let environments = ["integration", "sandbox", "production"]
    
    var body: some View {
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
                Button(action: startOnboarding) {
                    Text("Start Onboarding")
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
            .sheet(isPresented: $showingOnboarding) {
                WedgePayIOS(
                    token: token,
                    env: selectedEnvironment,
                    theme: "light",
                    onEvent: { event in
                        print("Event: \(event)")
                    },
                    onSuccess: { customerId in
                        handleOnboardingSuccess(customerId: customerId)
                    },
                    onClose: { _ in
                        handleOnboardingExit(status: "user_cancelled", customerId: "")
                    },
                    onLoad: { url in
                        print("Loaded: \(url)")
                    },
                    onError: { error in
                        handleOnboardingError(errorCode: "\(error)")
                    }
                )
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func startOnboarding() {
        guard !token.isEmpty else {
            showAlert(title: "Error", message: "Please enter an onboarding token")
            return
        }
        
        showingOnboarding = true
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
    
    private func handleOnboardingExit(status: String, customerId: String) {
        statusMessage = "⚠️ User exited onboarding\nStatus: \(status)\nCustomer ID: \(customerId)"
        statusColor = .orange
        showAlert(title: "Onboarding Exited", message: "User exited at status: \(status)")
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
