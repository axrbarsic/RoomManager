import SwiftUI

struct SimpleHistoryView: View {
    @ObservedObject var historyManager = SimpleHistoryManager.shared
    @ObservedObject var viewModel: RoomViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingUndoConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Заголовок с информацией
                headerSection
                
                if historyManager.history.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("История")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    undoButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                }
            }
            .alert("Отменить действие?", isPresented: $showingUndoConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Отменить", role: .destructive) {
                    performUndo()
                }
            } message: {
                if let lastAction = historyManager.getLastAction() {
                    Text("Будет отменено: \(lastAction.description)")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Заголовок
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Статистика
            HStack(spacing: 20) {
                HistoryStatCard(
                    title: "Записей",
                    value: "\(historyManager.history.count)/10",
                    color: .blue
                )
                
                HistoryStatCard(
                    title: "Можно отменить",
                    value: historyManager.history.isEmpty ? "0" : "1",
                    color: .orange
                )
            }
            .padding(.horizontal)
            
            // Кнопка очистки истории
            if !historyManager.history.isEmpty {
                Button(action: clearHistory) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                        Text("Очистить историю")
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(20)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Пустое состояние
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("История пуста")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Ваши действия с комнатами будут отображаться здесь")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Список истории
    
    private var historyListView: some View {
        List {
            ForEach(Array(historyManager.history.enumerated()), id: \.element.id) { index, record in
                HistoryRowView(
                    record: record,
                    index: index + 1,
                    isLatest: index == 0,
                    viewModel: viewModel
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemBackground))
    }
    
    // MARK: - Кнопка отмены
    
    private var undoButton: some View {
        Group {
            if !historyManager.history.isEmpty {
                Button(action: {
                    showingUndoConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                        Text("Отменить")
                    }
                    .foregroundColor(.orange)
                    .font(.headline)
                }
            }
        }
    }
    
    // MARK: - Действия
    
    private func performUndo() {
        if let previousState = historyManager.undoLastAction() {
            viewModel.rooms = previousState
            viewModel.saveRooms()
            
            // Закрываем окно, если история пуста
            if historyManager.history.isEmpty {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func clearHistory() {
        historyManager.clearHistory()
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Карточка статистики для истории

struct HistoryStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color, lineWidth: 2)
        )
    }
}

// MARK: - Ячейка истории на основе оригинальной RoomCell

struct HistoryRoomCell: View {
    let room: Room
    @ObservedObject var viewModel: RoomViewModel
    
    private let cellWidth: CGFloat = (UIScreen.main.bounds.width - 50) / 4
    private let cellHeight: CGFloat = 60
    
    var body: some View {
        RoomCell(
            room: room,
            toggleRoomStatus: { /* Пустая функция для истории */ },
            setTime: { /* Пустая функция для истории */ },
            deleteRoom: { /* Пустая функция для истории */ },
            markRoom: { /* Пустая функция для истории */ },
            getTranslation: { key in viewModel.getTranslation(for: key) },
            fontColor: .black, // Используем ТУ ЖЕ логику что и в главном экране
            isLocked: true, // Блокируем взаимодействие в истории
            removeTime: { /* Пустая функция для истории */ },
            viewModel: viewModel
        )
        .frame(width: cellWidth, height: cellHeight)
        .allowsHitTesting(false) // Полностью отключаем взаимодействие
    }
}



// MARK: - Строка истории

struct HistoryRowView: View {
    let record: SimpleActionRecord
    let index: Int
    let isLatest: Bool
    @ObservedObject var viewModel: RoomViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Номер действия и иконка
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(actionColor)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: record.actionType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("\(index)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            // Основное содержимое
            VStack(alignment: .leading, spacing: 8) {
                // Время и тип действия
                HStack {
                    Label(record.timeString, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isLatest {
                        Text("ПОСЛЕДНЕЕ")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                }
                
                // Визуальное представление изменений
                visualChangesView
                
                // Текстовое описание действия
                Text(record.description)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isLatest ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
        .scaleEffect(isLatest ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLatest)
    }
    
    private var visualChangesView: some View {
        Group {
            if let roomNumber = record.roomNumber {
                // Для действий с конкретной комнатой показываем состояние "до" и "после"
                if record.actionType == .deleteRoom,
                   let beforeRoom = findRoomInSnapshot(roomNumber: roomNumber, snapshot: record.beforeSnapshot) {
                    // Для удаленной комнаты показываем снапшот (комната больше не существует)
                    HStack(spacing: 8) {
                        HistoryRoomCell(room: beforeRoom, viewModel: viewModel)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: (UIScreen.main.bounds.width - 50) / 4, height: 60)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(6)
                        
                        Spacer()
                    }
                } else if record.actionType == .addRoom,
                          let afterRoom = findRoomInSnapshot(roomNumber: roomNumber, snapshot: record.afterSnapshot) {
                    // Для добавленной комнаты показываем снапшот из истории
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .frame(width: (UIScreen.main.bounds.width - 50) / 4, height: 60)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                        
                        HistoryRoomCell(room: afterRoom, viewModel: viewModel)
                        
                        Spacer()
                    }
                } else if let beforeRoom = findRoomInSnapshot(roomNumber: roomNumber, snapshot: record.beforeSnapshot),
                          let afterRoom = findRoomInSnapshot(roomNumber: roomNumber, snapshot: record.afterSnapshot) {
                    // Для всех остальных действий показываем снапшоты "до" и "после" из истории
                    HStack(spacing: 8) {
                        HistoryRoomCell(room: beforeRoom, viewModel: viewModel)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                        
                        HistoryRoomCell(room: afterRoom, viewModel: viewModel)
                        
                        Spacer()
                    }
                } else {
                    // Fallback: показываем плейсхолдеры для старых записей или ошибок данных
                    HStack(spacing: 8) {
                        // Плейсхолдер "до"
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: (UIScreen.main.bounds.width - 50) / 4, height: 60)
                            .overlay(
                                Text("?")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            )
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                        
                        // Плейсхолдер "после"
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: (UIScreen.main.bounds.width - 50) / 4, height: 60)
                            .overlay(
                                Text("?")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            )
                        
                        Spacer()
                    }
                }
            } else {
                // Для общих действий показываем количество комнат
                generalChangesIndicator
            }
        }
    }
    
    private var generalChangesIndicator: some View {
        HStack(spacing: 8) {
            let beforeCount = record.beforeSnapshot.count
            let afterCount = record.afterSnapshot.count
            
            if beforeCount != afterCount {
                HStack(spacing: 4) {
                    Text("\(beforeCount)")
                        .foregroundColor(.red)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.gray)
                    Text("\(afterCount)")
                        .foregroundColor(.green)
                    Text("комнат")
                        .foregroundColor(.secondary)
                }
                .font(.caption2)
                .fontWeight(.medium)
            } else {
                Text("Изменено состояние")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func findRoomInSnapshot(roomNumber: String, snapshot: [Room]) -> Room? {
        return snapshot.first { $0.number == roomNumber }
    }
    
    private var actionColor: Color {
        switch record.actionType.color {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Preview

struct SimpleHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleHistoryView(viewModel: RoomViewModel())
    }
}