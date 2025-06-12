import SwiftUI
import UniformTypeIdentifiers
import Foundation
import AVFoundation
import PhotosUI

// Тип резервного копирования
enum BackupType {
    case export
    case importing
}

struct SettingsView: View {
    @ObservedObject var viewModel: RoomViewModel
    let isLocked: Bool
    let clearAllData: () -> Void
    @Binding var showCustomBackground: Bool
    var requestImagePickerPresentation: () -> Void
    @Binding var backgroundImage: UIImage?
    @Binding var selectedImageItem: PhotosPickerItem?
    @State private var showConfirmationDialog = false
    @State private var backupMessage: String = ""
    @State private var showBackupAlert = false
    @State private var showBackupList = false
    @State private var showFirebaseDebugView = false
    @State private var showSimpleAuthView = false
    @State private var isSyncing = false
    
    // Настройки приложения
    @AppStorage("disableClipboard") private var disableClipboard = false
    @AppStorage("includeSpanish") private var includeSpanish = true
    @AppStorage("useParticleEffect") private var useParticleEffect = true
    
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Внешний вид
                appearanceSection()
                
                // MARK: - Основные настройки
                generalSection()
                
                // MARK: - Управление этажами
                floorManagementSection()
                
                // MARK: - Буфер обмена
                clipboardSection()
                
                // MARK: - Звуки
                soundsSection()
                
                // MARK: - Резервное копирование
                backupSection()
                
                // MARK: - Дополнительные настройки
                advancedSection()
                
                // MARK: - Очистка данных
                clearDataSection()
                
                // MARK: - Фон приложения
                backgroundSection()
                
                // Новая секция для статуса Firebase
                Section(header: Text("Firebase")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Статус аутентификации:")
                            Spacer()
                            if firebaseManager.isAuthenticated {
                                Label("Подключено", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Label("Отключено", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Информация о пользователе
                        if let userEmail = firebaseManager.currentUserEmail {
                            HStack {
                                Text("Пользователь:")
                                Spacer()
                                Text(userEmail)
                                    .foregroundColor(.blue)
                                    .font(.footnote)
                            }
                        }
                        
                        if let lastSyncTime = firebaseManager.lastSyncTime {
                            HStack {
                                Text("Последняя синхронизация:")
                                Spacer()
                                Text(lastSyncTime, style: .relative)
                                    .font(.footnote)
                            }
                        }
                        
                        if let syncError = firebaseManager.syncError {
                            Text("Ошибка: \(syncError)")
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                        
                        // Кнопки авторизации
                        if !firebaseManager.isAuthenticated {
                            Button(action: {
                                Task {
                                    try? await firebaseManager.signInAnonymously()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "person.crop.circle")
                                    Text("Анонимный вход")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                        
                        // Кнопка Google Sign-In (только если поддерживается и не аутентифицирован)
                        if firebaseManager.isGoogleSignInAvailable && !firebaseManager.isAuthenticated {
                            Button(action: {
                                Task { @MainActor in
                                    do {
                                        try await firebaseManager.signInWithGoogle()
                                    } catch {
                                        print("Ошибка Google Sign-In: \(error)")
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "g.circle.fill")
                                    Text("Войти с Google")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        
                        // Кнопка выхода (только если аутентифицирован)
                        if firebaseManager.isAuthenticated {
                            Button(action: {
                                Task { @MainActor in
                                    firebaseManager.signOutFromGoogle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Выйти")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        
                        // Принудительная синхронизация
                        Button(action: {
                            forceSynchronize()
                        }) {
                            HStack {
                                Image(systemName: isSyncing ? "arrow.triangle.2.circlepath.circle" : "arrow.triangle.2.circlepath")
                                    .imageScale(.large)
                                Text(isSyncing ? "Синхронизация..." : "Принудительная синхронизация")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(!firebaseManager.isAuthenticated || isSyncing)
                        .padding(.top, 5)
                        
                        Button(action: {
                            showFirebaseDebugView = true
                        }) {
                            Text("Диагностика Firebase")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            showSimpleAuthView = true
                        }) {
                            HStack {
                                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                                Text("Синхронизация устройств")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarTitle(viewModel.getTranslation(for: "settingsTitle"), displayMode: .inline)
            .alert(isPresented: $showBackupAlert) {
                Alert(title: Text(backupMessage), dismissButton: .default(Text(viewModel.getTranslation(for: "OK"))))
            }
            .listStyle(InsetGroupedListStyle())
            .environment(\.horizontalSizeClass, .regular)
            .sheet(isPresented: $showBackupList) {
                NavigationView {
                    BackupSelectionView(viewModel: viewModel, isLocked: isLocked)
                }
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showFirebaseDebugView) {
                FirebaseDebugView()
            }
            .sheet(isPresented: $showSimpleAuthView) {
                SimpleAuthView()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Секция внешнего вида
    private func appearanceSection() -> some View {
        Section(header: Text(NSLocalizedString("appearance", comment: ""))) {
            VStack(alignment: .leading, spacing: 12) {
                /* Временно отключено
                Toggle(NSLocalizedString("useParticleEffect", comment: ""), isOn: $useParticleEffect)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        useParticleEffect.toggle()
                    }
                    
                if useParticleEffect {
                    HStack {
                        Image(systemName: "tv")
                            .foregroundColor(.purple)
                            .frame(width: 26, height: 26)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(6)
                        
                        NavigationLink(destination: TVEffectSettingsView(translationProvider: viewModel)) {
                            Text(viewModel.getTranslation(for: "brokenTvEffectSettings"))
                        }
                        .disabled(isLocked)
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            // Сбрасываем настройки эффекта и очищаем кэш Metal
                            UserDefaults.standard.removeObject(forKey: "useSimpleEffectFallback")
                            UserDefaults.standard.removeObject(forKey: "tvEffectNoiseSize")
                            NotificationCenter.default.post(name: NSNotification.Name("ResetMetalRenderer"), object: nil)
                        }) {
                            Text(NSLocalizedString("resetTVEffect", comment: "Сбросить эффект ТВ"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding(.top, 5)
                }
                */
                
                // Раздел настроек вида ячеек
                HStack {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.blue)
                        .frame(width: 26, height: 26)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    
                    NavigationLink(destination: CellStyleSelectionView(viewModel: viewModel, isLocked: isLocked)) {
                        Text(viewModel.getTranslation(for: "cellStyleSettings"))
                    }
                    .disabled(isLocked)
                }
                

            }
        }
    }
    
    // MARK: - Общие настройки
    private func generalSection() -> some View {
        Section {
            // Выбор языка
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.green)
                    .frame(width: 26, height: 26)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                
                Picker(viewModel.getTranslation(for: "language"), selection: $viewModel.language) {
                    ForEach(RoomViewModel.Language.allCases, id: \.self) { language in
                        Text(language.rawValue)
                    }
                }
                .disabled(isLocked)
            }
        } header: {
            Text(viewModel.getTranslation(for: "general"))
                .font(.headline)
        }
    }
    
    // MARK: - Управление этажами
    private func floorManagementSection() -> some View {
        Section {
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.orange)
                    .frame(width: 26, height: 26)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                
                NavigationLink(destination: FloorSettingsView(viewModel: viewModel, isLocked: isLocked)) {
                    Text(viewModel.getTranslation(for: "floorSettings"))
                }
                .disabled(isLocked)
            }
        } header: {
            Text(viewModel.getTranslation(for: "floorSettings"))
                .font(.headline)
        }
    }
    
    // MARK: - Настройки буфера обмена
    private func clipboardSection() -> some View {
        Section {
            // Отключение буфера обмена
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.orange)
                    .frame(width: 26, height: 26)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                
                Toggle(viewModel.getTranslation(for: "disableClipboard"), isOn: $disableClipboard)
                    .disabled(isLocked)
            }
            
            if !disableClipboard {
                // Включение испанского языка
                HStack {
                    Image(systemName: "character.book.closed")
                        .foregroundColor(.orange)
                        .frame(width: 26, height: 26)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    
                    Toggle(viewModel.getTranslation(for: "includeSpanish"), isOn: $includeSpanish)
                        .disabled(isLocked)
                }
                
                // Настройки шаблонов
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(.orange)
                        .frame(width: 26, height: 26)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    
                    NavigationLink(destination: ClipboardSettingsView(viewModel: viewModel)) {
                        Text(viewModel.getTranslation(for: "clipboardTemplates"))
                    }
                    .disabled(isLocked)
                }
            }
        } header: {
            Text(viewModel.getTranslation(for: "clipboard"))
                .font(.headline)
        }
    }
    
    // MARK: - Настройки звуков
    private func soundsSection() -> some View {
        Section {
            ForEach(SoundManager.SoundType.allCases, id: \.self) { soundType in
                HStack {
                    Image(systemName: soundTypeIcon(for: soundType))
                        .foregroundColor(.cyan)
                        .frame(width: 26, height: 26)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(6)
                    
                    NavigationLink(destination: SoundSelectionView(soundType: soundType, viewModel: viewModel)) {
                        Text(viewModel.getTranslation(for: soundType.rawValue))
                    }
                    .disabled(isLocked)
                }
            }
        } header: {
            Text(viewModel.getTranslation(for: "sounds"))
                .font(.headline)
        }
    }
    
    // Вспомогательная функция для выбора иконок для типов звуков
    private func soundTypeIcon(for soundType: SoundManager.SoundType) -> String {
        switch soundType {
        case .addRoom:
            return "plus.circle"
        case .toggleStatus:
            return "arrow.triangle.2.circlepath"
        case .lockUnlock:
            return "lock.open"
        }
    }
    
    // MARK: - Резервное копирование
    private func backupSection() -> some View {
        Section {
            // Создание резервной копии
            HStack {
                Image(systemName: "arrow.up.doc")
                    .foregroundColor(.indigo)
                    .frame(width: 26, height: 26)
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(6)
                
                Button(viewModel.getTranslation(for: "backupData")) {
                    createBackup()
                }
                .disabled(isLocked)
            }
            
            // Восстановление из резервной копии
            HStack {
                Image(systemName: "arrow.down.doc")
                    .foregroundColor(.indigo)
                    .frame(width: 26, height: 26)
                    .background(Color.indigo.opacity(0.1))
                    .cornerRadius(6)
                
                Button(viewModel.getTranslation(for: "restoreData")) {
                    showBackupList = true
                }
                .disabled(isLocked)
            }
        } header: {
            Text(viewModel.getTranslation(for: "backup"))
                .font(.headline)
        }
    }
    
    // MARK: - Дополнительные настройки
    private func advancedSection() -> some View {
        Section {
            // Сюда можно добавить дополнительные настройки в будущем
            HStack {
                Image(systemName: "hammer")
                    .foregroundColor(.gray)
                    .frame(width: 26, height: 26)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                
                Text(viewModel.getTranslation(for: "noAdvancedSettings"))
                    .foregroundColor(.gray)
            }
        } header: {
            Text(viewModel.getTranslation(for: "advanced"))
                .font(.headline)
        }
    }
    
    // MARK: - Очистка данных
    private func clearDataSection() -> some View {
        Section {
            HStack {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(width: 26, height: 26)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                
                Button(viewModel.getTranslation(for: "clearData")) {
                    showConfirmationDialog = true
                }
                .foregroundColor(.red)
                .disabled(isLocked)
            }
            .confirmationDialog(viewModel.getTranslation(for: "confirmClearData"), isPresented: $showConfirmationDialog) {
                Button(viewModel.getTranslation(for: "clear"), role: .destructive) {
                    clearAllData()
                }
                Button(viewModel.getTranslation(for: "cancel"), role: .cancel) { }
            }
        } header: {
            Text(viewModel.getTranslation(for: "dangerZone"))
                .font(.headline)
                .foregroundColor(.red)
        }
    }
    
    // MARK: - Секция управления фоном
    private func backgroundSection() -> some View {
        Section(header: Text("Фон приложения")) {
            HStack {
                Image(systemName: showCustomBackground ? "photo.fill" : "photo")
                    .foregroundColor(.green)
                    .frame(width: 26, height: 26)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                Button(action: {
                    showCustomBackground.toggle()
                }) {
                    Text(showCustomBackground ? "Скрыть фон" : "Показать фон")
                }
            }
            .disabled(isLocked)
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.blue)
                    .frame(width: 26, height: 26)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                Button(action: {
                    // requestImagePickerPresentation()
                    // Вместо прямого вызова, проверяем, не заблокирован ли интерфейс
                    if !isLocked {
                        requestImagePickerPresentation() // Вызываем замыкание
                    }
                }) {
                    Text(viewModel.getTranslation(for: "setBackground"))
                }
            }
            .disabled(isLocked)
        }
    }
    
    // Обработка резервного копирования
    private func handleBackupRequest(type: BackupType) {
        switch type {
        case .export:
            createBackup()
            
        case .importing:
            showBackupList = true
        }
    }
    
    // Метод для создания резервной копии данных
    private func createBackup() {
        let result = viewModel.backupRooms()
        backupMessage = result
        showBackupAlert = true
    }
    
    // Метод для принудительной синхронизации
    private func forceSynchronize() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        Task {
            // Синхронизируем данные с Firebase
            await viewModel.syncToFirebase()
            
            // Ждем 1 секунду для визуального эффекта
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Возвращаемся в главный поток для обновления UI
            await MainActor.run {
                isSyncing = false
            }
        }
    }
}

// Вспомогательный компонент для шаринга файлов
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems, 
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Вспомогательный компонент для выбора файла
struct DocumentPicker: UIViewControllerRepresentable {
    var callback: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.callback(url)
        }
    }
}

// Для превью SettingsView
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Создаем мок ViewModel
        let mockViewModel = RoomViewModel()
        // Создаем мок для функции requestImagePickerPresentation
        let mockRequestImagePickerPresentation: () -> Void = {}
        // Создаем мок для функции clearAllData
        let mockClearAllData: () -> Void = {}

        // Возвращаем SettingsView с мок-данными
        SettingsView(
            viewModel: mockViewModel,
            isLocked: false,
            clearAllData: mockClearAllData,
            showCustomBackground: .constant(false),
            requestImagePickerPresentation: mockRequestImagePickerPresentation,
            backgroundImage: .constant(nil),
            selectedImageItem: .constant(nil)
        )
    }
}
