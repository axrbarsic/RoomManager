import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: RoomViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(groupedHistoryRecords(), id: \.key) { group in
                    sectionForDate(date: group.key, records: group.value)
                }
            }
            .navigationBarTitle(viewModel.getTranslation(for: "history"), displayMode: .inline)
            .navigationBarItems(trailing: cancelButton)
        }
    }

    // MARK: - Приватные методы

    private var cancelButton: some View {
        Button(viewModel.getTranslation(for: "cancel")) {
            dismissView()
        }
    }

    private func dismissView() {
        // Закрываем окно истории
        // Предположим, что в месте вызова есть @Environment(\.presentationMode)
        // или передана логика закрытия. Если нет - адаптируйте под свой код.
    }

    private func groupedHistoryRecords() -> [(key: Date, value: [HistoryRecord])] {
        // Группируем записи по дням
        let grouped = Dictionary(grouping: viewModel.history) { record in
            Calendar.current.startOfDay(for: record.timestamp)
        }
        
        // Сортируем по дате (новые сверху)
        return grouped.sorted { $0.key > $1.key }
    }

    @ViewBuilder
    private func sectionForDate(date: Date, records: [HistoryRecord]) -> some View {
        Section(header: Text(formattedDate(date))) {
            ForEach(records.sorted { $0.timestamp > $1.timestamp }, id: \.id) { record in
                historyRow(for: record)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func historyRow(for record: HistoryRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.description)
                    .font(.headline)
                Text(formattedTime(record.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            // Иконка действия
            Image(systemName: iconForActionType(record.actionType))
                .foregroundColor(colorForActionType(record.actionType))
        }
        .padding(.vertical, 2)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func iconForActionType(_ actionType: ActionType) -> String {
        switch actionType {
        case .addRoom:
            return "plus.circle"
        case .changeStatus:
            return "arrow.triangle.2.circlepath"
        case .markRoom:
            return "star.circle"
        case .completeRoom:
            return "checkmark.circle"
        case .deepClean:
            return "sparkles"
        case .deleteRoom:
            return "trash.circle"
        case .syncUpdate:
            return "icloud.and.arrow.down"
        case .syncDelete:
            return "icloud.and.arrow.up"
        }
    }
    
    private func colorForActionType(_ actionType: ActionType) -> Color {
        switch actionType {
        case .addRoom:
            return .green
        case .changeStatus:
            return .blue
        case .markRoom:
            return .yellow
        case .completeRoom:
            return .purple
        case .deepClean:
            return .orange
        case .deleteRoom:
            return .red
        case .syncUpdate:
            return .cyan
        case .syncDelete:
            return .gray
        }
    }
}
