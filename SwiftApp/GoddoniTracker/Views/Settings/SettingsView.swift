import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    @State private var settingsVM = SettingsViewModel()
    @State private var showBudgetAlert = false
    @State private var showImportPicker = false
    @State private var showExportSheet = false
    @State private var exportDateFrom = ""
    @State private var exportDateTo = ""
    @State private var toast: ToastMessage?
    @State private var showCategories = false

    var onLogout: () -> Void

    var body: some View {
        ZStack {
            GTColor.bgDeepest.ignoresSafeArea()

            VStack(spacing: 0) {
                List {
                    Section {
                        Button {
                            showCategories = true
                        } label: {
                            Label("Kategorien verwalten", systemImage: "tag")
                                .foregroundStyle(GTColor.textPrimary)
                        }

                        Button {
                            showBudgetAlert = true
                        } label: {
                            Label {
                                HStack {
                                    Text("Monatsbudget")
                                    Spacer()
                                    if let budget = Double(settingsVM.monthlyBudget), budget > 0 {
                                        Text("CHF \(String(format: "%.0f", budget))")
                                            .foregroundStyle(GTColor.textMuted)
                                    }
                                }
                            } icon: {
                                Image(systemName: "banknote")
                            }
                            .foregroundStyle(GTColor.textPrimary)
                        }
                    }

                    Section {
                        Button {
                            showExportSheet = true
                        } label: {
                            Label("Exportieren (CSV)", systemImage: "square.and.arrow.up")
                                .foregroundStyle(GTColor.textPrimary)
                        }

                        Button {
                            showImportPicker = true
                        } label: {
                            Label("Importieren (CSV)", systemImage: "square.and.arrow.down")
                                .foregroundStyle(GTColor.textPrimary)
                        }
                    }

                    Section {
                        Button {
                            onLogout()
                        } label: {
                            Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(GTColor.accentRed)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
                    .foregroundStyle(GTColor.textSecondary)
            }
        }
        .toast($toast)
        .onAppear {
            Task { await settingsVM.load(api: api) }
        }
        .alert("Monatsbudget (CHF)", isPresented: $showBudgetAlert) {
            TextField("z.B. 2000", text: $settingsVM.monthlyBudget)
                .keyboardType(.decimalPad)
            Button("Speichern") {
                Task {
                    if await settingsVM.saveBudget(api: api) {
                        toast = ToastMessage(text: "Budget gespeichert", actionLabel: nil, action: nil)
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .sheet(isPresented: $showCategories) {
            NavigationStack {
                CategoryManagementView()
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(api: api)
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            Task {
                do {
                    let url = try result.get()
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: url)
                    let response = try await api.importCSV(data: data, filename: url.lastPathComponent)
                    toast = ToastMessage(text: response.detail ?? "Import abgeschlossen", actionLabel: nil, action: nil)
                } catch {
                    toast = ToastMessage(text: error.localizedDescription, actionLabel: nil, action: nil)
                }
            }
        }
    }
}

struct ExportSheet: View {
    let api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var dateFrom = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var dateTo = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                GTColor.bgDeepest.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Von")
                            .font(.system(size: 13))
                            .foregroundStyle(GTColor.textSecondary)
                        DatePicker("", selection: $dateFrom, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(GTColor.accentCyan)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bis")
                            .font(.system(size: 13))
                            .foregroundStyle(GTColor.textSecondary)
                        DatePicker("", selection: $dateTo, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(GTColor.accentCyan)
                            .labelsHidden()
                    }

                    if let url = exportURL {
                        ShareLink(item: url) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("CSV exportieren")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GTColor.accentCyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Exportieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(GTColor.textSecondary)
                }
            }
        }
    }

    private var exportURL: URL? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return api.getExportURL(dateFrom: fmt.string(from: dateFrom), dateTo: fmt.string(from: dateTo))
    }
}
