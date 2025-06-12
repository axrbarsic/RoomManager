import SwiftUI
import Combine

// MARK: - Глобальный менеджер для Floating Menu
class FloatingMenuManager: ObservableObject {
    static let shared = FloatingMenuManager()
    
    @Published var isMenuVisible = false
    @Published var menuPosition: CGPoint = .zero
    @Published var activeRoom: Room?
    @Published var sourceFrame: CGRect = .zero
    
    private var screenBounds: CGRect = UIScreen.main.bounds
    
    private init() {}
    
    // Показать меню для комнаты
    func showMenu(for room: Room, sourceFrame: CGRect) {
        // Если уже показано меню, сначала скрываем его
        if isMenuVisible {
            hideMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.displayMenu(for: room, sourceFrame: sourceFrame)
            }
        } else {
            displayMenu(for: room, sourceFrame: sourceFrame)
        }
    }
    
    private func displayMenu(for room: Room, sourceFrame: CGRect) {
        self.activeRoom = room
        self.sourceFrame = sourceFrame
        self.menuPosition = calculateOptimalPosition(sourceFrame: sourceFrame)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.isMenuVisible = true
        }
    }
    
    // Скрыть меню
    func hideMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isMenuVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.activeRoom = nil
        }
    }
    
    // Автоматическое позиционирование меню с полной защитой от выхода за границы
    private func calculateOptimalPosition(sourceFrame: CGRect) -> CGPoint {
        // Динамический размер меню в зависимости от содержимого
        let baseMenuHeight: CGFloat = 160 // Базовая высота для заблокированных комнат
        let expandedMenuHeight: CGFloat = 220 // Высота для полного меню
        let menuWidth: CGFloat = 280
        
        // Определяем размер меню на основе состояния комнаты
        let isLocked = activeRoom?.isCompletedBefore930 ?? false
        let menuHeight = isLocked ? baseMenuHeight : expandedMenuHeight
        let menuSize = CGSize(width: menuWidth, height: menuHeight)
        
        let safetyPadding: CGFloat = 20 // Отступ от краев экрана
        
        // Обновляем границы экрана
        screenBounds = UIScreen.main.bounds
        
        // Учитываем safe area
        let safeAreaTop: CGFloat = 100 // Примерный отступ сверху для статус бара и navigation
        let safeAreaBottom: CGFloat = 50 // Примерный отступ снизу для home indicator
        
        // Доступная область для размещения меню
        let availableMinX = safetyPadding
        let availableMaxX = screenBounds.width - safetyPadding
        let availableMinY = safeAreaTop + safetyPadding
        let availableMaxY = screenBounds.height - safeAreaBottom - safetyPadding
        
        // Размеры меню
        let menuHalfWidth = menuSize.width / 2
        let menuHalfHeight = menuSize.height / 2
        
        // Начальная позиция - пытаемся разместить по центру ячейки
        var targetX = sourceFrame.midX
        var targetY = sourceFrame.midY
        
        // ПРОВЕРКА И КОРРЕКЦИЯ ПО ГОРИЗОНТАЛИ
        // Левая граница меню не должна выходить за левый край
        if targetX - menuHalfWidth < availableMinX {
            targetX = availableMinX + menuHalfWidth
        }
        
        // Правая граница меню не должна выходить за правый край
        if targetX + menuHalfWidth > availableMaxX {
            targetX = availableMaxX - menuHalfWidth
        }
        
        // ПРОВЕРКА И КОРРЕКЦИЯ ПО ВЕРТИКАЛИ
        // Верхняя граница меню не должна выходить за верхний край
        if targetY - menuHalfHeight < availableMinY {
            targetY = availableMinY + menuHalfHeight
        }
        
        // Нижняя граница меню не должна выходить за нижний край
        if targetY + menuHalfHeight > availableMaxY {
            targetY = availableMaxY - menuHalfHeight
        }
        
        // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: если ячейка находится в проблемном месте,
        // смещаем меню в более удобную позицию
        
        // Проверяем, не перекрывается ли меню с ячейкой
        let menuRect = CGRect(
            x: targetX - menuHalfWidth,
            y: targetY - menuHalfHeight,
            width: menuSize.width,
            height: menuSize.height
        )
        
        if menuRect.intersects(sourceFrame) {
            // Пытаемся разместить меню справа от ячейки
            let rightX = sourceFrame.maxX + menuHalfWidth + 10
            if rightX + menuHalfWidth <= availableMaxX {
                targetX = rightX
            }
            // Если справа не помещается, размещаем слева
            else {
                let leftX = sourceFrame.minX - menuHalfWidth - 10
                if leftX - menuHalfWidth >= availableMinX {
                    targetX = leftX
                }
            }
            
            // Аналогично для вертикали: пытаемся разместить сверху
            let topY = sourceFrame.minY - menuHalfHeight - 10
            if topY - menuHalfHeight >= availableMinY {
                targetY = topY
            }
            // Если сверху не помещается, размещаем снизу
            else {
                let bottomY = sourceFrame.maxY + menuHalfHeight + 10
                if bottomY + menuHalfHeight <= availableMaxY {
                    targetY = bottomY
                }
            }
        }
        
        // ФИНАЛЬНАЯ ЗАЩИТА: если каким-то образом координаты все еще выходят за границы,
        // принудительно ограничиваем их безопасными значениями
        targetX = max(availableMinX + menuHalfWidth, min(availableMaxX - menuHalfWidth, targetX))
        targetY = max(availableMinY + menuHalfHeight, min(availableMaxY - menuHalfHeight, targetY))
        
        // Логирование для отладки (можно убрать в релизе)
        print("📍 Menu positioning:")
        print("   Source frame: \(sourceFrame)")
        print("   Screen bounds: \(screenBounds)")
        print("   Menu size: \(menuSize) (locked: \(isLocked))")
        print("   Available area: x=\(availableMinX)-\(availableMaxX), y=\(availableMinY)-\(availableMaxY)")
        print("   Final position: (\(targetX), \(targetY))")
        print("   Menu bounds: (\(targetX - menuHalfWidth), \(targetY - menuHalfHeight)) to (\(targetX + menuHalfWidth), \(targetY + menuHalfHeight))")
        
        return CGPoint(x: targetX, y: targetY)
    }
    
    // Обновить размеры экрана при изменении ориентации с дополнительными проверками
    func updateScreenBounds(_ bounds: CGRect) {
        let oldBounds = screenBounds
        screenBounds = bounds
        
        print("📱 Screen bounds updated: \(oldBounds) -> \(bounds)")
        
        // Пересчитываем позицию если меню активно
        if isMenuVisible {
            let newPosition = calculateOptimalPosition(sourceFrame: sourceFrame)
            
            // Анимированно обновляем позицию
            withAnimation(.easeInOut(duration: 0.3)) {
                menuPosition = newPosition
            }
            
            print("📍 Menu position updated due to orientation change: \(newPosition)")
        }
    }
}

// MARK: - Floating Menu View
struct SmartFloatingMenu: View {
    @ObservedObject var manager = FloatingMenuManager.shared
    let viewModel: RoomViewModel
    let getTranslation: (String) -> String
    let onAction: (FloatingMenuAction) -> Void
    
    var body: some View {
        if manager.isMenuVisible, let room = manager.activeRoom {
            ZStack {
                // Полупрозрачный фон для закрытия меню
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        manager.hideMenu()
                    }
                
                // Само меню
                MenuContent(
                    room: room,
                    viewModel: viewModel,
                    getTranslation: getTranslation,
                    onAction: onAction
                )
                .position(manager.menuPosition)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.1).combined(with: .opacity),
                    removal: .scale(scale: 0.1).combined(with: .opacity)
                ))
            }
            .zIndex(999) // Поверх всего
        }
    }
}

// MARK: - Содержимое меню
struct MenuContent: View {
    let room: Room
    let viewModel: RoomViewModel
    let getTranslation: (String) -> String
    let onAction: (FloatingMenuAction) -> Void
    
    private let isLocked: Bool
    @State private var showDeleteConfirmation = false
    
    init(room: Room, viewModel: RoomViewModel, getTranslation: @escaping (String) -> String, onAction: @escaping (FloatingMenuAction) -> Void) {
        self.room = room
        self.viewModel = viewModel
        self.getTranslation = getTranslation
        self.onAction = onAction
        self.isLocked = room.isCompletedBefore930
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Заголовок
            Text("Комната \(room.number)")
                .font(.headline)
                .foregroundColor(.white)
            
            if isLocked {
                // Для комнат "сделано до 9:30" - только разблокировка
                VStack(spacing: 8) {
                    Text("Заблокировано до 9:30")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button(action: { 
                        SoundManager.shared.provideMaximumHapticFeedback()
                        onAction(.toggleBefore930) 
                    }) {
                        ZStack {
                            Text("930")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                            
                            // Показываем перечеркивание так как комната заблокирована
                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 2)
                                .rotationEffect(.degrees(-15))
                        }
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Для обычных комнат - полное меню
                
                // Цветовые статусы
                VStack(spacing: 8) {
                    Text("Статус")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 15) {
                        StatusButton(emoji: "🟡", color: .yellow, action: {
                            onAction(.changeColor(.none))
                        })
                        
                        StatusButton(emoji: "🔴", color: .red, action: {
                            onAction(.changeColor(.red))
                        })
                        
                        StatusButton(emoji: "🟢", color: .green, action: {
                            onAction(.changeColor(.green))
                        })
                        
                        StatusButton(emoji: "🔵", color: .blue, action: {
                            onAction(.changeColor(.blue))
                        })
                    }
                }
                
                // Действия
                VStack(spacing: 8) {
                    Text("Действия")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 15) {
                        // Пометка/снятие пометки
                        ActionButton(
                            icon: room.isMarked ? "flag.slash" : "flag.fill",
                            color: .orange,
                            action: { onAction(.toggleMark) }
                        )
                        
                        // Deep Clean - текстовая кнопка "DC" с перечеркиванием когда активна
                        Button(action: { 
                            SoundManager.shared.provideMaximumHapticFeedback()
                            onAction(.toggleDeepClean) 
                        }) {
                            ZStack {
                                Text("DC")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                // Перечеркивание если Deep Clean активен
                                if room.isDeepCleaned {
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(height: 2)
                                        .rotationEffect(.degrees(-15))
                                }
                            }
                            .frame(width: 45, height: 45)
                            .background(
                                Circle()
                                    .fill(Color.cyan)
                                    .shadow(color: Color.cyan.opacity(0.5), radius: 3, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Установка времени - будильник
                        ActionButton(
                            icon: "alarm.fill",
                            color: .purple,
                            action: { onAction(.setTime) }
                        )
                        
                        // Кнопка "сделано до 9:30" - белая с текстом "930" или перечеркнутая
                        Button(action: { 
                            SoundManager.shared.provideMaximumHapticFeedback()
                            onAction(.toggleBefore930) 
                        }) {
                            ZStack {
                                Text("930")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                
                                // Перечеркивание если комната белая (сделана до 9:30)
                                if room.color == .white {
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(height: 2)
                                        .rotationEffect(.degrees(-15))
                                }
                            }
                            .frame(width: 45, height: 45)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Удаление с подтверждением
                        Button(action: { 
                            SoundManager.shared.provideMaximumHapticFeedback()
                            showDeleteConfirmation = true 
                        }) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 45, height: 45)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .shadow(color: Color.red.opacity(0.5), radius: 3, x: 0, y: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
        .frame(maxWidth: 280)
        .alert("Подтверждение удаления", isPresented: $showDeleteConfirmation) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                onAction(.delete)
            }
        } message: {
            Text("Вы уверены, что хотите удалить комнату \(room.number)?")
        }
    }
}

// MARK: - Вспомогательные компоненты
struct StatusButton: View {
    let emoji: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            SoundManager.shared.provideMaximumHapticFeedback()
            action()
        }) {
            Text(emoji)
                .font(.title2)
                .frame(width: 45, height: 45)
                .background(
                    Circle()
                        .fill(color.opacity(0.3))
                        .overlay(
                            Circle()
                                .stroke(color, lineWidth: 2)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            SoundManager.shared.provideMaximumHapticFeedback()
            action()
        }) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 45, height: 45)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Перечисление действий меню
enum FloatingMenuAction {
    case changeColor(Room.RoomColor)
    case toggleMark
    case toggleDeepClean
    case setTime
    case delete
    case toggleBefore930
} 