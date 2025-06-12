import SwiftUI
import AVFoundation

// Добавляем перечисление для выбора стиля ячеек
enum CellStyle: Int, CaseIterable {
    case flat = 0       // Плоский стиль (без объема)
    case classic = 1    // Классический объемный стиль
}

struct RoomCell: View {
    let room: Room
    let toggleRoomStatus: () -> Void
    let setTime: () -> Void
    let deleteRoom: () -> Void
    let markRoom: () -> Void
    let getTranslation: (String) -> String
    let fontColor: Color
    let isLocked: Bool
    let removeTime: () -> Void
    @ObservedObject var viewModel: RoomViewModel
    @AppStorage("isRoundedView") private var isRoundedView = false
    @AppStorage("isVerticalLayout") private var isVerticalLayout = false
    @AppStorage("cellStyle") private var cellStyle: Int = 1 // По умолчанию классический стиль
    @State private var showDeleteAlert = false
    @AppStorage("useOldColorTap") private var useOldColorTap = false  // старый режим смены цвета по одному тапу
    @State private var cellFrame: CGRect = .zero

    // Подписываемся на PhysicsManager
    @ObservedObject private var physicsManager = PhysicsManager.shared

    // State переменные для более стабильных случайных факторов встряски
    @State private var chaosRandomFactorX: CGFloat = 1.0
    @State private var chaosRandomFactorY: CGFloat = 1.0
    
    // Добавляем переменную для принудительного обновления представления
    @State private var refreshID = UUID()

    var body: some View {
        buildContent()
            .crazyEffect(cellID: room.color == .white ? UUID() : room.id)
            .id(refreshID)
            .drawingGroup()
            .preferredColorScheme(.dark) // Задаем темную тему для всего View
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            cellFrame = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                            cellFrame = newFrame
                        }
                }
            )
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: AppConfiguration.Audio.menuLongPressMinDuration) {
                provideMaximumHapticFeedback()
                FloatingMenuManager.shared.showMenu(for: room, sourceFrame: cellFrame)
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text(getTranslation("deleteConfirmTitle")),
                    message: Text(String(format: getTranslation("deleteConfirmMessage"), room.number)),
                    primaryButton: .destructive(Text(getTranslation("delete"))) {
                        deleteRoom()
                    },
                    secondaryButton: .cancel(Text(getTranslation("cancel")))
                )
            }
            .onChange(of: room.isMarked) { isMarked in
                if isMarked && room.color != .white {
                    refreshID = UUID()
                }
            }
            .onChange(of: room.isDeepCleaned) { isDeepCleaned in
                if isDeepCleaned && room.color != .white {
                    refreshID = UUID()
                }
            }
    }

    private func handleTap() {
        // Блокируем взаимодействие с заблокированными и сделанными до 9:30
        guard !isLocked && !room.isCompletedBefore930 else { return }
        
        // Обновляем случайные факторы для хаоса, чтобы они изменились даже при простом тапе
        if room.color != .white {
            chaosRandomFactorX = CGFloat.random(in: 0.7...1.3)
            chaosRandomFactorY = CGFloat.random(in: 0.7...1.3)
        }
        
        // В старом режиме циклируем цвета, кроме белого и фиолетового
        if useOldColorTap {
            if room.color != .white && room.color != .purple {
                toggleRoomStatus()
            }
        }
    }

    private func buildContent() -> some View {
        let content = VStack(spacing: 1) {
            ViewThatFits(in: .vertical) {
                Text(room.number)
                    .font(.title)
                Text(room.number)
                    .font(.title2)
                Text(room.number)
                    .font(.title3)
            }
            .bold()
            .foregroundColor(room.color == .white ? .black : fontColor)
            .modifier(ConditionalPulseModifier(
                isActive: (room.color == .red && viewModel.isInLastThreeRedRooms(roomID: room.id)) ||
                          (room.color == .green && viewModel.isInLastThreeGreenRooms(roomID: room.id))
            ))
            .modifier(RotationModifier(isActive: false)) // Отключено вращение для белых ячеек
            
            // Показываем время под номером для всех цветов, включая белые
            if let timeString = getDisplayTimeForRoom(room) {
                ViewThatFits(in: .vertical) {
                    Text(timeString)
                        .font(.caption)
                    Text(timeString)
                        .font(.footnote)
                    Text(timeString)
                        .font(.system(size: 10))
                }
                .fontWeight(.semibold)
                .foregroundColor(fontColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        // Применяем объемный стиль в зависимости от настройки
        switch CellStyle(rawValue: cellStyle) ?? .classic {
        case .flat:
            return AnyView(applyFlatStyle(to: content).zebraEffect(isDeepCleaned: room.isDeepCleaned, roomColor: room.color))
        case .classic:
            return AnyView(applyClassicStyle(to: content).zebraEffect(isDeepCleaned: room.isDeepCleaned, roomColor: room.color))
        }
    }
    
    // MARK: - Стили ячеек
    
    // Плоский стиль (без объема)
    private func applyFlatStyle(to content: some View) -> some View {
        GeometryReader { geometry in
            content
                .background(
                    Group {
                        if room.color == .white {
                            Color.white
                        } else {
                            color(for: room.color)
                        }
                    }
                )
                .cornerRadius(isRoundedView ? min(geometry.size.width, geometry.size.height) / 2 : 8)
                .overlay(
                    room.isCompletedBefore930 && room.color != .white ? bottomLeftClock() : nil
                )
                .floatingMarker(isMarked: room.isMarked, roomColor: room.color)
        }
    }
    
    // Классический объемный стиль
    private func applyClassicStyle(to content: some View) -> some View {
        GeometryReader { geometry in
            content
                .background(
                    Group {
                        if room.color == .white {
                            // Для белых ячеек делаем особый градиент
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color.white.opacity(0.85)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            // Для цветных ячеек создаем градиент на основе основного цвета
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorWithBrightness(for: room.color, amount: 1.2),  // Светлее сверху
                                    color(for: room.color),                             // Основной цвет в центре
                                    colorWithBrightness(for: room.color, amount: 0.8)   // Темнее снизу
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                )
                .cornerRadius(isRoundedView ? min(geometry.size.width, geometry.size.height) / 2 : 10)
                .overlay(
                    // Добавляем внутреннюю рамку для объемности
                    RoundedRectangle(cornerRadius: isRoundedView ? min(geometry.size.width, geometry.size.height) / 2 : 10)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),    // Светлая рамка сверху
                                    Color.black.opacity(0.3)     // Темная рамка снизу
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .opacity(0.7)
                )
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: 5,
                    x: 2,
                    y: 2
                )
                .rotation3DEffect(
                    .degrees(3),
                    axis: (x: 0.5, y: 0, z: 0)
                )
                .overlay(
                    room.isCompletedBefore930 && room.color != .white ? bottomLeftClock() : nil
                )
                .floatingMarker(isMarked: room.isMarked, roomColor: room.color)
        }
    }

    private func color(for roomColor: Room.RoomColor) -> Color {
        switch roomColor {
        case .none:
            return Color(red: 1.0, green: 0.85, blue: 0.0) // Яркий желтый
        case .red:
            return Color(red: 1.0, green: 0.15, blue: 0.15) // Яркий красный
        case .green:
            return Color(red: 0.0, green: 0.95, blue: 0.2) // Сочный зеленый
        case .purple:
            return Color(red: 0.85, green: 0.2, blue: 1.0) // Яркий фиолетовый
        case .blue:
            return Color(red: 0.0, green: 0.45, blue: 1.0) // Насыщенный синий
        case .white:
            return Color.white
        }
    }

    // Функция для создания оттенка цвета с измененной яркостью
    private func colorWithBrightness(for roomColor: Room.RoomColor, amount: CGFloat) -> Color {
        let baseColor = color(for: roomColor)
        
        // Получаем UIColor для работы с компонентами
        let uiColor = UIColor(baseColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Изменяем яркость, сохраняя насыщенность
        return Color(
            red: min(1.0, red * amount),
            green: min(1.0, green * amount),
            blue: min(1.0, blue * amount)
        )
    }

    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        SoundManager.shared.playSound(for: .toggleStatus)
    }
    
    // Максимальная тактильная отдача для длинного тапа (вызов меню)
    private func provideMaximumHapticFeedback() {
        SoundManager.shared.provideMaximumHapticFeedback()
    }

    @ViewBuilder
    private func bottomLeftClock() -> some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .padding(5)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.indigo.opacity(0.8),
                                Color.purple.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Circle())
                Spacer()
            }
        }
        .padding(5)
    }

    private func chaoticOffset() -> (x: CGFloat, y: CGFloat) {
        let amplitude: CGFloat = 8.0 // Удваиваем амплитуду для более заметного эффекта
        
        // Используем сохраненные в @State случайные факторы
        let angleX = physicsManager.chaosTick * 10 * chaosRandomFactorX 
        let angleY = physicsManager.chaosTick * 10 * chaosRandomFactorY 
        
        let xOffset = sin(angleX) * amplitude
        let yOffset = cos(angleY) * amplitude 
        return (xOffset, yOffset)
    }

    // Возвращает строку времени для отображения под номером
    private func getDisplayTimeForRoom(_ room: Room) -> String? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        switch room.color {
        case .none:
            if let t = room.noneTimestamp { return formatter.string(from: t) }
        case .purple:
            return room.availableTime
        case .red:
            if let t = room.redTimestamp { return formatter.string(from: t) }
        case .green:
            if let t = room.greenTimestamp { return formatter.string(from: t) }
        case .blue:
            if let t = room.blueTimestamp { return formatter.string(from: t) }
        case .white:
            if let t = room.whiteTimestamp { return formatter.string(from: t) }
        }
        return nil
    }
}

struct GlobalPhysicsModifier: ViewModifier {
    let cellID: UUID
    func body(content: Content) -> some View {
        return content
    }
}

extension View {
    func globalPhysics(cellID: UUID) -> some View {
        self.modifier(GlobalPhysicsModifier(cellID: cellID))
    }
}

// Вращение с использованием анимации вместо TimelineView
struct SimpleRotationView<Content: View>: View {
    let content: Content
    @State private var isRotating = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
            .animation(
                Animation.linear(duration: 8)
                    .repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
    }
}

// Модификатор вращения
struct RotationModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            SimpleRotationView {
                content
            }
        } else {
            content
        }
    }
}

// Условный модификатор пульсации, который применяется только если isActive = true
struct ConditionalPulseModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.pulseEffect()
        } else {
            content
        }
    }
}

// Новый модификатор для эффекта "зебры" (диагональные полосы)
struct ZebraEffectModifier: ViewModifier {
    var isDeepCleaned: Bool
    var roomColor: Room.RoomColor
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZebraAnimationView(isActive: isDeepCleaned, roomColor: roomColor)
            )
    }
}

// Отдельное представление для анимации зебры с использованием TimelineView
struct ZebraAnimationView: View {
    var isActive: Bool
    var roomColor: Room.RoomColor
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.01, paused: !isActive)) { timeline in
            GeometryReader { geometry in
                Canvas { context, size in
                    // Только рисуем, если эффект активен
                    if isActive {
                        let stripeWidth: CGFloat = 15 // Увеличены полоски
                        let stripeSpacing: CGFloat = 18 // Увеличены промежутки
                        let totalStripePatternWidth = stripeWidth + stripeSpacing
                        let numberOfStripes = Int(ceil((size.width + size.height) / totalStripePatternWidth)) * 3
                        
                        // Вычисляем фазу на основе времени
                        let currentDate = timeline.date
                        let seconds = currentDate.timeIntervalSince1970
                        let animationSpeed: Double = 0.6 // Немного замедляем для лучшей заметности
                        let phase = CGFloat(seconds.truncatingRemainder(dividingBy: animationSpeed) / animationSpeed) * totalStripePatternWidth
                        
                        context.clip(to: Path(CGRect(origin: .zero, size: size)))
                        
                        // Выбираем цвет полос в зависимости от цвета ячейки
                        let stripeColor = getStripeColor(for: roomColor)
                        
                        for i in -numberOfStripes...numberOfStripes {
                            let xOffset = CGFloat(i) * totalStripePatternWidth - phase * totalStripePatternWidth
                            
                            var path = Path()
                            // Рисуем диагональные линии
                            path.move(to: CGPoint(x: xOffset - size.height, y: 0))
                            path.addLine(to: CGPoint(x: xOffset + stripeWidth - size.height, y: 0))
                            path.addLine(to: CGPoint(x: xOffset + stripeWidth, y: size.height))
                            path.addLine(to: CGPoint(x: xOffset, y: size.height))
                            path.closeSubpath()
                            
                            // Используем выбранный цвет с большей непрозрачностью
                            context.fill(path, with: .color(stripeColor))
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
    }
    
    // Функция для выбора цвета полос в зависимости от цвета ячейки
    private func getStripeColor(for roomColor: Room.RoomColor) -> Color {
        switch roomColor {
        case .none: // Желтый
            return Color.black.opacity(0.4) // Для желтого используем темные полосы
        case .white:
            return Color.black.opacity(0.3) // Для белого используем темные полосы
        case .red, .green, .blue, .purple:
            return Color.white.opacity(0.5) // Для темных цветов используем белые полосы с большей непрозрачностью
        }
    }
}

extension View {
    func zebraEffect(isDeepCleaned: Bool, roomColor: Room.RoomColor) -> some View { // Обновляем расширение
        self.modifier(ZebraEffectModifier(isDeepCleaned: isDeepCleaned, roomColor: roomColor))
    }
}

