import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Combine
import UIKit
import GoogleSignIn
import Network

// MARK: - Перечисление для состояния подключения
enum ConnectionStatus {
    case connected      // Зеленый - подключено
    case unstable      // Желтый - нестабильное соединение  
    case disconnected  // Красный - нет связи
}

// MARK: - Обновление для Google Sign-In
// GoogleSignIn SDK интегрирован в проект

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    @Published var isAuthenticated = false
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var currentUserEmail: String?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private var userId: String?
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    private let deviceName = UIDevice.current.name
    
    // Network Monitor для отслеживания состояния сети
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = false
    private var lastSyncSuccess: Date?
    private var connectionCheckTimer: Timer?
    
    // Для подписок Combine
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        configureGoogleSignIn()
        validateFirebaseConfiguration()
        setupAuthentication()
        startNetworkMonitoring()
        startConnectionStatusMonitoring()
        
        // Сразу инициализируем статус подключения
        updateConnectionStatus()
    }
    
    // MARK: - Google Sign-In Configuration
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let clientId = dict["CLIENT_ID"] as? String else {
            print("❌ Не удалось получить CLIENT_ID из GoogleService-Info.plist")
            return
        }
        
        print("✅ Настройка Google Sign-In с CLIENT_ID: \(clientId)")
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
    }
    
    // MARK: - Validation
    
    private func validateFirebaseConfiguration() {
        // Проверяем Bundle ID
        if let bundleID = Bundle.main.bundleIdentifier {
            print("📱 Текущий Bundle ID приложения: \(bundleID)")
            
            // Пробуем получить Bundle ID из GoogleService-Info.plist
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path),
               let configBundleID = dict["BUNDLE_ID"] as? String {
                print("📄 Bundle ID в GoogleService-Info.plist: \(configBundleID)")
                
                if bundleID != configBundleID {
                    print("⚠️ НЕСООТВЕТСТВИЕ: Bundle ID приложения не совпадает с Bundle ID в GoogleService-Info.plist")
                }
            }
        }
    }
    
    // MARK: - Authentication
    
    private func setupAuthentication() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                self?.userId = user?.uid
                self?.currentUserEmail = user?.email
                
                if user != nil {
                    self?.startListeningForChanges()
                    print("✅ Пользователь аутентифицирован: \(user?.email ?? "анонимный")")
                    
                    // Выполняем миграцию булевых полей для существующих комнат
                    Task {
                        await self?.migrateExistingRooms()
                    }
                } else {
                    self?.stopListeningForChanges()
                    print("ℹ️ Пользователь не аутентифицирован")
                }
            }
        }
    }
    
    func signInAnonymously() async throws {
        do {
            // Проверяем, есть ли уже аутентифицированный пользователь
            if Auth.auth().currentUser != nil {
                print("✅ Пользователь уже аутентифицирован")
                await MainActor.run {
                    self.isAuthenticated = true
                }
                return
            }
            
            // Выполняем анонимную аутентификацию
            let result = try await Auth.auth().signInAnonymously()
            await MainActor.run {
                userId = result.user.uid
                isAuthenticated = true
            }
            print("✅ Успешная анонимная аутентификация: \(result.user.uid)")
        } catch {
            print("❌ Ошибка аутентификации: \(error.localizedDescription)")
            
            await MainActor.run {
                // Расширенная отладка
                if let nsError = error as NSError? {
                    print("  Домен ошибки: \(nsError.domain)")
                    print("  Код ошибки: \(nsError.code)")
                    print("  Детали: \(nsError.userInfo)")
                    
                    // Анализ известных ошибок
                    if nsError.domain == "FIRAuthErrorDomain" {
                        switch nsError.code {
                        case 17020: // AUTH_API_KEY_ERROR
                            syncError = "Неверный API ключ Firebase"
                        case 17021: // AUTH_TOKEN_EXPIRED
                            syncError = "Токен аутентификации истек"
                        case 17005: // NETWORK_ERROR
                            syncError = "Ошибка сети. Проверьте подключение к интернету"
                        default:
                            syncError = "Ошибка аутентификации (код \(nsError.code))"
                        }
                    } else if nsError.domain == "FIRFirestoreErrorDomain" {
                        switch nsError.code {
                        case 7: // PERMISSION_DENIED
                            syncError = "Доступ запрещен. Проверьте правила безопасности Firestore"
                        case 14: // UNAVAILABLE
                            syncError = "Сервис Firebase недоступен"
                        default:
                            syncError = "Ошибка Firestore (код \(nsError.code))"
                        }
                    } else {
                        syncError = error.localizedDescription
                    }
                } else {
                    syncError = error.localizedDescription
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Синхронизация комнат
    
    func syncRooms(_ rooms: [Room]) async {
        guard let userId = userId else { 
            print("❌ Нет аутентификации для синхронизации")
            return 
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            let batch = db.batch()
            let roomsRef = db.collection("users").document(userId).collection("rooms")
            
            print("🔄 Начинаем синхронизацию \(rooms.count) комнат")
            
            // Конвертируем и сохраняем каждую комнату
            for room in rooms {
                let firebaseRoom = FirebaseRoom(from: room, deviceId: deviceId)
                let docRef = roomsRef.document(room.id.uuidString)
                
                // ДЕБАГ: логируем булевы поля
                print("📤 Синхронизируем комнату \(room.number): isMarked=\(room.isMarked), isDeepCleaned=\(room.isDeepCleaned), isCompletedBefore930=\(room.isCompletedBefore930)")
                print("📤 FirebaseRoom \(firebaseRoom.number): isMarked=\(firebaseRoom.isMarked), isDeepCleaned=\(firebaseRoom.isDeepCleaned), isCompletedBefore930=\(firebaseRoom.isCompletedBefore930)")
                
                try batch.setData(from: firebaseRoom, forDocument: docRef, merge: true)
            }
            
            // Обновляем метаданные синхронизации
            let metadataRef = db.collection("users").document(userId).collection("sync_metadata").document(deviceId)
            let metadata = SyncMetadata(
                id: deviceId,
                lastSyncTimestamp: Date(),
                deviceId: deviceId,
                deviceName: deviceName
            )
            try batch.setData(from: metadata, forDocument: metadataRef)
            
            // Коммитим batch
            try await batch.commit()
            
            await MainActor.run {
                lastSyncTime = Date()
                lastSyncSuccess = Date()
                updateConnectionStatus()
            }
            print("✅ Синхронизировано \(rooms.count) комнат")
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
            }
            print("❌ Ошибка синхронизации: \(error)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    // MARK: - Получение комнат
    
    func fetchRooms() async throws -> [Room] {
        guard let userId = userId else { 
            throw FirebaseError.notAuthenticated 
        }
        
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("rooms")
            .getDocuments()
        
        let rooms = try snapshot.documents.compactMap { document -> Room? in
            let firebaseRoom = try document.data(as: FirebaseRoom.self)
            return firebaseRoom.toLocalRoom()
        }
        
        // Отмечаем успешную операцию
        await MainActor.run {
            self.lastSyncSuccess = Date()
            self.updateConnectionStatus()
        }
        
        print("✅ Получено \(rooms.count) комнат из Firebase")
        return rooms
    }
    
    // MARK: - Реальное время слушатель
    
    private func startListeningForChanges() {
        guard let userId = userId else { return }
        
        print("🔄 Запуск слушателя изменений для пользователя: \(userId)")
        
        // Останавливаем предыдущий слушатель, если он был
        stopListeningForChanges()
        
        listener = db.collection("users")
            .document(userId)
            .collection("rooms")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Ошибка слушателя: \(error)")
                    return
                }
                
                guard let snapshot = snapshot, !snapshot.isEmpty else {
                    print("ℹ️ Слушатель: Нет данных или изменений")
                    return
                }
                
                print("📥 Слушатель получил изменения: \(snapshot.documentChanges.count)")
                
                // Обрабатываем изменения
                for change in snapshot.documentChanges {
                    // Отладка каждого изменения
                    print("🔄 Тип изменения: \(change.type.rawValue), документ: \(change.document.documentID)")
                    
                    switch change.type {
                    case .added, .modified:
                        do {
                            let firebaseRoom = try change.document.data(as: FirebaseRoom.self)
                            let room = firebaseRoom.toLocalRoom()
                            
                            // Важно: переключаемся на главный поток для UI обновлений
                            DispatchQueue.main.async {
                                // Отправляем уведомление об изменении
                                print("📢 Публикуем обновление комнаты: \(room.number)")
                                NotificationCenter.default.post(
                                    name: .roomUpdatedFromFirebase,
                                    object: nil,
                                    userInfo: ["room": room]
                                )
                            }
                        } catch {
                            print("❌ Ошибка парсинга: \(error)")
                        }
                        
                    case .removed:
                        let roomId = change.document.documentID
                        
                        // Важно: переключаемся на главный поток для UI обновлений
                        DispatchQueue.main.async {
                            print("🗑️ Публикуем удаление комнаты: \(roomId)")
                            NotificationCenter.default.post(
                                name: .roomDeletedFromFirebase,
                                object: nil,
                                userInfo: ["roomId": roomId]
                            )
                        }
                    }
                }
            }
    }
    
    private func stopListeningForChanges() {
        if listener != nil {
            print("🛑 Останавливаем слушатель изменений")
            listener?.remove()
            listener = nil
        }
    }
    
    // MARK: - Удаление комнаты
    
    func deleteRoom(_ roomId: String) async throws {
        guard let userId = userId else { 
            throw FirebaseError.notAuthenticated 
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("rooms")
            .document(roomId)
            .delete()
    }
    
    // MARK: - Очистка всех данных
    
    func clearAllRooms() async throws {
        guard let userId = userId else { 
            throw FirebaseError.notAuthenticated 
        }
        
        let batch = db.batch()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("rooms")
            .getDocuments()
        
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Авторизация через Google
    
    /// Проверяет, поддерживается ли Google Sign-In
    var isGoogleSignInAvailable: Bool {
        return GIDSignIn.sharedInstance.configuration != nil
    }
    
    /// Авторизация через Google аккаунт
    @MainActor
    func signInWithGoogle() async throws {
        guard let presentingViewController = getRootViewController() else {
            throw FirebaseError.syncFailed("Не удалось получить root view controller")
        }
        
        do {
            // Выполняем Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                throw FirebaseError.syncFailed("Не удалось получить ID токен от Google")
            }
            
            let accessToken = user.accessToken.tokenString
            
            // Создаем credential для Firebase
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // Аутентифицируемся в Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Теперь обновления свойств уже в главном потоке
            userId = authResult.user.uid
            currentUserEmail = authResult.user.email
            isAuthenticated = true
            
            print("✅ Успешная авторизация через Google: \(authResult.user.email ?? "нет email")")
            
        } catch {
            print("❌ Ошибка Google Sign-In: \(error.localizedDescription)")
            syncError = "Ошибка входа через Google: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Выход из Google аккаунта
    @MainActor
    func signOutFromGoogle() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            
            // Теперь обновления свойств уже в главном потоке
            userId = nil
            currentUserEmail = nil
            isAuthenticated = false
            
            print("✅ Успешный выход из Google аккаунта")
        } catch {
            print("❌ Ошибка выхода: \(error.localizedDescription)")
            syncError = "Ошибка выхода: \(error.localizedDescription)"
        }
    }
    
    // Вспомогательная функция для получения root view controller
    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    // MARK: - Авторизация по коду
    
    /// Создает новый код синхронизации для использования на разных устройствах
    func createNewSyncCode(code: String) async throws {
        // Преобразуем код в email/password для Firebase
        let email = "\(code.lowercased())@sync.roommanager.app"
        let password = "SyncCode_\(code)" // Добавляем префикс для безопасности
        
        do {
            // Создаем пользователя с email/password
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            await MainActor.run {
                userId = result.user.uid
                isAuthenticated = true
            }
            
            // Сохраняем информацию о синхронизации
            let db = Firestore.firestore()
            try await db.collection("sync_codes").document(code).setData([
                "uid": result.user.uid,
                "created": FieldValue.serverTimestamp(),
                "device": UIDevice.current.name
            ])
            
            print("✅ Создан новый код синхронизации: \(code)")
        } catch {
            print("❌ Ошибка создания кода: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Авторизация с использованием существующего кода синхронизации
    func signInWithCode(code: String) async throws {
        // Преобразуем код в email/password для Firebase
        let email = "\(code.lowercased())@sync.roommanager.app"
        let password = "SyncCode_\(code)" // Добавляем префикс для безопасности
        
        do {
            // Пытаемся войти с существующими данными
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await MainActor.run {
                userId = result.user.uid
                isAuthenticated = true
            }
            
            // Добавляем это устройство в список подключенных
            let db = Firestore.firestore()
            try await db.collection("sync_codes").document(code).updateData([
                "lastLogin": FieldValue.serverTimestamp(),
                "devices": FieldValue.arrayUnion([UIDevice.current.name])
            ])
            
            print("✅ Успешный вход с кодом: \(code)")
        } catch {
            print("❌ Ошибка входа с кодом: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Информация о текущей синхронизации
    
    /// Возвращает код синхронизации для текущего пользователя, если он есть
    func getCurrentSyncCode() async -> String? {
        guard let userId = userId else { return nil }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("sync_codes")
                .whereField("uid", isEqualTo: userId)
                .getDocuments()
            
            if let document = snapshot.documents.first {
                return document.documentID
            }
            return nil
        } catch {
            print("❌ Ошибка получения кода: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                
                if wasAvailable != self.isNetworkAvailable {
                    print("📶 Сеть: \(path.status == .satisfied ? "ДОСТУПНА" : "НЕДОСТУПНА")")
                }
                
                self.updateConnectionStatus()
            }
        }
        networkMonitor.start(queue: networkQueue)
        print("📡 Запущен мониторинг сети")
    }
    
    private func startConnectionStatusMonitoring() {
        // Проверяем состояние подключения каждые 10 секунд
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateConnectionStatus()
            }
        }
    }
    
    private func updateConnectionStatus() {
        let now = Date()
        let previousStatus = connectionStatus
        
        if !isNetworkAvailable {
            connectionStatus = .disconnected
            if previousStatus != connectionStatus {
                print("🔴 Статус подключения: DISCONNECTED (нет сети)")
            }
            return
        }
        
        if !isAuthenticated {
            connectionStatus = .disconnected
            if previousStatus != connectionStatus {
                print("🔴 Статус подключения: DISCONNECTED (не аутентифицирован)")
            }
            return
        }
        
        // Если последняя успешная синхронизация была недавно (в течение 30 секунд)
        if let lastSync = lastSyncSuccess, now.timeIntervalSince(lastSync) < 30 {
            connectionStatus = .connected
            if previousStatus != connectionStatus {
                print("🟢 Статус подключения: CONNECTED")
            }
            return
        }
        
        // Если последняя синхронизация была более 30 секунд назад, но есть сеть
        if let lastSync = lastSyncSuccess, now.timeIntervalSince(lastSync) < 120 {
            connectionStatus = .unstable
            if previousStatus != connectionStatus {
                print("🟡 Статус подключения: UNSTABLE")
            }
            return
        }
        
        // Если синхронизации не было долго или вообще не было
        connectionStatus = isNetworkAvailable ? .unstable : .disconnected
        if previousStatus != connectionStatus {
            let status = connectionStatus == .unstable ? "UNSTABLE" : "DISCONNECTED"
            print("🔶 Статус подключения: \(status) (долго не было синхронизации)")
        }
    }
    
    // MARK: - Миграция данных
    
    /// Обновляет все существующие комнаты в Firebase, добавляя булевы поля если их нет
    func migrateExistingRooms() async {
        guard let userId = userId else {
            print("❌ Нет аутентификации для миграции")
            return
        }
        
        print("🔄 Начинаем миграцию существующих комнат...")
        
        do {
            // Получаем все комнаты из Firebase
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("rooms")
                .getDocuments()
            
            let batch = db.batch()
            var updatedCount = 0
            
            for document in snapshot.documents {
                let data = document.data()
                var needsUpdate = false
                var updateData: [String: Any] = [:]
                
                // Проверяем и добавляем булевы поля если их нет
                if data["isMarked"] == nil {
                    updateData["isMarked"] = false
                    needsUpdate = true
                }
                
                if data["isDeepCleaned"] == nil {
                    updateData["isDeepCleaned"] = false
                    needsUpdate = true
                }
                
                if data["isCompletedBefore930"] == nil {
                    updateData["isCompletedBefore930"] = false
                    needsUpdate = true
                }
                
                if needsUpdate {
                    batch.updateData(updateData, forDocument: document.reference)
                    updatedCount += 1
                    print("📝 Обновляем комнату: \(data["number"] ?? "неизвестно")")
                }
            }
            
            if updatedCount > 0 {
                try await batch.commit()
                print("✅ Миграция завершена: обновлено \(updatedCount) комнат")
            } else {
                print("ℹ️ Миграция не требуется: все комнаты уже имеют булевы поля")
            }
            
        } catch {
            print("❌ Ошибка миграции: \(error)")
        }
    }
    
    deinit {
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
        listener?.remove()
        connectionCheckTimer?.invalidate()
        networkMonitor.cancel()
    }
}

// MARK: - Error Types
enum FirebaseError: LocalizedError {
    case notAuthenticated
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Пользователь не аутентифицирован"
        case .syncFailed(let message):
            return "Ошибка синхронизации: \(message)"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let roomUpdatedFromFirebase = Notification.Name("roomUpdatedFromFirebase")
    static let roomDeletedFromFirebase = Notification.Name("roomDeletedFromFirebase")
} 