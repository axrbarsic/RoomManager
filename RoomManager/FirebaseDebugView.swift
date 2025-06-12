import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct FirebaseDebugView: View {
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var diagnosticInfo = ""
    @State private var isPerformingTest = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Firebase Диагностика")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Статус соединения
                statusSection
                
                // Диагностические данные
                diagnosticSection
                
                // Тестовые кнопки
                actionButtons
                
                // Результаты диагностики
                if !diagnosticInfo.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Результаты:")
                            .font(.headline)
                        
                        Text(diagnosticInfo)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            runDiagnostics()
        }
    }
    
    // MARK: - UI Sections
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Статус подключения")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(firebaseManager.isAuthenticated ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(firebaseManager.isAuthenticated ? "Подключено" : "Отключено")
            }
            
            if let lastSync = firebaseManager.lastSyncTime {
                Text("Последняя синхронизация: \(lastSync, formatter: dateFormatter)")
                    .font(.subheadline)
            }
            
            if let error = firebaseManager.syncError {
                Text("Ошибка: \(error)")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var diagnosticSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Диагностика")
                .font(.headline)
            
            Text("Bundle ID: \(Bundle.main.bundleIdentifier ?? "неизвестно")")
            
            Button("Запустить диагностику") {
                runDiagnostics()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await connectToFirebase()
                }
            }) {
                HStack {
                    Image(systemName: "link")
                    Text("Подключиться")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(firebaseManager.isAuthenticated || isPerformingTest)
            
            Button(action: {
                Task {
                    await testWrite()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Тест записи")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!firebaseManager.isAuthenticated || isPerformingTest)
            
            Button(action: {
                Task {
                    await testRead()
                }
            }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Тест чтения")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!firebaseManager.isAuthenticated || isPerformingTest)
            
            Button(action: {
                checkFirebaseConfig()
            }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Проверка конфигурации")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Actions
    
    private func runDiagnostics() {
        var info = ""
        
        // Проверка Bundle ID
        if let bundleID = Bundle.main.bundleIdentifier {
            info += "📱 Bundle ID приложения: \(bundleID)\n"
        } else {
            info += "❌ Bundle ID не найден\n"
        }
        
        // Проверка наличия GoogleService-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            info += "✅ GoogleService-Info.plist найден: \(path)\n"
            
            if let dict = NSDictionary(contentsOfFile: path) {
                if let projectID = dict["PROJECT_ID"] as? String {
                    info += "🔥 Firebase Project ID: \(projectID)\n"
                }
                
                if let configBundleID = dict["BUNDLE_ID"] as? String {
                    info += "📄 Firebase Bundle ID: \(configBundleID)\n"
                    
                    if configBundleID != Bundle.main.bundleIdentifier {
                        info += "⚠️ ОШИБКА: Bundle ID в GoogleService-Info.plist не совпадает с Bundle ID приложения\n"
                    }
                }
            } else {
                info += "❌ Не удалось прочитать GoogleService-Info.plist\n"
            }
        } else {
            info += "❌ GoogleService-Info.plist не найден в ресурсах приложения\n"
        }
        
        // Статус Firebase
        if FirebaseApp.app() != nil {
            info += "✅ Firebase SDK инициализирован\n"
        } else {
            info += "❌ Firebase SDK не инициализирован\n"
        }
        
        // Статус авторизации
        if Auth.auth().currentUser != nil {
            info += "✅ Пользователь авторизован\n"
            info += "👤 ID пользователя: \(Auth.auth().currentUser?.uid ?? "неизвестно")\n"
        } else {
            info += "👤 Пользователь не авторизован\n"
        }
        
        diagnosticInfo = info
    }
    
    private func connectToFirebase() async {
        isPerformingTest = true
        do {
            try await firebaseManager.signInAnonymously()
            diagnosticInfo += "✅ Успешное подключение к Firebase\n"
        } catch {
            diagnosticInfo += "❌ Ошибка подключения: \(error.localizedDescription)\n"
        }
        isPerformingTest = false
        runDiagnostics()
    }
    
    private func testWrite() async {
        isPerformingTest = true
        diagnosticInfo += "🔄 Тестирование записи в Firestore...\n"
        
        guard let userId = Auth.auth().currentUser?.uid else {
            diagnosticInfo += "❌ Нет аутентифицированного пользователя\n"
            isPerformingTest = false
            return
        }
        
        // Создаем тестовый документ
        let db = Firestore.firestore()
        let testDoc = db.collection("users").document(userId).collection("test").document("test-doc")
        
        do {
            // Используем throw, чтобы показать компилятору, что ошибка возможна
            let data: [String: Any] = [
                "timestamp": FieldValue.serverTimestamp(),
                "deviceInfo": UIDevice.current.name,
                "testValue": "test-\(Int.random(in: 1...1000))"
            ]
            
            try await testDoc.setData(data)
            diagnosticInfo += "✅ Тестовый документ успешно записан\n"
        } catch {
            diagnosticInfo += "❌ Ошибка записи: \(error.localizedDescription)\n"
        }
        
        isPerformingTest = false
    }
    
    private func testRead() async {
        isPerformingTest = true
        diagnosticInfo += "🔄 Тестирование чтения из Firestore...\n"
        
        guard let userId = Auth.auth().currentUser?.uid else {
            diagnosticInfo += "❌ Нет аутентифицированного пользователя\n"
            isPerformingTest = false
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            // Используем явный throw, чтобы показать компилятору, что ошибка возможна
            let testDocRef = db.collection("users").document(userId).collection("test").document("test-doc")
            let testDoc = try await testDocRef.getDocument()
            
            if testDoc.exists {
                if let data = testDoc.data() {
                    diagnosticInfo += "✅ Документ успешно прочитан\n"
                    diagnosticInfo += "📄 Содержимое: \(data)\n"
                } else {
                    diagnosticInfo += "⚠️ Документ существует, но данные не получены\n"
                }
            } else {
                diagnosticInfo += "⚠️ Тестовый документ не существует\n"
                
                // Попробуем прочитать все документы в коллекции test
                let testDocs = try await db.collection("users").document(userId).collection("test").getDocuments()
                diagnosticInfo += "📚 Найдено \(testDocs.documents.count) документов в коллекции test\n"
            }
        } catch {
            diagnosticInfo += "❌ Ошибка чтения: \(error.localizedDescription)\n"
        }
        
        isPerformingTest = false
    }
    
    private func checkFirebaseConfig() {
        diagnosticInfo = "🔍 Проверка конфигурации Firebase...\n"
        
        // Проверка конфигурации Firebase
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) {
            
            diagnosticInfo += "📄 Содержимое GoogleService-Info.plist:\n"
            
            // Вывод основных параметров конфигурации
            let keysToShow = ["PROJECT_ID", "BUNDLE_ID", "API_KEY", "GCM_SENDER_ID", 
                              "STORAGE_BUCKET", "IS_ADS_ENABLED", "IS_ANALYTICS_ENABLED", 
                              "IS_APPINVITE_ENABLED", "IS_GCM_ENABLED", "IS_SIGNIN_ENABLED"]
            
            for key in keysToShow {
                if let value = dict[key] {
                    if key == "API_KEY" {
                        // Скрываем API ключ в целях безопасности
                        if let apiKey = value as? String, apiKey.count > 8 {
                            let maskedKey = String(apiKey.prefix(4)) + "..." + String(apiKey.suffix(4))
                            diagnosticInfo += "🔑 \(key): \(maskedKey)\n"
                        } else {
                            diagnosticInfo += "🔑 \(key): [скрыто]\n"
                        }
                    } else {
                        diagnosticInfo += "📌 \(key): \(value)\n"
                    }
                }
            }
            
            // Проверка Bundle ID
            if let bundleID = Bundle.main.bundleIdentifier,
               let configBundleID = dict["BUNDLE_ID"] as? String {
                if bundleID != configBundleID {
                    diagnosticInfo += "\n⚠️ НЕСООТВЕТСТВИЕ: Bundle ID приложения (\(bundleID)) не совпадает с Bundle ID в GoogleService-Info.plist (\(configBundleID))\n"
                    diagnosticInfo += "👉 Рекомендации: Смотрите README_FIREBASE.md для инструкций по решению проблемы\n"
                } else {
                    diagnosticInfo += "\n✅ Bundle ID соответствует конфигурации Firebase\n"
                }
            }
        } else {
            diagnosticInfo += "❌ Не удалось прочитать GoogleService-Info.plist\n"
        }
        
        // Проверка инициализации Firebase
        if FirebaseApp.app() != nil {
            diagnosticInfo += "\n✅ Firebase SDK успешно инициализирован\n"
        } else {
            diagnosticInfo += "\n❌ Firebase SDK не инициализирован\n"
        }
    }
    
    // MARK: - Helpers
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct FirebaseDebugView_Previews: PreviewProvider {
    static var previews: some View {
        FirebaseDebugView()
    }
} 