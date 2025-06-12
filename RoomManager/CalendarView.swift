import SwiftUI

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: RoomViewModel

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .onChange(of: selectedDate) { newValue in
                        if !hasData(for: newValue) {
                            // Нет данных за выбранный день
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
            }
            .navigationBarTitle(viewModel.getTranslation(for: "historyTitle"), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(viewModel.getTranslation(for: "cancel")) {
                    presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func hasData(for date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return viewModel.history.contains(where: { Calendar.current.startOfDay(for: $0.timestamp) == day })
    }
}
