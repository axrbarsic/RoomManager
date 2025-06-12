import SwiftUI

struct ClipboardSettingsView: View {
    @ObservedObject var viewModel: RoomViewModel
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("disableClipboard") private var disableClipboard = false
    @AppStorage("includeSpanish") private var includeSpanish = true
    @AppStorage("redMessageTemplate") private var redMessageTemplate = "%@ I received this room at %@"
    @AppStorage("greenMessageTemplate") private var greenMessageTemplate = "%@ room stripped at %@"
    @AppStorage("redMessageTemplateES") private var redMessageTemplateES = "habitación %@ recibida a las %@"
    @AppStorage("greenMessageTemplateES") private var greenMessageTemplateES = "habitación %@ limpiada a las %@"
    @AppStorage("enableRedClipboard") private var enableRedClipboard = true
    @AppStorage("enableGreenClipboard") private var enableGreenClipboard = true
    
    @State private var editedRedTemplate: String = ""
    @State private var editedGreenTemplate: String = ""
    @State private var editedRedTemplateES: String = ""
    @State private var editedGreenTemplateES: String = ""
    @State private var showHelp = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(viewModel.getTranslation(for: "clipboardSettings"))) {
                    Toggle(viewModel.getTranslation(for: "disableClipboard"), isOn: $disableClipboard)
                    
                    if !disableClipboard {
                        Toggle(viewModel.getTranslation(for: "includeSpanish"), isOn: $includeSpanish)
                        
                        Toggle(viewModel.getTranslation(for: "enableRedClipboard"), isOn: $enableRedClipboard)
                        
                        Toggle(viewModel.getTranslation(for: "enableGreenClipboard"), isOn: $enableGreenClipboard)
                    }
                }
                
                if !disableClipboard {
                    Section(header: headerWithHelp(title: viewModel.getTranslation(for: "redRoomMessageTemplate"))) {
                        VStack(alignment: .leading) {
                            Text(viewModel.getTranslation(for: "englishTemplate"))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("", text: $editedRedTemplate)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        if includeSpanish {
                            VStack(alignment: .leading) {
                                Text(viewModel.getTranslation(for: "spanishTemplate"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                TextField("", text: $editedRedTemplateES)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    Section(header: Text(viewModel.getTranslation(for: "greenRoomMessageTemplate"))) {
                        VStack(alignment: .leading) {
                            Text(viewModel.getTranslation(for: "englishTemplate"))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("", text: $editedGreenTemplate)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        if includeSpanish {
                            VStack(alignment: .leading) {
                                Text(viewModel.getTranslation(for: "spanishTemplate"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                TextField("", text: $editedGreenTemplateES)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    Section {
                        Button(viewModel.getTranslation(for: "resetToDefault")) {
                            resetToDefaults()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationBarTitle(viewModel.getTranslation(for: "clipboardSettings"), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(viewModel.getTranslation(for: "done")) {
                    saveChanges()
                    presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                editedRedTemplate = redMessageTemplate
                editedGreenTemplate = greenMessageTemplate
                editedRedTemplateES = redMessageTemplateES
                editedGreenTemplateES = greenMessageTemplateES
            }
            .alert(isPresented: $showHelp) {
                Alert(
                    title: Text(viewModel.getTranslation(for: "templateHelp")),
                    message: Text(viewModel.getTranslation(for: "templateHelpText")),
                    dismissButton: .default(Text(viewModel.getTranslation(for: "OK")))
                )
            }
        }
    }
    
    private func headerWithHelp(title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: { showHelp = true }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func saveChanges() {
        redMessageTemplate = editedRedTemplate
        greenMessageTemplate = editedGreenTemplate
        redMessageTemplateES = editedRedTemplateES
        greenMessageTemplateES = editedGreenTemplateES
    }
    
    private func resetToDefaults() {
        editedRedTemplate = "%@ I received this room at %@"
        editedGreenTemplate = "%@ room stripped at %@"
        editedRedTemplateES = "habitación %@ recibida a las %@"
        editedGreenTemplateES = "habitación %@ limpiada a las %@"
    }
}
