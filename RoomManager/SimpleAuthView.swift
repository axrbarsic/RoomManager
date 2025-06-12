import SwiftUI
import FirebaseAuth

struct SimpleAuthView: View {
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var syncCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Подключение устройств")
                    .font(.title)
                    .padding(.top)
                
                // Иконка устройства
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding()
                
                // Описание
                Text("Введите код синхронизации для подключения всех устройств к общим данным")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Поле ввода кода
                TextField("Код синхронизации", text: $syncCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .keyboardType(.namePhonePad)
                    .onChange(of: syncCode) { newValue in
                        // Очищаем сообщения об ошибках при редактировании
                        if !newValue.isEmpty {
                            errorMessage = ""
                        }
                    }
                
                // Сообщение об ошибке
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                // Кнопка подключения
                Button(action: {
                    connectWithCode()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Подключиться")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(syncCode.isEmpty || isLoading)
                
                // Создать новый код
                Button(action: {
                    generateNewCode()
                }) {
                    Text("Создать новый код")
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading)
                
                // Разделитель
                HStack {
                    VStack { Divider() }
                    Text("или")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    VStack { Divider() }
                }
                .padding()
                
                // Кнопка Google
                Button(action: {
                    signInWithGoogle()
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Войти с Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .alert("Успешное подключение", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Устройства будут синхронизированы автоматически")
            }
            .navigationBarTitle("Синхронизация", displayMode: .inline)
            .navigationBarItems(trailing: Button("Закрыть") {
                dismiss()
            })
        }
    }
    
    // Подключение через Google
    private func signInWithGoogle() {
        isLoading = true
        
        Task { @MainActor in
            do {
                try await firebaseManager.signInWithGoogle()
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = "Ошибка входа с Google: \(error.localizedDescription)"
            }
        }
    }
    
    // Подключение по существующему коду
    private func connectWithCode() {
        guard !syncCode.isEmpty else {
            errorMessage = "Введите код синхронизации"
            return
        }
        
        isLoading = true
        
        Task { @MainActor in
            do {
                try await firebaseManager.signInWithCode(code: syncCode)
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
    }
    
    // Создание нового кода синхронизации
    private func generateNewCode() {
        isLoading = true
        
        // Генерируем случайный 6-значный код
        let randomCode = String(Int.random(in: 100000...999999))
        syncCode = randomCode
        
        Task { @MainActor in
            do {
                try await firebaseManager.createNewSyncCode(code: randomCode)
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
    }
}

struct SimpleAuthView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleAuthView()
    }
} 