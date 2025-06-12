import SwiftUI

struct TimePickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: RoomViewModel
    @Binding var selectedTime: Date
    var onSave: () -> Void
    
    // Часы в 12-часовом формате и минуты с шагом 15
    private let hours = AppConfiguration.Time.timePickerHours
    private let minutes = AppConfiguration.Time.timePickerMinutes
    
    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @State private var isAM: Bool
    
    init(viewModel: RoomViewModel, selectedTime: Binding<Date>, onSave: @escaping () -> Void) {
        self.viewModel = viewModel
        self._selectedTime = selectedTime
        self.onSave = onSave
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime.wrappedValue)
        let minute = calendar.component(.minute, from: selectedTime.wrappedValue)
        
        // Преобразуем в 12-часовой формат
        let isAM = hour < 12
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        
        // Округляем минуты до ближайших 15 минут
        let roundedMinute = (minute / 15) * 15
        
        _selectedHour = State(initialValue: hour12)
        _selectedMinute = State(initialValue: roundedMinute)
        _isAM = State(initialValue: isAM)
    }
    
    var body: some View {
        ZStack {
            // Тёмный полупрозрачный фон для модального окна
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 15) {
                // Заголовок
                Text(viewModel.getTranslation(for: "setTime"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Текущее выбранное время
                HStack(spacing: 2) {
                    Text("\(selectedHour):\(String(format: "%02d", selectedMinute))")
                        .font(.system(size: 40, weight: .bold))
                    Text(isAM ? "AM" : "PM")
                        .font(.system(size: 30, weight: .medium))
                        .padding(.leading, 5)
                }
                .foregroundColor(.white)
                .padding(.vertical, 10)
                
                // Секция выбора часов
                VStack(alignment: .leading) {
                    Text(viewModel.getTranslation(for: "hour"))
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.leading, 5)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                        ForEach(hours, id: \.self) { hour in
                            Button(action: {
                                selectedHour = hour
                                updateSelectedTime()
                            }) {
                                Text("\(hour)")
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(selectedHour == hour ? .black : .white)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedHour == hour ? 
                                                 Color.white : Color.gray.opacity(0.2))
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 5)
                }
                .padding(.horizontal)
                
                // Секция выбора минут
                VStack(alignment: .leading) {
                    Text(viewModel.getTranslation(for: "minute"))
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.leading, 5)
                    
                    HStack(spacing: 15) {
                        ForEach(minutes, id: \.self) { minute in
                            Button(action: {
                                selectedMinute = minute
                                updateSelectedTime()
                            }) {
                                Text(String(format: "%02d", minute))
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(selectedMinute == minute ? .black : .white)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedMinute == minute ? 
                                                 Color.white : Color.gray.opacity(0.2))
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 5)
                }
                .padding(.horizontal)
                
                // Секция выбора AM/PM
                VStack(alignment: .leading) {
                    Text("AM/PM")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.leading, 5)
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            isAM = true
                            updateSelectedTime()
                        }) {
                            Text("AM")
                                .font(.system(size: 20, weight: .medium))
                                .frame(height: 50)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(isAM ? .black : .white)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isAM ? Color.white : Color.gray.opacity(0.2))
                                )
                        }
                        
                        Button(action: {
                            isAM = false
                            updateSelectedTime()
                        }) {
                            Text("PM")
                                .font(.system(size: 20, weight: .medium))
                                .frame(height: 50)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(!isAM ? .black : .white)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(!isAM ? Color.white : Color.gray.opacity(0.2))
                                )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Кнопки действий
                HStack(spacing: 20) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(viewModel.getTranslation(for: "cancel"))
                            .font(.headline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(viewModel.getTranslation(for: "OK"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.blue)
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(UIColor.systemBackground))
            )
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
    }
    
    private func updateSelectedTime() {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        
        // Преобразуем из 12-часового формата в 24-часовой
        var hour24 = selectedHour
        if !isAM {
            hour24 = selectedHour == 12 ? 12 : selectedHour + 12
        } else {
            hour24 = selectedHour == 12 ? 0 : selectedHour
        }
        
        components.hour = hour24
        components.minute = selectedMinute
        components.second = 0
        
        if let newDate = calendar.date(from: components) {
            selectedTime = newDate
        }
    }
}

// Для предварительного просмотра
struct TimePickerView_Previews: PreviewProvider {
    static var previews: some View {
        TimePickerView(
            viewModel: RoomViewModel(),
            selectedTime: .constant(Date()),
            onSave: {}
        )
        .preferredColorScheme(.dark)
    }
}
