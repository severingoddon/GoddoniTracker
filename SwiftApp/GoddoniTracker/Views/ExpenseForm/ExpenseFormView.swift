import SwiftUI

struct ExpenseFormView: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ExpenseFormViewModel()
    @State private var categories: [CategoryModel] = []
    @State private var showNewCategory = false
    @State private var newCategoryName = ""

    var expense: ExpenseModel?
    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                GTColor.bgDeepest.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        formSection("Titel") {
                            TextField("z.B. Migros Einkauf", text: $viewModel.title)
                                .foregroundStyle(GTColor.textPrimary)
                        }

                        HStack(spacing: 12) {
                            formSection("Betrag") {
                                TextField("0.00", text: $viewModel.amount)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(GTColor.textPrimary)
                            }

                            formSection("Währung") {
                                Picker("", selection: $viewModel.currency) {
                                    Text("CHF").tag("CHF")
                                    Text("EUR").tag("EUR")
                                    Text("USD").tag("USD")
                                    Text("GBP").tag("GBP")
                                }
                                .pickerStyle(.menu)
                                .tint(GTColor.accentCyan)
                            }
                            .frame(width: 100)
                        }

                        if viewModel.currency != "CHF" {
                            formSection("Betrag in CHF") {
                                TextField("0.00", text: $viewModel.amountInCHF)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(GTColor.textPrimary)
                            }
                        }

                        formSection("Kategorie") {
                            HStack {
                                Picker("", selection: $viewModel.selectedCategoryId) {
                                    Text("Keine").tag(nil as Int?)
                                    ForEach(categories) { cat in
                                        Text(cat.name).tag(cat.id as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(GTColor.accentCyan)

                                Spacer()

                                Button {
                                    showNewCategory = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(GTColor.accentCyan)
                                }
                            }
                        }

                        formSection("Datum") {
                            DatePicker("", selection: $viewModel.date)
                                .datePickerStyle(.compact)
                                .tint(GTColor.accentCyan)
                                .labelsHidden()
                        }

                        formSection("Zahlungsmethode") {
                            TextField("z.B. Karte, Twint, Bar", text: $viewModel.paymentMethod)
                                .foregroundStyle(GTColor.textPrimary)
                        }

                        HStack(spacing: 12) {
                            formSection("Stadt") {
                                TextField("Optional", text: $viewModel.city)
                                    .foregroundStyle(GTColor.textPrimary)
                            }
                            formSection("Land") {
                                TextField("Optional", text: $viewModel.country)
                                    .foregroundStyle(GTColor.textPrimary)
                            }
                        }

                        formSection("Kommentar") {
                            TextField("Optional", text: $viewModel.comment)
                                .foregroundStyle(GTColor.textPrimary)
                        }

                        Button {
                            Task {
                                let success = await viewModel.save(api: api)
                                if success { onSaved() }
                            }
                        } label: {
                            HStack {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(viewModel.isEditing ? "Speichern" : "Ausgabe erfassen")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.isValid ? GTColor.accentCyan : GTColor.textMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!viewModel.isValid || viewModel.isSaving)
                        .padding(.top, 8)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(GTColor.accentRed)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(viewModel.isEditing ? "Ausgabe bearbeiten" : "Neue Ausgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(GTColor.textSecondary)
                }
            }
            .onAppear {
                if let expense {
                    viewModel.populate(from: expense)
                }
                Task {
                    categories = (try? await api.getCategories()) ?? []
                }
            }
            .alert("Neue Kategorie", isPresented: $showNewCategory) {
                TextField("Name", text: $newCategoryName)
                Button("Erstellen") {
                    Task {
                        if let cat = try? await api.createCategory(newCategoryName) {
                            categories.append(cat)
                            viewModel.selectedCategoryId = cat.id
                            newCategoryName = ""
                        }
                    }
                }
                Button("Abbrechen", role: .cancel) { newCategoryName = "" }
            }
        }
    }

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(GTColor.textSecondary)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GTColor.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GTColor.borderSubtle, lineWidth: 1)
                )
        }
    }
}
