import SwiftUI
import AVFoundation
import Combine
import Charts
import Metal
import simd
import PhotosUI
import AVKit
import UniformTypeIdentifiers

// MARK: - Адаптивный компонент для цифр этажей
struct AdaptiveFloorLabel: View {
    let floor: Int
    let width: CGFloat
    let height: CGFloat
    
    @State private var textColor: Color = .white
    @State private var timer: Timer?
    
    var body: some View {
        Text("\(floor)")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(textColor)
            .frame(width: width, height: height)
            .background(Color.clear)
            .onAppear {
                startColorAdaptation()
            }
            .onDisappear {
                stopColorAdaptation()
            }
    }
    
    private func startColorAdaptation() {
        // Максимальная частота обновления для мгновенной реакции
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { _ in
            updateTextColor()
        }
    }
    
    private func stopColorAdaptation() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTextColor() {
        let time = Date().timeIntervalSince1970
        let position = Double(floor - 1) / 4.0 // 0 to 1 для этажей 1-5
        
        // Быстрая симуляция изменения яркости фона
        let speed = 8.0 // Увеличена скорость для более заметных изменений
        let phase = position * .pi * 4 // Больший фазовый сдвиг между этажами
        
        // Простая синусоида для четкого переключения
        let wave = sin(time * speed + phase)
        
        // Четкое переключение: >0 = темный фон (белый текст), <0 = светлый фон (черный текст)
        let newColor: Color = wave > 0 ? .white : .black
        
        // Мгновенное обновление
        textColor = newColor
    }
}

// MARK: - Главное окно приложения

struct ContentView: View {
    @StateObject var viewModel = RoomViewModel()
    @ObservedObject private var floorManager = FloorManager.shared
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var enteredRoomNumber: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var selectedTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var isLocked = false
    @AppStorage("isRoundedView") private var isRoundedView = false
    @State private var selectedFilter: Room.RoomColor? = nil
    @State private var previousFilter: Room.RoomColor? = nil
    @State private var combinedFilterCycleState: Int = 0 // 0: None, 1: R+P, 2: R+Y, 3: R+P+Y
    @AppStorage("isVerticalLayout") private var isVerticalLayout = false
    @AppStorage("disableClipboard") private var disableClipboard = false
    @AppStorage("includeSpanish") private var includeSpanish = true
    @AppStorage("redMessageTemplate") private var redMessageTemplate = "%@ I received this room at %@"
    @AppStorage("greenMessageTemplate") private var greenMessageTemplate = "%@ room stripped at %@"
    @AppStorage("redMessageTemplateES") private var redMessageTemplateES = "habitación %@ recibida a las %@"
    @AppStorage("greenMessageTemplateES") private var greenMessageTemplateES = "habitación %@ limpiada a las %@"
    @AppStorage("enableRedClipboard") private var enableRedClipboard = true
    @AppStorage("enableGreenClipboard") private var enableGreenClipboard = true
    @AppStorage("useOldColorTap") private var useOldColorTap = false  // Toggle for old single-tap color cycle mode
    @State private var showActionHistory = false
    @ObservedObject private var actionHistoryManager = ActionHistoryManager.shared
    @State private var showWhiteLegend = false
    @State private var selectedRoom: Room?
    @State private var backgroundLoadTask: Task<Void, Never>? = nil
    
    // Управление клавиатурой
    @State private var shouldShowKeyboard = true
    @State private var keyboardTimer: Timer? = nil
    @State private var lastInputTime: Date = Date()
    private let keyboardTimeout: TimeInterval = 3.0
    
    @State private var isListViewMode = false // Новый режим отображения списка
    @State private var selectedListColor: Room.RoomColor? = nil // Выбранный цвет для списка
    
    // Добавляем новое состояние для отображения фона
    @AppStorage("showCustomBackground") private var showCustomBackground = false
    
    // Добавляем состояния для работы с выбором изображения
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage?
    @AppStorage("blurRadius") private var blurRadius: Double = 10.0
    // 0: Fill, 1: Fit, 2: Stretch, 3: Original
    @AppStorage("backgroundImageContentMode") private var backgroundImageContentMode: Int = 0
    
    // Добавлено: состояния для фонового видео
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var backgroundVideoURL: URL?
    @State private var loopingPlayer: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    
    // URL для встроенного видео
    private let bundledVideoName = "VID_20220715_224938_580" // Имя файла без расширения
    private let bundledVideoExtension = "mov" // Расширение файла

    var bundledVideoURL: URL? {
        Bundle.main.url(forResource: bundledVideoName, withExtension: bundledVideoExtension)
    }
    
    // Перечисление для управления активным модальным окном
    enum ActiveSheet: Identifiable, CaseIterable { // Добавлено CaseIterable
        case settings, imagePicker, timePicker, numberSelection, actionHistory

        var id: Int {
            hashValue
        }
    }
    @State private var activeSheet: ActiveSheet?
    
    var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification).map { _ in true },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in false }
        ).eraseToAnyPublisher()
    }
    
    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private func handleColorTap(_ color: Room.RoomColor) {
        provideHapticFeedback()
        
        // Если мы уже в режиме списка и нажали на тот же цвет - выходим из режима списка
        if isListViewMode && selectedListColor == color {
            isListViewMode = false
            selectedListColor = nil
            return
        } else {
            // Переходим в режим списка
            isListViewMode = true
            selectedListColor = color
        }
        
        // Записываем действие выбора режима в историю
        recordFilterChange(
            name: "colorFilter",
            prevFilter: nil,
            newFilter: selectedListColor
        )
    }
    
    private func handleColorFilterTap(_ color: Room.RoomColor) {
        provideHapticFeedback()
        
        combinedFilterCycleState = 0 // Сбрасываем комбинированный фильтр при выборе одиночного
        
        let prevFilter = selectedFilter // Сохраняем предыдущий для истории
        
        if selectedFilter == color {
            selectedFilter = nil // Если тапнули по уже выбранному фильтру - сбрасываем его
            previousFilter = nil
            recordFilterChange(
                name: "", // Пустое имя для общего сброса фильтра
                prevFilter: prevFilter,
                newFilter: nil
            )
        } else {
            selectedFilter = color // Иначе - устанавливаем новый фильтр
            previousFilter = color // previousFilter тут совпадает с selectedFilter
            recordFilterChange(
                name: "", // Пустое имя для установки фильтра
                prevFilter: prevFilter, // Может быть nil или предыдущим цветом
                newFilter: color
            )
        }
    }
    
    private func resetFilters() {
        provideHapticFeedback()
        
        // Записываем действие сброса фильтров в историю
        let prevFilter = selectedFilter
        
        selectedFilter = nil
        previousFilter = nil
        combinedFilterCycleState = 0
        
        recordFilterChange(
            name: "",
            prevFilter: prevFilter,
            newFilter: nil
        )
    }
    
    var body: some View {
        buildMainView()
            .onAppear {
                loadBackgroundImage()
                loadBackgroundVideo()
                // ULTRA PERFORMANCE: Принудительное включение ProMotion 120fps
                HighPerformanceEffectManager.shared.forceUpdateFrameRate()
                print("🚀 ULTRA: ContentView activated ProMotion 120fps")
            }
    }
    
    // Создаем основное представление
    private func buildMainView() -> some View {
        NavigationView {
            GeometryReader { outerGeo in
                buildContentView(outerGeo: outerGeo)
            }
            .background(
                Group {
                    if showCustomBackground {
                        // Видео-фон при наличии URL
                        if let currentURL = backgroundVideoURL, let player = loopingPlayer {
                            let gravity: AVLayerVideoGravity = (currentURL == bundledVideoURL) ? .resizeAspectFill : .resize
                            CustomVideoPlayerView(player: player, videoGravityForPlayer: gravity)
                                .frame(maxWidth: .infinity, maxHeight: .infinity) // Заполняет доступное пространство
                                .clipped() // Обрезает излишки
                                .ignoresSafeArea() // Игнорирует безопасные зоны
                                .onAppear { player.play() } // Запускаем плеер при появлении
                        } else if let backgroundImage = backgroundImage {
                            // Используем выбранное пользователем фото как фон с размытием
                            Image(uiImage: backgroundImage)
                                .resizable() // Всегда resizable
                                .applyScalingMode(mode: backgroundImageContentMode, sourceImageSize: backgroundImage.size)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped() // Обрезаем, если выходит за рамки (особенно для Fill и Original)
                                .blur(radius: blurRadius)
                                .overlay(Color.black.opacity(0.2))
                                .ignoresSafeArea()
                        } else {
                            // Если нет выбранного изображения, показываем зеленый фон
                            Color.green
                                .opacity(0.7)
                                .blur(radius: 10)
                                .overlay(Color.black.opacity(0.2))
                                .ignoresSafeArea()
                        }
                    }
                }
            )
        }
        .preferredColorScheme(.dark)
        // Используем один .sheet(item: content:) для всех модальных окон этого уровня
        .sheet(item: $activeSheet) { item in
            switch item {
            case .settings:
                SettingsView(
                    viewModel: viewModel,
                    isLocked: isLocked,
                    clearAllData: {
                        viewModel.clearAllRooms()
                        actionHistoryManager.clearHistory()
                    },
                    showCustomBackground: $showCustomBackground,
                    requestImagePickerPresentation: {
                        self.activeSheet = nil
                        DispatchQueue.main.async {
                            self.activeSheet = .imagePicker
                        }
                    },
                    backgroundImage: $backgroundImage,
                    selectedImageItem: $selectedImageItem
                )
            case .imagePicker:
            backgroundPickerView
            case .timePicker:
                TimePickerView(
                    viewModel: viewModel,
                    selectedTime: $selectedTime,
                    onSave: setRoomTime
                )
            case .numberSelection:
                NumberSelectionView(viewModel: viewModel)
                    .onDisappear { 
                        shouldShowKeyboard = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shouldShowKeyboard = true }
                    }
            case .actionHistory:
                SimpleHistoryView(viewModel: viewModel)
            }
        }
    }
    
    // Представление для выбора и настройки фонового изображения
    private var backgroundPickerView: some View {
        NavigationView {
            ScrollView {
            VStack(spacing: 20) {
                    // Кнопка для выбора встроенного видео
                    Button(action: {
                        setBundledVideoAsBackground()
                    }) {
                        Label(viewModel.getTranslation(for: "selectBundledVideo"), systemImage: "film")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange) // Другой цвет для отличия
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                // Выбор видео
                PhotosPicker(
                    selection: $selectedVideoItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                        Label(viewModel.getTranslation(for: "selectVideo"), systemImage: "video")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .onChange(of: selectedVideoItem) { newItem in
                    guard let newItem = newItem else { return }

                        backgroundLoadTask?.cancel()
                        backgroundLoadTask = Task {
                            do {
                                guard let data = try await newItem.loadTransferable(type: Data.self) else {
                                    if Task.isCancelled { print("Video load cancelled after trying to load data."); return }
                                    await MainActor.run { self.selectedVideoItem = nil }
                                    return
                                }
                                if Task.isCancelled { print("Video load cancelled after data loaded."); return }

                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            let target = docs.appendingPathComponent("backgroundVideo.mov")
                                
                                // Очищаем предыдущий файл, если есть, чтобы избежать ошибок перезаписи
                            try? FileManager.default.removeItem(at: target)
                                if Task.isCancelled { print("Video load cancelled before writing file."); return }
                                
                                try data.write(to: target)
                                if Task.isCancelled { print("Video load cancelled after writing file."); return }
                                    
                                await MainActor.run {
                                    if Task.isCancelled { print("Video load cancelled just before MainActor.run."); return }
                                    self.backgroundVideoURL = target
                                    self.backgroundImage = nil
                                    self.selectedImageItem = nil
                                    self.loopingPlayer?.pause()
                                    self.loopingPlayer = nil
                                    self.playerLooper = nil
                                    UserDefaults.standard.removeObject(forKey: "backgroundImageData")
                                    saveBackgroundVideoURL(target)
                                    setupVideoPlayer(url: target)
                                    self.selectedVideoItem = nil
                                }
                            } catch {
                                if Task.isCancelled {
                                    print("Video load task was cancelled with error: \\(error)")
                                } else {
                                    print("Ошибка сохранения видео-фона: \\(error)")
                            }
                                 await MainActor.run { self.selectedVideoItem = nil }
                        }
                    }
                }
                // Превью видео и кнопка удаления
                    if let currentURL = backgroundVideoURL, let player = loopingPlayer {
                    // Определяем videoGravity в зависимости от URL
                    let gravity: AVLayerVideoGravity = (currentURL == bundledVideoURL) ? .resizeAspectFill : .resize
                    CustomVideoPlayerView(player: player, videoGravityForPlayer: gravity)
                        .frame(height: 200)
                        .cornerRadius(10)
                        Button(viewModel.getTranslation(for: "deleteVideo")) {
                        clearBackgroundVideo()
                    }
                    .foregroundColor(.red)
                    .padding(.top)
                }
                    Text(viewModel.getTranslation(for: "chooseBackgroundImagePrompt"))
                    .font(.headline)
                
                PhotosPicker(
                    selection: $selectedImageItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                        Label(viewModel.getTranslation(for: "selectFromGallery"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .onChange(of: selectedImageItem) { newItem in
                    guard let newItem = newItem else { return }

                        backgroundLoadTask?.cancel()
                        backgroundLoadTask = Task {
                            do {
                                guard let data = try await newItem.loadTransferable(type: Data.self) else {
                                    if Task.isCancelled { print("Image load cancelled after trying to load data."); return }
                                    await MainActor.run { self.selectedImageItem = nil }
                                    return
                                }
                                if Task.isCancelled { print("Image load cancelled after data loaded."); return }

                                guard let uiImage = UIImage(data: data) else {
                                    if Task.isCancelled { print("Image load cancelled after trying to create UIImage."); return }
                                    await MainActor.run { self.selectedImageItem = nil }
                                    return
                                }
                                
                                if Task.isCancelled { print("Image load cancelled before updating state."); return }
                                
                                await MainActor.run {
                                    if Task.isCancelled { print("Image load cancelled just before MainActor.run."); return }
                                    self.backgroundImage = uiImage
                                    self.backgroundVideoURL = nil
                                    self.loopingPlayer?.pause()
                                    self.loopingPlayer = nil
                                    self.playerLooper = nil
                                    UserDefaults.standard.removeObject(forKey: "backgroundVideoPath")
                                    self.selectedVideoItem = nil
                            saveBackgroundImage()
                                    self.selectedImageItem = nil // Раскомментировано и важно!
                                }
                            } catch {
                                if Task.isCancelled {
                                    print("Image load task was cancelled with error: \\(error)")
                                } else {
                                    print("Error loading image: \\(error)")
                                }
                                await MainActor.run { self.selectedImageItem = nil }
                        }
                    }
                }
                
                if let backgroundImage = backgroundImage {
                        // Предпросмотр с эффектом размытия и выбранным режимом масштабирования
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .scaledToFit() // ИЗМЕНЕНО: Всегда использовать scaledToFit для превью
                            .frame(height: 200) // Фиксированная высота для превью
                            .clipped() // Важно для всех режимов, чтобы вписаться в frame
                            .blur(radius: blurRadius) // Применяем размытие к единому превью
                            .overlay(Color.black.opacity(0.2))
                            .cornerRadius(10)

                        Text(viewModel.getTranslation(for: "imageScalingModePrompt"))
                            .font(.subheadline)
                            .padding(.top)
                        Picker(viewModel.getTranslation(for: "imageScalingModePrompt"), selection: $backgroundImageContentMode) {
                            Text(viewModel.getTranslation(for: "scalingModeFill")).tag(0)
                            Text(viewModel.getTranslation(for: "scalingModeFit")).tag(1)
                            Text(viewModel.getTranslation(for: "scalingModeStretch")).tag(2)
                            Text(viewModel.getTranslation(for: "scalingModeOriginal")).tag(3)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        Text(viewModel.getTranslation(for: "blurIntensityPrompt"))
                        .font(.subheadline)
                    
                    Slider(value: $blurRadius, in: 0...25, step: 1)
                        .padding(.horizontal)
                    
                    Text(String(format: "%.0f", blurRadius))
                        .font(.caption)
                    
                        Button(viewModel.getTranslation(for: "deleteImage")) {
                        self.backgroundImage = nil
                        self.selectedImageItem = nil
                        UserDefaults.standard.removeObject(forKey: "backgroundImageData")
                    }
                    .foregroundColor(.red)
                    .padding(.top)
                }
                
                Spacer()
            }
            .padding()
                .frame(maxWidth: .infinity) // Добавлено для ограничения ширины VStack
            }
            .navigationBarTitle(viewModel.getTranslation(for: "backgroundSettingsTitle"), displayMode: .inline)
            .navigationBarItems(
                trailing: Button(viewModel.getTranslation(for: "doneButton")) {
                    activeSheet = nil // Закрываем imagePicker
                }
            )
        }
    }
    
    // Создаем представление содержимого
    private func buildContentView(outerGeo: GeometryProxy) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).minY
                )
            }
            .frame(height: 0)
            
            VStack(alignment: .center, spacing: 20) {
                buildFloorsSection()
            }
            .centeredWithPadding()
            .padding(.top, 8)
            .padding(.bottom, 20)
            .onTapGesture { hideKeyboard() }
        }
        // SMART PERFORMANCE: Оптимизированный детектор скролла
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in 
                    // Приостанавливаем эффекты для плавного скролла
                    HighPerformanceEffectManager.shared.startScrollDetection()
                }
                .onEnded { _ in 
                    // ULTRA: Немедленный вызов - внутренняя логика сама управляет задержками
                    HighPerformanceEffectManager.shared.stopScrollDetection()
                }
        )
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            // Обрабатываем изменение скролла
            handleScrollChange(value: value)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(false)
        .scrollDismissesKeyboard(.immediately)
        // ULTRA PERFORMANCE: Принудительная высокая частота обновления
        .background(
            // Создаем invisible view который принуждает к высокому FPS
            Color.clear
                .onAppear {
                    // Принудительно активируем высокую частоту обновления
                    HighPerformanceEffectManager.shared.forceUpdateFrameRate()
                }
        )
        // Отключаем анимации, которые могут вызывать проблемы со скроллом
        .animation(.none, value: isLocked)
        .animation(.none, value: selectedFilter)
        .overlay(
            Group {
                if showToast {
                    ToastView(message: toastMessage, isShowing: $showToast)
                        .zIndex(100)
                }
            }
        ) // Всплывающие уведомления, которые автоматически исчезают через 2 секунды
        .overlay(
            SmartFloatingMenu(
                viewModel: viewModel,
                getTranslation: { key in viewModel.getTranslation(for: key) },
                onAction: handleFloatingMenuAction
            )
            .zIndex(999) // Поверх всего включая toast
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                buildToolbarContent()
            }
        }
        .onReceive(keyboardPublisher) { isVisible in
            if isVisible { startKeyboardTimer() } else { stopKeyboardTimer() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in stopKeyboardTimer() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in startKeyboardTimer() }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // Создаем содержимое панели инструментов
    private func buildToolbarContent() -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            HStack(spacing: 2) {
                buildRoomNumberField(width: totalWidth)
                
                // Адаптивное размещение цветных счетчиков
                buildColorCounters(width: totalWidth)
                
                Spacer(minLength: 1)
                
                // Адаптивное размещение кнопок управления
                buildControlButtons(width: totalWidth)
            }
        }
        .frame(height: 44)
    }
    
    // Создаем поле для номера комнаты
    private func buildRoomNumberField(width: CGFloat) -> some View {
        let calculatedWidth = width * 0.18
        let fieldFrameWidth = max(50, min(70, calculatedWidth))
        
        // Цвет фона в зависимости от состояния подключения
        let connectionBackgroundColor: Color = {
            switch firebaseManager.connectionStatus {
            case .connected:
                return Color.green.opacity(0.4)  // Зеленый фон при подключении
            case .unstable:
                return Color.yellow.opacity(0.4) // Желтый фон при нестабильной связи
            case .disconnected:
                return Color.red.opacity(0.4)    // Красный фон при отсутствии связи
            }
        }()

        return TextField(
            {
                // Общее количество ячеек (с учетом видимости белых)
                let totalRooms = viewModel.hideWhiteRooms 
                    ? viewModel.visibleRooms.filter { $0.color != .white }.count 
                    : viewModel.visibleRooms.count
                    
                // Завершенные ячейки (зеленые и синие)
                let completedRooms = viewModel.visibleRooms.filter { $0.color == .green || $0.color == .blue }.count
                
                // Количество не завершенных ячеек (без зеленых и синих)
                let nonCompletedRooms = totalRooms - completedRooms
                    
                return "\(totalRooms)/\(nonCompletedRooms)"
            }(),
            text: $enteredRoomNumber
        )
        .textFieldStyle(PlainTextFieldStyle()) // Убираем стандартные стили
        .keyboardType(.numberPad)
        .frame(width: fieldFrameWidth, height: 36)
        .font(.system(size: 17, weight: .medium))
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.center)
        .disabled(isLocked || !shouldShowKeyboard)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(connectionBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
        )
        // Применяем цвет ПОСЛЕ background
        .foregroundStyle(Color.black) // Используем foregroundStyle вместо foregroundColor
        .accentColor(.black) // Черный цвет курсора
        .tint(.black) // Дополнительно устанавливаем tint color
        .colorScheme(.light) // Принудительно устанавливаем светлую схему для TextField
        .animation(.easeInOut(duration: 0.3), value: firebaseManager.connectionStatus)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.width < 0 {
                        withAnimation { activeSheet = .numberSelection }
                        provideHapticFeedback()
                    }
                }
        )
        .onChange(of: enteredRoomNumber) { newValue in
            handleRoomNumberInput(newValue)
            resetKeyboardTimer()
        }
    }
    
    // Создаем цветные счетчики
    private func buildColorCounters(width: CGFloat) -> some View {
        let colors = getSortedColorCounts()
        // Убедимся, что colors.count не равен нулю, чтобы избежать деления на ноль.
        let count = CGFloat(max(1, colors.count))
        
        let availableWidthForCounters = width * 0.38
        let calculatedItemWidth = (availableWidthForCounters * 0.95) / count
        let itemFrameWidth = max(18, min(24, calculatedItemWidth))
        let hStackSpacing = max(1.0, min(3.0, width * 0.005))

        return HStack(spacing: hStackSpacing) {
            ForEach(colors) { colorCount in
                Text("\(colorCount.count)")
                    .foregroundColor(colorCount.textColor)
                    .frame(width: itemFrameWidth)
                    .font(.system(size: 15, weight: .medium))
                    .minimumScaleFactor(0.6)
                    .padding(4)
                    .background(colorCount.backgroundColor)
                    .cornerRadius(5)
                    .onTapGesture { 
                        // Исправлено: при нажатии на цветной счетчик, используем разные обработчики
                        // в зависимости от того, активен ли уже режим списка
                        if isListViewMode {
                            handleColorTap(colorCount.color)
                        } else {
                            handleColorFilterTap(colorCount.color)
                        }
                    }
                    .onLongPressGesture(minimumDuration: AppConfiguration.Audio.menuLongPressMinDuration * 2) { 
                        provideHapticFeedback()
                        resetFilters() 
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { gesture in
                                handleColorCounterGesture(gesture)
                            }
                    )
            }
        }
    }
    
    // Обрабатываем жест на цветном счетчике
    private func handleColorCounterGesture(_ gesture: DragGesture.Value) {
        if gesture.translation.width < 0 { // Свайп влево
            provideHapticFeedback()
            selectedFilter = nil
            previousFilter = nil
            
            // Логика цикла для combinedFilterCycleState
            if combinedFilterCycleState == 0 { // Если был неактивен или только что сброшен
                combinedFilterCycleState = 1 // Красные + Фиолетовые
            } else if combinedFilterCycleState == 1 {
                combinedFilterCycleState = 2 // Красные + Желтые
            } else if combinedFilterCycleState == 2 {
                combinedFilterCycleState = 3 // Красные + Фиолетовые + Желтые
            } else if combinedFilterCycleState == 3 {
                combinedFilterCycleState = 1 // Возврат к Красные + Фиолетовые
            }
            
            // Записываем включение/изменение комбинированного фильтра в историю
            recordFilterChange(
                name: "combinedFilter",
                prevFilter: nil,
                newFilter: nil
            )
        } else if gesture.translation.width > 0 { // Свайп вправо
            provideHapticFeedback()
            
            // При свайпе вправо сбрасываем комбинированный фильтр
            combinedFilterCycleState = 0
            
            // Удаляем переключение округлого вида ячеек
            recordFilterChange(
                name: "viewMode",
                prevFilter: nil,
                newFilter: nil
            )
        }
    }
    
    // Создаем кнопки управления
    private func buildControlButtons(width: CGFloat) -> some View {
        let calculatedButtonSize = width * 0.035
        let buttonFrameSize = max(12, min(16, calculatedButtonSize))
        let calculatedButtonSpacing = width * 0.008
        let hStackSpacing = max(1, min(3, calculatedButtonSpacing))
        
        return HStack(spacing: hStackSpacing) {
            buildHistoryButton(size: buttonFrameSize)
            buildLayoutButton(size: buttonFrameSize)
            buildSettingsButton(size: buttonFrameSize)
            // Добавляем кнопку для импорта списка из буфера обмена
            Button(action: importRoomsFromClipboard) {
                Image(systemName: "doc.on.clipboard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonFrameSize, height: buttonFrameSize)
                    .foregroundColor(.white)
            }
            // Button for old single-tap color cycle mode
            Button(action: {
                provideHapticFeedback()
                useOldColorTap.toggle()
            }) {
                Image(systemName: useOldColorTap ? "hand.tap.fill" : "hand.tap")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonFrameSize, height: buttonFrameSize)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, min(2, max(1, width * 0.005)))
    }
    
    // MARK: - Keyboard Timer Methods
    
    private func startKeyboardTimer() {
        stopKeyboardTimer()
        lastInputTime = Date()
        keyboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in checkKeyboardTimeout() }
    }
    
    private func stopKeyboardTimer() {
        keyboardTimer?.invalidate()
        keyboardTimer = nil
    }
    
    private func resetKeyboardTimer() {
        lastInputTime = Date()
        if keyboardTimer == nil { startKeyboardTimer() }
    }
    
    private func checkKeyboardTimeout() {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastInputTime) >= keyboardTimeout {
            DispatchQueue.main.async {
                hideKeyboard()
                stopKeyboardTimer()
            }
        }
    }
    
    // MARK: - UI Builders
    
    private func buildHistoryButton(size: CGFloat) -> some View {
        Button(action: {
            // Больше не добавляем тестовое действие при открытии истории
            activeSheet = .actionHistory
            SoundManager.shared.playSound(for: .toggleStatus)
        }) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: size))
                .foregroundColor(.white)
        }
    }
    
    private func buildLayoutButton(size: CGFloat) -> some View {
        Button(action: {
            // Записываем действие изменения режима отображения в историю
            let wasVertical = isVerticalLayout
            isVerticalLayout.toggle()
            
            recordFilterChange(
                name: "layout",
                prevFilter: nil,
                newFilter: wasVertical ? .green : .red
            )
            
            provideHapticFeedback()
        }) {
            Image(systemName: isVerticalLayout ? "rectangle.grid.1x2" : "rectangle.grid.2x2")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.white)
        }
    }
    
    private func buildSettingsButton(size: CGFloat) -> some View {
        Button(action: { provideHapticFeedback(); activeSheet = .settings }) {
            Image(systemName: "gearshape")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Floor Section
    
    // Вспомогательная функция для фильтрации комнат по этажу и цвету
    private func filterRoomsByFloorAndColor(floor: Int, selectedFilter: Room.RoomColor?) -> [Room] {
                        let roomsForFloor = viewModel.visibleRooms.filter { room in
            // Проверяем, находится ли комната на нужном этаже
            let isCorrectFloor = Int(room.number.prefix(1)) == floor
            
            // Не показываем белые комнаты, если они скрыты
            if viewModel.hideWhiteRooms && room.color == .white {
                return false
            }
            
            // Логика для combinedFilterCycleState
            if combinedFilterCycleState == 1 { // Красные + Фиолетовые
                return isCorrectFloor && (room.color == .red || room.color == .purple)
            } else if combinedFilterCycleState == 2 { // Красные + Желтые
                return isCorrectFloor && (room.color == .red || room.color == .none)
            } else if combinedFilterCycleState == 3 { // Красные + Фиолетовые + Желтые
                return isCorrectFloor && (room.color == .red || room.color == .purple || room.color == .none)
            }
            // Конец логики для combinedFilterCycleState
            
            // Проверяем совпадение с одиночным фильтром (если combinedFilterCycleState == 0)
            if let filter = selectedFilter {
                switch filter {
                case .none: return isCorrectFloor && room.color == .none
                case .purple: return isCorrectFloor && room.color == .purple
                case .red: return isCorrectFloor && room.color == .red
                case .green: return isCorrectFloor && (room.color == .green || room.color == .blue)
                case .blue: return isCorrectFloor && room.color == .blue
                case .white: return isCorrectFloor && room.color == .white
                }
            }
            return isCorrectFloor // Если нет ни комбинированных, ни одиночных фильтров
        }
        
        // Сортируем комнаты по номеру
        return roomsForFloor.sorted { $0.number < $1.number }
    }
    
    // Вспомогательная функция для определения, должна ли комната отображаться с учетом фильтров
    private func shouldDisplayRoom(room: Room, selectedFilter: Room.RoomColor?) -> Bool {
        if viewModel.hideWhiteRooms && room.color == .white {
            return false
        }

        // Логика для combinedFilterCycleState
        if combinedFilterCycleState == 1 { // Красные + Фиолетовые
            return room.color == .red || room.color == .purple
        } else if combinedFilterCycleState == 2 { // Красные + Желтые
            return room.color == .red || room.color == .none
        } else if combinedFilterCycleState == 3 { // Красные + Фиолетовые + Желтые
            return room.color == .red || room.color == .purple || room.color == .none
        }
        // Конец логики для combinedFilterCycleState

        // Логика для одиночного фильтра (если combinedFilterCycleState == 0)
        if let filter = selectedFilter {
            switch filter {
            case .none: return room.color == .none
            case .purple: return room.color == .purple
            case .red: return room.color == .red
            case .green: return room.color == .green || room.color == .blue 
            case .blue: return room.color == .blue 
            case .white: return room.color == .white
            }
        }
        return true // Если нет активных фильтров (combinedFilterCycleState == 0 и selectedFilter == nil), отображаем комнату
    }
    
    // Создает ячейку комнаты с необходимыми обработчиками
    private func createRoomCell(for room: Room) -> some View {
        RoomCell(
            room: room,
            toggleRoomStatus: {
                toggleRoomStatus(room)
            },
            setTime: {
                setTimeForRoom(room)
            },
            deleteRoom: {
                deleteRoom(room)
            },
            markRoom: {
                markRoom(room)
            },
            getTranslation: viewModel.getTranslation(for:),
            fontColor: .black,
            isLocked: isLocked,
            removeTime: {
                removeTimeFromRoom(room: room)
            },
            viewModel: viewModel
        )
        .crazyEffect(cellID: room.id)
    }
    
    // Создает сетку ячеек одинакового размера с равной толщиной линий
    private func createGridCell(number: String, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        Text(number)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.gray)
            .frame(width: cellWidth, height: cellHeight)
            .background(Color.clear)
    }
    
    // Создает вертикальную раскладку для этажа
    private func createVerticalLayout() -> some View {
        // Получаем все видимые комнаты
        let visibleRooms = viewModel.visibleRooms
        let screenWidth = UIScreen.main.bounds.width
        let spacing: CGFloat = 0 // Убираем все расстояния между колонками
        let columnWidth = screenWidth / 5 // 5 колонок без отступов
        let cellSize: CGFloat = columnWidth // Квадратные ячейки
        
        return ScrollView {
            HStack(alignment: .top, spacing: spacing) {
                // Создаем 5 колонок для этажей
                ForEach(1...5, id: \.self) { floor in
                    // Фильтруем комнаты для текущего этажа с учетом всех фильтров
                    let floorRooms = visibleRooms.filter { room in
                        // Проверяем, соответствует ли комната текущему этажу
                        let isOnFloor = Int(room.number.prefix(1)) == floor
                        guard isOnFloor else { return false }
                        
                        // Применяем фильтр, если он выбран
                        if let filter = selectedFilter {
                            switch filter {
                            case .none: return room.color == .none
                            case .purple: return room.color == .purple
                            case .red: return room.color == .red
                            case .green: return (room.color == .green || room.color == .blue)
                            case .blue: return room.color == .blue
                            case .white: return room.color == .white
                            }
                        }
                        
                        // Логика для combinedFilterCycleState
                        if combinedFilterCycleState == 1 { // Красные + Фиолетовые
                            return (room.color == .red || room.color == .purple)
                        } else if combinedFilterCycleState == 2 { // Красные + Желтые
                            return (room.color == .red || room.color == .none)
                        } else if combinedFilterCycleState == 3 { // Красные + Фиолетовые + Желтые
                            return (room.color == .red || room.color == .purple || room.color == .none)
                        }
                        
                        // Если нет фильтров, показываем комнату
                        return true
                    }.sorted { $0.number < $1.number }
                    
                    VStack(spacing: 0) { // Убираем spacing между элементами в колонке
                        // Заголовок этажа
                        AdaptiveFloorLabel(
                            floor: floor,
                            width: columnWidth,
                            height: 30
                        )
                        
                        // Комнаты этажа
                        if !floorRooms.isEmpty {
                            ForEach(floorRooms) { room in
                                createRoomCell(for: room)
                                    .frame(width: cellSize, height: cellSize) // Квадратные ячейки
                            }
                        }
                    }
                    .frame(width: columnWidth)
                }
            }
            .padding(.horizontal, 0) // Убираем горизонтальные отступы
            .padding(.vertical, 5) // Минимальный вертикальный отступ
        }
    }
    
    // Функция для определения цвета этажа
    private func floorColor(for floor: Int) -> Color {
        switch floor {
        case 1: return Color.blue
        case 2: return Color.green
        case 3: return Color.orange
        case 4: return Color.purple
        case 5: return Color.red
        default: return Color.gray
        }
    }
    
    // Создает горизонтальную раскладку для всех этажей
    private func createHorizontalLayout() -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        let cellWidth = (UIScreen.main.bounds.width - 50) / 4 // Учитываем отступы
        let cellHeight: CGFloat = 60
        
        return VStack(alignment: .center, spacing: 40) {
            ForEach(1...5, id: \.self) { floor in
                let filteredRooms = filterRoomsByFloorAndColor(
                    floor: floor, 
                    selectedFilter: selectedFilter
                )
                
                if !filteredRooms.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredRooms) { room in
                            createRoomCell(for: room)
                                .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                    .centeredWithPadding()
                }
            }
        }
    }
    
    private func buildFloorsSection() -> some View {
        Group {
            VStack(spacing: 15) {
                // Добавляем блок статистики над списком комнат
                StatisticsCompactView(viewModel: viewModel)
                    .centeredWithPadding()
                    .animation(.none, value: viewModel.rooms)
                    .frame(height: 230)
                    .layoutPriority(1)
                
                Spacer(minLength: 30)
                
                // Используем соответствующую раскладку в зависимости от настроек
                if isListViewMode {
                    createColorFilteredListView()
                } else if isVerticalLayout {
                    createVerticalLayout()
                } else {
                    createHorizontalLayout()
                }
            }
        }
        .animation(.none, value: viewModel.rooms)
    }
    
    // Создает представление со списком комнат отфильтрованных по цвету
    private func createColorFilteredListView() -> some View {
        let filteredRooms = viewModel.visibleRooms.filter { room in
            if let color = selectedListColor {
                if color == .green {
                    // Для зеленого индикатора показываем и зеленые, и синие комнаты
                    return room.color == .green || room.color == .blue
                } else {
                    return room.color == color
                }
            }
            return false
        }.sorted { $0.number < $1.number }
        
        return ScrollView {
            VStack(spacing: 8) {
                // Показываем заголовок с названием выбранного цвета
                Text(getColorNameForList(selectedListColor))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                if filteredRooms.isEmpty {
                    Text(viewModel.getTranslation(for: "noRoomsWithColor"))
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(filteredRooms) { room in
                        colorFilteredRoomRow(room: room)
                    }
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .centeredWithPadding()
    }
    
    // Получает название выбранного цвета для заголовка списка
    private func getColorNameForList(_ color: Room.RoomColor?) -> String {
        guard let color = color else { return "" }
        
        switch color {
        case .none:
            return viewModel.getTranslation(for: "colorYellow")
        case .red:
            return viewModel.getTranslation(for: "colorRed")
        case .green:
            return viewModel.getTranslation(for: "colorGreen") + " & " + viewModel.getTranslation(for: "colorBlue")
        case .blue:
            return viewModel.getTranslation(for: "colorBlue")
        case .purple:
            return viewModel.getTranslation(for: "colorPurple")
        case .white:
            return viewModel.getTranslation(for: "colorWhite")
        }
    }
    
    // Создает строку для одной комнаты в режиме списка с цветовой фильтрацией
    private func colorFilteredRoomRow(room: Room) -> some View {
        HStack {
            Text(room.number)
                .font(.title3)
                .bold()
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            if let timestamp = getRelevantTimestamp(for: room) {
                Text(formatTimestamp(timestamp))
                    .font(.system(size: 16))
            } else {
                Text("--:--")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                if let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) {
                    selectedRoom = viewModel.rooms[index]
                    toggleRoomStatus(viewModel.rooms[index])
                }
            }) {
                Circle()
                    .fill(getColorForRoom(room))
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    // Возвращает соответствующую временную метку для комнаты в зависимости от ее цвета
    private func getRelevantTimestamp(for room: Room) -> Date? {
        switch room.color {
        case .none:
            return room.noneTimestamp
        case .red:
            return room.redTimestamp
        case .green:
            return room.greenTimestamp
        case .blue:
            return room.blueTimestamp
        case .purple:
            if let timeString = room.availableTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return formatter.date(from: timeString)
            }
            return nil
        case .white:
            return room.whiteTimestamp
        }
    }
    
    // Форматирует временную метку в удобочитаемый формат
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Возвращает цвет для отображения в списке
    private func getColorForRoom(_ room: Room) -> Color {
        switch room.color {
        case .none:
            return Color(red: 1.0, green: 0.85, blue: 0.0) // Яркий желтый
        case .red:
            return Color(red: 1.0, green: 0.15, blue: 0.15) // Яркий красный
        case .green:
            return Color(red: 0.0, green: 0.95, blue: 0.2) // Сочный зеленый
        case .blue:
            return Color(red: 0.0, green: 0.45, blue: 1.0) // Насыщенный синий
        case .purple:
            return Color(red: 0.85, green: 0.2, blue: 1.0) // Яркий фиолетовый
        case .white:
            return Color.white
        }
    }
    
    // MARK: - Actions
    
    private func handleRoomNumberInput(_ text: String) {
        // Обрабатываем случай с Enter (обратная совместимость)
        if text.hasSuffix("\n") {
            processRoomNumber(text.trimmingCharacters(in: .whitespacesAndNewlines))
            return
        }
        
        // Проверяем, что текст содержит только цифры
        let numbersOnly = text.filter { $0.isNumber }
        
        // Если ввели 3 цифры - автоматически добавляем комнату
        if numbersOnly.count == 3 {
            processRoomNumber(numbersOnly)
        }
    }
    
    private func processRoomNumber(_ roomNumber: String) {
        if !roomNumber.isEmpty {
            // Сохраняем состояние до добавления комнаты для истории
            let roomsBeforeAdd = viewModel.rooms
            
            if let error = viewModel.addRoom(number: roomNumber) {
                toastMessage = error
                showToast = true
            } else {
                // Записываем действие добавления комнаты в историю
                ActionHistoryManager.shared.recordAddRoom(
                    roomNumber: roomNumber,
                    rooms: roomsBeforeAdd // Передаем состояние ДО добавления
                )
                
                print("DEBUG: Добавлена запись о создании комнаты \(roomNumber) в историю действий")
                
                // Обновляем статистику без анимации
                updateStats()
            }
        }
        
        enteredRoomNumber = ""
        hideKeyboard()
    }
    
    private func setRoomTime() {
        if let index = viewModel.rooms.firstIndex(where: { $0.id == selectedRoom?.id }) {
            // Форматируем выбранное время
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let formattedTime = formatter.string(from: selectedTime)
            
            // Сохраняем предыдущее состояние для истории действий
            let prevRooms = viewModel.rooms
            
            // Сохраняем время в комнате
            viewModel.rooms[index].availableTime = formattedTime
            
            // Если цвет комнаты не фиолетовый, меняем его
            if viewModel.rooms[index].color != .purple {
                viewModel.rooms[index].color = .purple
            }
            
            // ЗАПИСЫВАЕМ ТОЛЬКО ОДНО ДЕЙСТВИЕ - установка времени
            // Действие автоматически включает изменение цвета на фиолетовый
            ActionHistoryManager.shared.recordAddTime(
                roomNumber: viewModel.rooms[index].number,
                time: selectedTime,
                rooms: prevRooms
            )
            
            // Обновляем статистику без анимации
            updateStats()
        }
        activeSheet = nil
    }
    
    // Функция для обновления статистики без анимации
    private func updateStats() {
        // Отключаем анимацию при сохранении, чтобы избежать дергания экрана
        withAnimation(.none) {
            viewModel.saveRooms()
        }
    }
    
    private func toggleRoomStatus(_ room: Room) {
        provideHapticFeedback()
        // Проверка условий
        if isLocked || room.isCompletedBefore930 {
            return
        }
        // Старый режим циклической смены цветов: жёлтый, красный, зелёный, синий
        if useOldColorTap {
            guard let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) else { return }
            let currentColor = viewModel.rooms[index].color
            let now = Date()
            let cycle: [Room.RoomColor] = [.none, .red, .green, .blue]
            // Определяем следующий цвет в цикле
            guard let idx = cycle.firstIndex(of: currentColor) else { return }
            let nextColor = cycle[(idx + 1) % cycle.count]
            // Применяем цвет и обновляем метки/времена
            viewModel.rooms[index].color = nextColor
            // Устанавливаем timestamp для red/green
            switch nextColor {
            case .none:
                viewModel.rooms[index].noneTimestamp = now
            case .red:
                viewModel.rooms[index].redTimestamp = now
                if !disableClipboard && enableRedClipboard {
                    let formatted = formatTimeInAmericanStyle(now)
                    var text = String(format: redMessageTemplate, viewModel.rooms[index].number, formatted)
                    if includeSpanish { text += " / " + String(format: redMessageTemplateES, viewModel.rooms[index].number, formatted) }
                    UIPasteboard.general.string = text
                }
            case .green:
                viewModel.rooms[index].greenTimestamp = now
                if !disableClipboard && enableGreenClipboard {
                    let formatted = formatTimeInAmericanStyle(now)
                    var text = String(format: greenMessageTemplate, viewModel.rooms[index].number, formatted)
                    if includeSpanish { text += " / " + String(format: greenMessageTemplateES, viewModel.rooms[index].number, formatted) }
                    UIPasteboard.general.string = text
                }
            case .blue:
                viewModel.rooms[index].blueTimestamp = now
                // При переходе на синий очищаем дополнительные поля
                viewModel.rooms[index].availableTime = nil
                // Не очищаем timestamp'ы при переходе на синий
            default:
                break
            }
            // Записываем изменение цвета в историю
            ActionHistoryManager.shared.recordColorChange(
                roomNumber: viewModel.rooms[index].number,
                prevColor: currentColor,
                newColor: nextColor,
                rooms: viewModel.rooms
            )
            // Сохраняем и обновляем статистику
            updateStats()
            // Звук переключения
            SoundManager.shared.playSound(for: .toggleStatus)
            return
        }
        // Обычная логика смены цвета (с учётом фиолетового)
        if let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) {
            let currentColor = viewModel.rooms[index].color
            let now = Date()
            
            // Сохраняем предыдущий цвет для записи в историю
            let prevColor = viewModel.rooms[index].color
            var newColor: Room.RoomColor = .none
            
            if currentColor == .none || (useOldColorTap ? currentColor == .blue : currentColor == .purple) {
                newColor = .red
                viewModel.rooms[index].color = newColor
                viewModel.rooms[index].redTimestamp = now
                
                // Форматируем время в американском формате (AM/PM)
                let formattedTime = formatTimeInAmericanStyle(now)
                
                if !disableClipboard && enableRedClipboard {
                    // Копируем номер комнаты с сообщением и временем в буфер обмена
                    let roomNumber = viewModel.rooms[index].number
                    var clipboardText = String(format: redMessageTemplate, roomNumber, formattedTime)
                    
                    // Если включен испанский язык, добавляем перевод
                    if includeSpanish {
                        clipboardText += " / " + String(format: redMessageTemplateES, roomNumber, formattedTime)
                    }
                    
                    UIPasteboard.general.string = clipboardText
                }
            } else if currentColor == .red {
                newColor = .green
                viewModel.rooms[index].color = newColor
                viewModel.rooms[index].greenTimestamp = now
                
                if !disableClipboard && enableGreenClipboard {
                    // Форматируем время в американском формате (AM/PM)
                    let formattedTime = formatTimeInAmericanStyle(now)
                    
                    // Копируем номер комнаты с сообщением и временем в буфер обмена
                    let roomNumber = viewModel.rooms[index].number
                    var clipboardText = String(format: greenMessageTemplate, roomNumber, formattedTime)
                    
                    // Если включен испанский язык, добавляем перевод
                    if includeSpanish {
                        clipboardText += " / " + String(format: greenMessageTemplateES, roomNumber, formattedTime)
                    }
                    
                    UIPasteboard.general.string = clipboardText
                }
            } else if currentColor == .green {
                newColor = .blue
                viewModel.rooms[index].color = newColor
                viewModel.rooms[index].blueTimestamp = now
            } else if currentColor == .blue {
                newColor = .none
                viewModel.rooms[index].color = newColor
                viewModel.rooms[index].noneTimestamp = now
                viewModel.rooms[index].availableTime = nil
                // Не очищаем предыдущие timestamp'ы при переходе на желтый
            }
            
            // Если новый цвет белый, сбрасываем метку
            if newColor == .white {
                // Сохраняем предыдущее состояние метки для истории
                if viewModel.rooms[index].isMarked {
                    let beforeMarkState = viewModel.rooms
                    viewModel.rooms[index].isMarked = false
                    let afterMarkState = viewModel.rooms
                    ActionHistoryManager.shared.recordUnmark(
                        roomNumber: viewModel.rooms[index].number,
                        beforeState: beforeMarkState,
                        afterState: afterMarkState
                    )
                } else {
                    viewModel.rooms[index].isMarked = false
                }
            }
            
            // Записываем действие в историю
            recordFilterChange(
                name: viewModel.rooms[index].number,
                prevFilter: prevColor,
                newFilter: newColor
            )
            
            // Обновляем статистику без анимации
            updateStats()
            
            // Воспроизводим звук в зависимости от нового цвета
            let soundType: SoundManager.SoundType = newColor == .red ? .toggleStatus :
                                                 newColor == .green ? .toggleStatus :
                                                 newColor == .blue ? .toggleStatus :
                                                 .toggleStatus
            SoundManager.shared.playSound(for: soundType)
        }
    }
    
    private func deleteRoom(_ room: Room) {
        if let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) {
            // Сохраняем данные перед удалением для истории
            let roomNumber = viewModel.rooms[index].number
            let prevColor = viewModel.rooms[index].color
            let prevRooms = viewModel.rooms
            let roomId = viewModel.rooms[index].id.uuidString
            
            // 🔥 ИСПРАВЛЕНО: СНАЧАЛА удаляем из Firebase
            Task {
                do {
                    try await FirebaseManager.shared.deleteRoom(roomId)
                    print("✅ Комната \(roomNumber) удалена из Firebase")
                    
                    // ЗАТЕМ удаляем локально БЕЗ СИНХРОНИЗАЦИИ (в главном потоке)
                    await MainActor.run {
                        // Записываем действие удаления в историю
                        ActionHistoryManager.shared.recordDeleteRoom(
                            roomNumber: roomNumber,
                            prevColor: prevColor,
                            rooms: prevRooms
                        )
                        
                        // Удаляем комнату локально
                        if let currentIndex = viewModel.rooms.firstIndex(where: { $0.id == room.id }) {
                            viewModel.rooms.remove(at: currentIndex)
                        }
                        
                        // 🔥 ИСПРАВЛЕНО: Сохраняем только локально, БЕЗ Firebase синхронизации
                        viewModel.saveRoomsLocally() // Вместо updateStats() или saveRooms()
                    }
                } catch {
                    print("❌ Ошибка удаления комнаты \(roomNumber) из Firebase: \(error)")
                }
            }
        }
    }
    
    private func markRoom(_ room: Room) {
        // Не позволяем отмечать белые комнаты
        if room.color == .white {
            return
        }
        
        if let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) {
            let beforeState = viewModel.rooms // Сохраняем состояние ДО изменения
            
            viewModel.rooms[index].isMarked.toggle()
            let isNowMarked = viewModel.rooms[index].isMarked
            let afterState = viewModel.rooms // Состояние ПОСЛЕ изменения
            
            if isNowMarked {
                ActionHistoryManager.shared.recordMark(
                    roomNumber: viewModel.rooms[index].number,
                    beforeState: beforeState,
                    afterState: afterState
                )
                // Запускаем оптимизированную анимацию пометки
                if room.color != .white {
                    PhysicsManager.shared.startChaos()
                    // Оптимизированное время из конфигурации для 120fps производительности
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConfiguration.Performance.markEffectDuration) {
                        PhysicsManager.shared.stopChaos()
                    }
                }
            } else {
                ActionHistoryManager.shared.recordUnmark(
                    roomNumber: viewModel.rooms[index].number,
                    beforeState: beforeState,
                    afterState: afterState
                )
                // Можно добавить аналогичный запуск анимации и для снятия метки, если нужно
            }
            
            updateStats()
        }
    }
    
    private func setTimeForRoom(_ room: Room) {
        selectedRoom = room
        activeSheet = .timePicker
    }
    
    // MARK: - Вспомогательные методы
    
    private func formatTimeInAmericanStyle(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a" // Формат часы:минуты AM/PM
        timeFormatter.locale = Locale(identifier: "en_US")
        return timeFormatter.string(from: date)
    }
    
    // Функция отмены последнего действия - УПРОЩЕННАЯ И ЧЕТКАЯ!
    private func undoLastAction() {
        guard let lastAction = actionHistoryManager.getLastAction() else { 
            print("❌ Нет действий для отмены!")
            return 
        }
        
        // Новая система работает ПРОСТО: восстанавливаем предыдущее состояние
        if let previousState = actionHistoryManager.getPreviousRoomsState() {
            viewModel.rooms = previousState
            viewModel.saveRooms()
            
            // Удаляем действие из истории
            actionHistoryManager.removeLastAction()
            
            // Показываем уведомление о выполненной отмене
            toastMessage = "⏪ Отменено: \(lastAction.description)"
            showToast = true
            
            print("✅ ОТМЕНА ВЫПОЛНЕНА: \(lastAction.description)")
        } else {
            print("❌ Не удалось получить предыдущее состояние для отмены")
        }
    }
    
    private func handleScrollChange(value: CGFloat) {
        // Упрощенная логика обработки скролла для iOS 16
        // Определяем, когда баннер начинает соприкасаться с верхней панелью
        if value < -60 {
            // Применяем размытие, когда скроллим достаточно вверх
            NavigationBarManager.shared.applyBlurredAppearance()
        } else {
            // Оставляем меню прозрачным в остальных случаях
            NavigationBarManager.shared.applyTransparentAppearance()
        }
    }
    
    // MARK: - Для организации контента и поддержки истории

    private struct ColorCount: Identifiable {
        let id = UUID()
        let color: Room.RoomColor
        let count: Int
        let backgroundColor: Color
        let textColor: Color
    }
    
    private func getSortedColorCounts() -> [ColorCount] {
        let counts = [
            ColorCount(
                color: .none,
                count: viewModel.visibleRooms.filter { $0.color == .none }.count,
                backgroundColor: Color(red: 1.0, green: 0.85, blue: 0.0), // Яркий желтый
                textColor: .black
            ),
            ColorCount(
                color: .red,
                count: viewModel.visibleRooms.filter { $0.color == .red }.count,
                backgroundColor: Color(red: 1.0, green: 0.15, blue: 0.15), // Яркий красный
                textColor: .white
            ),
            ColorCount(
                color: .green,
                count: viewModel.visibleRooms.filter { $0.color == .green || $0.color == .blue }.count,
                backgroundColor: Color(red: 0.0, green: 0.95, blue: 0.2), // Сочный зеленый
                textColor: .black
            ),
            ColorCount(
                color: .purple,
                count: viewModel.visibleRooms.filter { $0.color == .purple }.count,
                backgroundColor: Color(red: 0.85, green: 0.2, blue: 1.0), // Яркий фиолетовый
                textColor: .white
            )
        ]
        
        return counts.sorted { $0.count < $1.count }
    }
    
    // Вспомогательный метод для записи изменений фильтров и настроек отображения
    private func recordFilterChange(name: String, prevFilter: Room.RoomColor?, newFilter: Room.RoomColor?) {
        var description = ""
        
        if name == "layout" {
            description = isVerticalLayout ? "Переключен на вертикальный layout" : "Переключен на горизонтальный layout"
        } else if let prevColor = prevFilter, let newColor = newFilter {
            let prevName = colorName(prevColor)
            let newName = colorName(newColor)
            description = "Фильтр: \(prevName) → \(newName)"
        } else if let prevColor = prevFilter {
            let prevName = colorName(prevColor)
            description = "Сброшен фильтр: \(prevName)"
        } else if let newColor = newFilter {
            let newName = colorName(newColor)
            description = "Установлен фильтр: \(newName)"
        } else {
            if name == "viewMode" {
                description = isRoundedView ? "Включен округлый вид" : "Выключен округлый вид"
            } else {
                description = "Изменены настройки отображения"
            }
        }
        
        ActionHistoryManager.shared.recordFilterChange(
            name: name,
            description: description,
            rooms: viewModel.rooms
        )
    }
    
    private func colorName(_ color: Room.RoomColor) -> String {
        switch color {
        case .none: return "Не назначен"
        case .red: return "Красный"
        case .green: return "Зеленый"
        case .blue: return "Синий"
        case .purple: return "Фиолетовый"
        case .white: return "Белый"
        }
    }
    
    // Функция для удаления установленного времени
    private func removeTimeFromRoom(room: Room) {
        if let index = viewModel.rooms.firstIndex(where: { $0.id == room.id }) {
            if let timeToRemove = viewModel.rooms[index].availableTime {
                // Сохраняем предыдущее состояние для истории действий
                let prevRooms = viewModel.rooms
                let prevColor = viewModel.rooms[index].color
                
                // Создаем дату из строки времени для истории
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let prevTime = formatter.date(from: timeToRemove) ?? Date()
                
                // Удаляем время и меняем цвет на "none"
                viewModel.rooms[index].availableTime = nil
                viewModel.rooms[index].color = .none
                
                // Записываем действие удаления времени в историю
                ActionHistoryManager.shared.recordRemoveTime(
                    roomNumber: viewModel.rooms[index].number,
                    prevTime: prevTime,
                    rooms: prevRooms
                )
                
                // Записываем действие изменения цвета в историю
                ActionHistoryManager.shared.recordColorChange(
                    roomNumber: viewModel.rooms[index].number,
                    prevColor: prevColor,
                    newColor: .none,
                    rooms: prevRooms
                )
                
                // Обновляем статистику без анимации
                updateStats()
            }
        }
    }
    
    // Парсит строку времени в Date (поддержка различных форматов)
    private func parseTimeString(_ s: String) -> Date? {
        let formats = ["HH:mm:ss", "H:mm:ss", "HH:mm", "H:mm", "h:mm a"]
        for format in formats {
            let df = DateFormatter()
            df.dateFormat = format
            if let d = df.date(from: s) {
                return d
            }
        }
        return nil
    }
    
    // Импортирует список комнат из буфера обмена и устанавливает время, если указано
    private func importRoomsFromClipboard() {
        guard let clipboard = UIPasteboard.general.string else { return }
        let lines = clipboard.split(whereSeparator: \.isNewline) 
        let outputFormatter = DateFormatter()
        outputFormatter.timeStyle = .short
        var importedCount = 0
        
        let initialRoomsSnapshot = viewModel.rooms 
        var roomsToAdd: [Room] = []
        var roomsToUpdateDetails: [(originalRoom: Room, timeToSet: Date?, newColorCandidate: Room.RoomColor?)] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) 
            guard !line.isEmpty else { continue }
            let tokens = line.split(whereSeparator: { $0.isWhitespace || $0 == "\t" }).map { String($0) }
            guard let numberToken = tokens.first(where: { $0.range(of: "^[1-5]\\d{2}$", options: String.CompareOptions.regularExpression) != nil }) else { continue } 
            let number = numberToken
            let timeToken = tokens.first(where: { $0.contains(":") })
            let timeDate = timeToken.flatMap { parseTimeString($0) }

            if let existingRoom = initialRoomsSnapshot.first(where: { $0.number == number }) {
                if timeDate != nil {
                    roomsToUpdateDetails.append((originalRoom: existingRoom, timeToSet: timeDate, newColorCandidate: .purple))
                }
            } else {
                var newRoom = Room(number: number)
                if let time = timeDate {
                    newRoom.availableTime = outputFormatter.string(from: time)
                    newRoom.color = .purple
                }
                roomsToAdd.append(newRoom)
            }
        }

        var workingRoomsCopy = viewModel.rooms

        for details in roomsToUpdateDetails {
            if let indexInWorkingCopy = workingRoomsCopy.firstIndex(where: { $0.id == details.originalRoom.id }) {
                var changed = false
                if let timeToSet = details.timeToSet {
                    let newTimeStr = outputFormatter.string(from: timeToSet)
                    if workingRoomsCopy[indexInWorkingCopy].availableTime != newTimeStr {
                        workingRoomsCopy[indexInWorkingCopy].availableTime = newTimeStr
                        changed = true
                        ActionHistoryManager.shared.recordAddTime(
                            roomNumber: details.originalRoom.number,
                            time: timeToSet,
                            rooms: initialRoomsSnapshot)
                    }
                }
                if let newColor = details.newColorCandidate, workingRoomsCopy[indexInWorkingCopy].color != newColor {
                    let oldColor = workingRoomsCopy[indexInWorkingCopy].color
                    workingRoomsCopy[indexInWorkingCopy].color = newColor
                    changed = true
                    ActionHistoryManager.shared.recordColorChange(
                        roomNumber: details.originalRoom.number,
                        prevColor: oldColor,
                        newColor: newColor,
                        rooms: initialRoomsSnapshot)
                }
                if changed {
                    importedCount += 1
                }
            }
        }

        if !roomsToAdd.isEmpty {
            for newRoom in roomsToAdd {
                if !workingRoomsCopy.contains(where: { $0.number == newRoom.number }) {
                    workingRoomsCopy.append(newRoom)
                    ActionHistoryManager.shared.recordAddRoom(
                        roomNumber: newRoom.number,
                        rooms: initialRoomsSnapshot) 

                    if newRoom.color == .purple, let timeString = newRoom.availableTime, let timeDate = parseTimeString(timeString) {
                         ActionHistoryManager.shared.recordAddTime(
                            roomNumber: newRoom.number,
                            time: timeDate,
                            rooms: initialRoomsSnapshot)
                    }
                    importedCount += 1
                }
            }
        }
        
        viewModel.rooms = workingRoomsCopy
        
        var floorsToActivate = Set<Int>()
        for roomNumber in roomsToAdd.map({ $0.number }) + roomsToUpdateDetails.map({ $0.originalRoom.number }) {
            if let floor = AppConfiguration.Rooms.extractFloor(from: roomNumber) {
                if !floorManager.isFloorActive(floor) {
                    floorsToActivate.insert(floor)
                }
            }
        }
        
        if !floorsToActivate.isEmpty {
            let beforeFloorChangeSnapshot = viewModel.rooms 
            for floor in floorsToActivate {
                floorManager.enableFloor(floor)
            }
            SimpleHistoryManager.shared.recordSystemChange(
                "Активированы этажи: \(floorsToActivate.sorted().map { String($0) }.joined(separator: ", ")) из-за импорта",
                before: beforeFloorChangeSnapshot, 
                after: viewModel.rooms 
            )
        }

        viewModel.saveRooms()
        
        toastMessage = "Импортировано \(importedCount) комнат"
        showToast = true
    }
    
    // Функция для сохранения изображения
    private func saveBackgroundImage() {
        if let backgroundImage = backgroundImage,
           let imageData = backgroundImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(imageData, forKey: "backgroundImageData")
        }
    }
    
    // Функция для загрузки изображения
    private func loadBackgroundImage() {
        if let imageData = UserDefaults.standard.data(forKey: "backgroundImageData") {
            backgroundImage = UIImage(data: imageData)
        }
    }
    
    // MARK: - Методы для фонового видео
    
    private func saveBackgroundVideoURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "backgroundVideoPath")
    }
    
    private func loadBackgroundVideo() {
        if let path = UserDefaults.standard.string(forKey: "backgroundVideoPath") {
            // Сначала проверяем, существует ли файл по сохраненному пути
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path) // Теперь 'url' создается только если файл существует и будет использован
                backgroundVideoURL = url
                setupVideoPlayer(url: url)
                return // Если есть сохраненное видео, используем его
            }
        }
        // Если нет сохраненного видео (или файл по пути не найден), пытаемся загрузить встроенное
        if let bundledURL = bundledVideoURL {
            backgroundVideoURL = bundledURL
            setupVideoPlayer(url: bundledURL)
        }
    }
    
    private func setupVideoPlayer(url: URL) {
        let queuePlayer = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        queuePlayer.play()
        loopingPlayer = queuePlayer
        playerLooper = looper
        // Наблюдатели за состоянием приложения
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            self.loopingPlayer?.play()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            self.loopingPlayer?.pause()
        }
    }
    
    // Удаление видео-фона
    private func clearBackgroundVideo() {
        loopingPlayer?.pause()
        loopingPlayer = nil
        playerLooper = nil
        backgroundVideoURL = nil
        selectedVideoItem = nil // Сбрасываем PhotosPickerItem для видео
        UserDefaults.standard.removeObject(forKey: "backgroundVideoPath")
        // backgroundImage = nil // УДАЛЕНО: Эта функция не должна влиять на фото-фон

        // Если после очистки пользовательского видео, мы хотим вернуться к встроенному видео по умолчанию:
        // loadBundledVideoAsBackground() // Раскомментируйте, если нужно такое поведение
    }
    
    // Новая функция для установки встроенного видео как фона
    private func setBundledVideoAsBackground() {
        guard let url = bundledVideoURL else { return }
        // Очищаем фото-фон
        self.backgroundImage = nil
        self.selectedImageItem = nil
        UserDefaults.standard.removeObject(forKey: "backgroundImageData")

        // Очищаем пользовательское видео-фон (если было)
        UserDefaults.standard.removeObject(forKey: "backgroundVideoPath")
        self.selectedVideoItem = nil

        // Устанавливаем встроенное видео
        self.backgroundVideoURL = url
        setupVideoPlayer(url: url)
        // Нет необходимости вызывать saveBackgroundVideoURL для встроенного видео,
        // так как оно всегда доступно из бандла.
    }
    
    // MARK: - Обработчик действий FloatingMenu
    private func handleFloatingMenuAction(_ action: FloatingMenuAction) {
        switch action {
        case .changeColor(let newColor):
            changeRoomColorFromMenu(newColor)
        case .toggleMark:
            toggleMarkFromMenu()
        case .toggleDeepClean:
            toggleDeepCleanFromMenu()
        case .setTime:
            setTimeFromMenu()
        case .delete:
            deleteRoomFromMenu()
        case .toggleBefore930:
            toggleBefore930FromMenu()
        }
    }
    
    private func changeRoomColorFromMenu(_ roomColor: Room.RoomColor) {
        guard let activeRoom = FloatingMenuManager.shared.activeRoom,
              let index = viewModel.rooms.firstIndex(where: { $0.id == activeRoom.id }) else { return }
        
        provideHapticFeedback()
        FloatingMenuManager.shared.hideMenu()
        
        // Сохраняем предыдущий цвет для истории и изменяем цвет комнаты
        let prevColor = viewModel.rooms[index].color
        viewModel.rooms[index].color = roomColor
        
        // Если новый цвет не фиолетовый, сбрасываем время
        if roomColor != .purple {
            viewModel.rooms[index].availableTime = nil
        }
        
        // Если это переход из/в синий/зеленый/желтый, обрабатываем таймстемпы
        if roomColor == .none {
            viewModel.rooms[index].noneTimestamp = Date()
        }
        if roomColor == .green {
            viewModel.rooms[index].greenTimestamp = Date()
            if !disableClipboard && enableGreenClipboard {
                setClipboardMessage(for: viewModel.rooms[index], color: .green)
            }
        }
        if roomColor == .blue {
            viewModel.rooms[index].blueTimestamp = Date()
        }
        if roomColor == .red {
            viewModel.rooms[index].redTimestamp = Date()
            if !disableClipboard && enableRedClipboard {
                setClipboardMessage(for: viewModel.rooms[index], color: .red)
            }
        }
        if roomColor == .white {
            viewModel.rooms[index].whiteTimestamp = Date()
        }
        
        // Записываем действие изменения цвета в историю
        ActionHistoryManager.shared.recordColorChange(
            roomNumber: viewModel.rooms[index].number,
            prevColor: prevColor,
            newColor: roomColor,
            rooms: viewModel.rooms
        )
        
        // Воспроизводим звук в зависимости от нового цвета
        let soundType: SoundManager.SoundType = roomColor == .red ? .toggleStatus :
                                             roomColor == .green ? .toggleStatus :
                                             roomColor == .blue ? .toggleStatus :
                                             .toggleStatus
        SoundManager.shared.playSound(for: soundType)
        
        // Сохраняем изменения
        viewModel.saveRooms()
    }
    
    private func toggleMarkFromMenu() {
        guard let activeRoom = FloatingMenuManager.shared.activeRoom,
              let index = viewModel.rooms.firstIndex(where: { $0.id == activeRoom.id }) else { return }
        
        provideHapticFeedback()
        FloatingMenuManager.shared.hideMenu()
        
        let beforeState = viewModel.rooms // Сохраняем состояние ДО изменения
        viewModel.rooms[index].isMarked.toggle()
        let afterState = viewModel.rooms // Состояние ПОСЛЕ изменения
        
        // Записываем в историю
        if viewModel.rooms[index].isMarked {
            ActionHistoryManager.shared.recordMark(
                roomNumber: viewModel.rooms[index].number,
                beforeState: beforeState,
                afterState: afterState
            )
        } else {
            ActionHistoryManager.shared.recordUnmark(
                roomNumber: viewModel.rooms[index].number,
                beforeState: beforeState,
                afterState: afterState
            )
        }
        
        // Воспроизводим звук
        SoundManager.shared.playSound(for: .toggleStatus)
        
        viewModel.saveRooms()
    }
    
    private func toggleDeepCleanFromMenu() {
        guard let activeRoom = FloatingMenuManager.shared.activeRoom,
              let index = viewModel.rooms.firstIndex(where: { $0.id == activeRoom.id }) else { return }
        
        provideHapticFeedback()
        FloatingMenuManager.shared.hideMenu()
        
        let beforeState = viewModel.rooms // Сохраняем состояние ДО изменения
        viewModel.rooms[index].isDeepCleaned.toggle()
        let afterState = viewModel.rooms // Состояние ПОСЛЕ изменения
        
        // Записываем в историю
        if viewModel.rooms[index].isDeepCleaned {
            ActionHistoryManager.shared.recordMarkDeepClean(
                roomNumber: viewModel.rooms[index].number,
                beforeState: beforeState,
                afterState: afterState
            )
        } else {
            ActionHistoryManager.shared.recordUnmarkDeepClean(
                roomNumber: viewModel.rooms[index].number,
                beforeState: beforeState,
                afterState: afterState
            )
        }
        
        // Воспроизводим звук
        SoundManager.shared.playSound(for: .toggleStatus)
        
        viewModel.saveRooms()
    }
    
    private func setTimeFromMenu() {
        guard let activeRoom = FloatingMenuManager.shared.activeRoom else { return }
        
        FloatingMenuManager.shared.hideMenu()
        selectedRoom = activeRoom
        
        // Воспроизводим звук
        SoundManager.shared.playSound(for: .toggleStatus)
        
        activeSheet = .timePicker
    }
    
    private func deleteRoomFromMenu() {
        guard let activeRoom = FloatingMenuManager.shared.activeRoom,
              let _ = viewModel.rooms.firstIndex(where: { $0.id == activeRoom.id }) else { return }
        
        provideHapticFeedback()
        FloatingMenuManager.shared.hideMenu()
        
        let roomId = activeRoom.id.uuidString
        let roomNumber = activeRoom.number
        let prevColor = activeRoom.color
        let prevRooms = viewModel.rooms
        
        // 🔥 ИСПРАВЛЕНО: СНАЧАЛА удаляем из Firebase
        Task {
            do {
                try await FirebaseManager.shared.deleteRoom(roomId)
                print("✅ Комната \(roomNumber) удалена из Firebase (меню)")
                
                // ЗАТЕМ удаляем локально БЕЗ СИНХРОНИЗАЦИИ (в главном потоке)
                await MainActor.run {
                    // Записываем действие удаления в историю
                    ActionHistoryManager.shared.recordDeleteRoom(
                        roomNumber: roomNumber,
                        prevColor: prevColor,
                        rooms: prevRooms
                    )
                    
                    // Воспроизводим звук
                    SoundManager.shared.playSound(for: .toggleStatus)
                    
                    // Удаляем комнату локально
                    if let currentIndex = viewModel.rooms.firstIndex(where: { $0.id == activeRoom.id }) {
                        viewModel.rooms.remove(at: currentIndex)
                    }
                    
                    // 🔥 ИСПРАВЛЕНО: Сохраняем только локально, БЕЗ Firebase синхронизации  
                    viewModel.saveRoomsLocally() // Вместо viewModel.saveRooms()
                }
            } catch {
                print("❌ Ошибка удаления комнаты \(roomNumber) из Firebase (меню): \(error)")
            }
        }
    }
    
    private func toggleBefore930FromMenu() {
        guard let activeRoom = FloatingMenuManager.shared.activeRoom,
              let index = viewModel.rooms.firstIndex(where: { $0.id == activeRoom.id }) else { return }
        
        provideHapticFeedback()
        FloatingMenuManager.shared.hideMenu()
        
        let prevColor = viewModel.rooms[index].color
        
        if viewModel.rooms[index].color == .white {
            // Если комната белая, возвращаем к желтому и убираем флаг "сделано до 9:30"
            viewModel.rooms[index].color = .none
            viewModel.rooms[index].noneTimestamp = Date()
            viewModel.rooms[index].isCompletedBefore930 = false
            
            // Записываем действие в историю - разблокировка
            ActionHistoryManager.shared.recordColorChange(
                roomNumber: viewModel.rooms[index].number,
                prevColor: .white,
                newColor: .none,
                rooms: viewModel.rooms
            )
        } else {
            // Если комната не белая, делаем её белой и ставим флаг "сделано до 9:30"
            viewModel.rooms[index].color = .white
            viewModel.rooms[index].isCompletedBefore930 = true
            viewModel.rooms[index].whiteTimestamp = Date() // Устанавливаем время для белой ячейки
            
            // СБРАСЫВАЕМ ВСЕ НАСТРОЙКИ кроме whiteTimestamp при установке "сделано до 9:30"
            viewModel.rooms[index].availableTime = nil
            viewModel.rooms[index].redTimestamp = nil
            viewModel.rooms[index].greenTimestamp = nil
            viewModel.rooms[index].blueTimestamp = nil
            viewModel.rooms[index].noneTimestamp = nil
            viewModel.rooms[index].isMarked = false
            viewModel.rooms[index].isDeepCleaned = false
            
            // Записываем действие в историю - блокировка
            ActionHistoryManager.shared.recordColorChange(
                roomNumber: viewModel.rooms[index].number,
                prevColor: prevColor,
                newColor: .white,
                rooms: viewModel.rooms
            )
        }
        
        // Воспроизводим звук
        SoundManager.shared.playSound(for: .toggleStatus)
        
        viewModel.saveRooms()
    }
    
    // MARK: - Вспомогательная функция для работы с clipboard
    private func setClipboardMessage(for room: Room, color: Room.RoomColor) {
        let now = Date()
        let formattedTime = formatTimeInAmericanStyle(now)
        
        var clipboardText = ""
        
        switch color {
        case .red:
            clipboardText = String(format: redMessageTemplate, room.number, formattedTime)
            if includeSpanish {
                clipboardText += " / " + String(format: redMessageTemplateES, room.number, formattedTime)
            }
        case .green:
            clipboardText = String(format: greenMessageTemplate, room.number, formattedTime)
            if includeSpanish {
                clipboardText += " / " + String(format: greenMessageTemplateES, room.number, formattedTime)
            }
        default:
            return // Для других цветов не устанавливаем clipboard
        }
        
        UIPasteboard.general.string = clipboardText
    }
}

// Новое расширение для View для применения режимов масштабирования
extension Image {
    @ViewBuilder
    func applyScalingMode(mode: Int, sourceImageSize: CGSize) -> some View {
        switch mode {
        case 0: // Fill
            self.scaledToFill()
        case 1: // Fit
            self.scaledToFit()
        case 2: // Stretch
            // Для Stretch мы не используем .aspectRatio, позволяя frame растянуть изображение
            self
        case 3: // Original
            // Для Original устанавливаем frame изображения равным его sourceImageSize,
            // .clipped() в вызывающем коде позаботится об обрезке если оно больше контейнера.
            // Если изображение меньше контейнера, оно будет в оригинальном размере, центрировано.
            self.frame(width: sourceImageSize.width, height: sourceImageSize.height)
        default:
            self.scaledToFill() // По умолчанию Fill
        }
    }
}
