import SwiftUI

struct ExpenseFormView: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ExpenseFormViewModel()
    @State private var categories: [CategoryModel] = []
    @State private var showNewCategory = false
    @State private var newCategoryName = ""
    @State private var showDeleteConfirm = false
    @State private var showCategoryPicker = false
    @State private var showDatePicker = false
    @FocusState private var focusedField: FormField?

    enum FormField {
        case title, amount, amountInCHF, paymentMethod, comment
    }

    var expense: ExpenseModel?
    var onSaved: () -> Void
    var onDeleted: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                GTColor.bgDeepest.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        formSection("Titel") {
                            TextField("z.B. Migros Einkauf", text: $viewModel.title)
                                .foregroundStyle(GTColor.textPrimary)
                                .focused($focusedField, equals: .title)
                        }

                        HStack(spacing: 12) {
                            formSection("Betrag") {
                                TextField("0.00", text: $viewModel.amount)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(GTColor.textPrimary)
                                    .focused($focusedField, equals: .amount)
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
                                .frame(height: 20)
                            }
                            .frame(width: 100)
                        }

                        if viewModel.currency != "CHF" {
                            formSection("Betrag in CHF") {
                                HStack {
                                    TextField("0.00", text: $viewModel.amountInCHF)
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(GTColor.textPrimary)
                                        .focused($focusedField, equals: .amountInCHF)
                                    if viewModel.isLoadingRate {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(GTColor.accentCyan)
                                    }
                                }
                            }
                        }

                        formSection("Kategorie") {
                            HStack {
                                Button {
                                    focusedField = nil
                                    showCategoryPicker = true
                                } label: {
                                    HStack {
                                        Text(selectedCategoryName)
                                            .foregroundStyle(GTColor.accentCyan)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(GTColor.textMuted)
                                    }
                                    .contentShape(Rectangle())
                                }

                                Button {
                                    showNewCategory = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(GTColor.accentCyan)
                                }
                            }
                        }
                        .navigationDestination(isPresented: $showCategoryPicker) {
                            CategoryPickerView(
                                categories: categories,
                                selectedCategoryId: $viewModel.selectedCategoryId
                            )
                        }

                        formSection("Datum") {
                            Button {
                                focusedField = nil
                                showDatePicker = true
                            } label: {
                                HStack {
                                    Text(viewModel.date, format: .dateTime.day().month(.wide).year())
                                    Text(viewModel.date, format: .dateTime.hour().minute())
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(GTColor.textMuted)
                                }
                                .foregroundStyle(GTColor.textPrimary)
                                .contentShape(Rectangle())
                            }
                        }
                        .navigationDestination(isPresented: $showDatePicker) {
                            DatePickerView(date: $viewModel.date)
                        }

                        formSection("Anteil bezahlt") {
                            HStack(spacing: 10) {
                                Button {
                                    viewModel.splitHalf.toggle()
                                    if viewModel.splitHalf {
                                        viewModel.splitCustom = ""
                                        viewModel.splitAbsolute = ""
                                    }
                                    viewModel.applySplit()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: viewModel.splitHalf ? "checkmark.square.fill" : "square")
                                        Text("50%")
                                    }
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(viewModel.splitHalf ? GTColor.accentCyan : GTColor.textMuted)
                                }

                                Divider().frame(height: 18)

                                HStack(spacing: 2) {
                                    TextField("0", text: $viewModel.splitCustom)
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(GTColor.textPrimary)
                                        .frame(minWidth: 25)
                                    Text("%")
                                        .font(.system(size: 13))
                                        .foregroundStyle(GTColor.textMuted)
                                }

                                Divider().frame(height: 18)

                                HStack(spacing: 2) {
                                    TextField("0.00", text: $viewModel.splitAbsolute)
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(GTColor.textPrimary)
                                    Text(viewModel.currency)
                                        .font(.system(size: 13))
                                        .foregroundStyle(GTColor.textMuted)
                                }
                            }
                        }

                        formSection("Zahlungsmethode") {
                            TextField("z.B. Karte, Twint, Bar", text: $viewModel.paymentMethod)
                                .foregroundStyle(GTColor.textPrimary)
                                .focused($focusedField, equals: .paymentMethod)
                        }

                        formSection("Kommentar") {
                            TextField("Optional", text: $viewModel.comment)
                                .foregroundStyle(GTColor.textPrimary)
                                .focused($focusedField, equals: .comment)
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
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture {
                    focusedField = nil
                }
            }
            .navigationTitle(viewModel.isEditing ? "Ausgabe bearbeiten" : "Neue Ausgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(GTColor.textSecondary)
                }
                if viewModel.isEditing {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showDeleteConfirm = true } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(GTColor.accentRed)
                        }
                    }
                }
            }
            .confirmationDialog("Ausgabe löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let id = expense?.id {
                        Task {
                            try? await api.deleteExpense(id)
                            onDeleted?()
                        }
                    }
                }
            }
            .onAppear {
                if let expense, !viewModel.isEditing {
                    viewModel.populate(from: expense)
                } else if expense == nil {
                    focusedField = .amount
                }
                Task {
                    categories = (try? await api.getCategories()) ?? []
                }
            }
            .onChange(of: viewModel.splitCustom) {
                if !viewModel.splitCustom.isEmpty {
                    viewModel.splitHalf = false
                }
                viewModel.applySplit()
            }
            .onChange(of: viewModel.splitAbsolute) {
                viewModel.applyAbsoluteSplit()
            }
            .onChange(of: viewModel.currency) {
                Task { await viewModel.convertToCHF() }
            }
            .onChange(of: viewModel.amount) {
                if viewModel.currency != "CHF" {
                    Task { await viewModel.convertToCHF() }
                }
            }
            .onChange(of: showCategoryPicker) {
                if !showCategoryPicker {
                    focusedField = nil
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

    private var selectedCategoryName: String {
        if let id = viewModel.selectedCategoryId, let cat = categories.first(where: { $0.id == id }) {
            return cat.name
        }
        return "Keine"
    }

    private func formSection<Content: View>(_ title: String, verticalPadding: CGFloat = 10, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(GTColor.textSecondary)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, verticalPadding)
                .background(GTColor.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GTColor.borderSubtle, lineWidth: 1)
                )
        }
    }
}
