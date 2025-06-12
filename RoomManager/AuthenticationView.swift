import SwiftUI
import FirebaseAuth

struct AuthenticationView: View {
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @ObservedObject var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Синхронизация данных")
                .font(.largeTitle)
                .bold()
            
            Text("Войдите для синхронизации данных между устройствами")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if firebaseManager.isAuthenticated {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Подключено")
                        .font(.headline)
                    
                    if let lastSync = firebaseManager.lastSyncTime {
                        Text("Последняя синхронизация: \(lastSync, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Button(action: signInAnonymously) {
                    HStack {
                        if isSigningIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.circle")
                        }
                        Text("Войти анонимно")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(isSigningIn)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
    
    private func signInAnonymously() {
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                try await firebaseManager.signInAnonymously()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
} 