import SwiftUI
import Firebase
import AVFoundation
import GoogleSignIn

// MARK: - Info.plist Keys
// Для использования функционала пользовательских фонов необходимо добавить в проекте Xcode
// в разделе "Info" следующие ключи:
// NSPhotoLibraryUsageDescription = "Это приложение запрашивает доступ к вашей галерее для выбора фонового изображения"
// NSPhotoLibraryAddUsageDescription = "Это приложение запрашивает доступ к вашей галерее для выбора фонового изображения"

@main
struct RoomManagerApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Инициализация Firebase
        // Явно проверяем наличие и загружаем GoogleService-Info.plist
        let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        if let filePath = filePath,
           let options = FirebaseOptions(contentsOfFile: filePath) {
            FirebaseApp.configure(options: options)
            print("Firebase успешно инициализирован с файлом из пути: \(filePath)")
        } else {
            // Файл не найден, пробуем стандартную конфигурацию
            print("⚠️ GoogleService-Info.plist не найден. Пробуем стандартную конфигурацию")
            FirebaseApp.configure()
        }
        
        // Настройка AVAudioSession
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
        
        // Настройка навигационной панели с размытым фоном для стандартного состояния
        let defaultAppearance = UINavigationBarAppearance()
        defaultAppearance.configureWithDefaultBackground()
        defaultAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        defaultAppearance.shadowColor = .clear
        
        // Создаем прозрачный вид для состояния прокрутки по умолчанию
        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithTransparentBackground()
        scrollEdgeAppearance.backgroundColor = .clear
        scrollEdgeAppearance.shadowColor = .clear
        
        // Устанавливаем настройки для различных состояний
        UINavigationBar.appearance().standardAppearance = defaultAppearance
        UINavigationBar.appearance().compactAppearance = defaultAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Обработка URL схем для Google Sign-In
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
                    } else {
                        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
                    }
                }
        }
        .backgroundTask(.appRefresh("com.roommanager.refresh")) {
            // Пустой фоновый таск для регистрации возможности обновления в фоне
        }
    }
} 