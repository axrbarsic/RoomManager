import SwiftUI

struct BackupSelectionView: View {
    @ObservedObject var viewModel: RoomViewModel
    let isLocked: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        List {
            if viewModel.backups.isEmpty {
                Text(viewModel.getTranslation(for: "noBackupFound"))
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.backups.sorted { $0.timestamp > $1.timestamp }) { backup in
                    Button(action: {
                        if !isLocked {
                            let message = viewModel.restoreRooms(from: backup)
                            if message == viewModel.getTranslation(for: "restoreSuccess") {
                                // Успешное восстановление
                                alertMessage = message
                                showAlert = true
                            } else {
                                // Ошибка
                                alertMessage = message
                                showAlert = true
                            }
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(backup.name)
                                    .font(.headline)
                                
                                Text(backup.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.down.doc")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(isLocked)
                }
                .onDelete(perform: deleteBackup)
            }
        }
        .navigationTitle(viewModel.getTranslation(for: "chooseBackup"))
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertMessage),
                dismissButton: .default(Text(viewModel.getTranslation(for: "OK"))) {
                    if alertMessage == viewModel.getTranslation(for: "restoreSuccess") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.backups.isEmpty {
                    EditButton()
                        .disabled(isLocked)
                }
            }
        }
    }
    
    private func deleteBackup(at offsets: IndexSet) {
        let sortedBackups = viewModel.backups.sorted { $0.timestamp > $1.timestamp }
        for index in offsets {
            if let backupIndex = viewModel.backups.firstIndex(where: { $0.id == sortedBackups[index].id }) {
                viewModel.backups.remove(at: backupIndex)
            }
        }
        viewModel.saveBackups()
    }
}
