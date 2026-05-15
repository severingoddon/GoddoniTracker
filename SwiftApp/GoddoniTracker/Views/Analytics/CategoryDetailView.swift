import SwiftUI

struct CategoryDetailView: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    let categoryId: Int?
    let categoryName: String
    let month: String?

    @State private var monthExpenses: MonthExpenses?
    @State private var isLoading = false
    @State private var showExpenseForm = false
    @State private var editingExpense: ExpenseModel?
    @State private var toast: ToastMessage?

    var body: some View {
        ZStack {
            GTColor.bgDeepest.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(GTColor.accentCyan)
            } else if let data = monthExpenses {
                List {
                    ForEach(data.days) { day in
                        Section {
                            ForEach(day.expenses) { expense in
                                ExpenseRowView(expense: expense)
                                    .listRowBackground(GTColor.bgDeepest)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingExpense = expense
                                        showExpenseForm = true
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task { await deleteExpense(expense.id) }
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack {
                                Text(day.dateObject?.dayGroupLabel ?? day.date)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(GTColor.textPrimary)
                                Spacer()
                                Text("-CHF \(String(format: "%.2f", day.total))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(GTColor.textPrimary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                if data.days.isEmpty {
                    Text("Keine Ausgaben")
                        .foregroundStyle(GTColor.textMuted)
                }
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .sheet(isPresented: $showExpenseForm) {
            ExpenseFormView(
                expense: editingExpense,
                onSaved: {
                    showExpenseForm = false
                    editingExpense = nil
                    Task { await load() }
                },
                onDeleted: {
                    showExpenseForm = false
                    editingExpense = nil
                    Task { await load() }
                    toast = ToastMessage(text: "Ausgabe gelöscht", actionLabel: nil, action: nil)
                }
            )
        }
        .onChange(of: showExpenseForm) {
            if !showExpenseForm { editingExpense = nil }
        }
        .onAppear {
            Task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        monthExpenses = try? await api.getExpenses(month: month, categoryId: categoryId ?? 0)
        isLoading = false
    }

    private func deleteExpense(_ id: Int) async {
        try? await api.deleteExpense(id)
        await load()
        toast = ToastMessage(text: "Ausgabe gelöscht", actionLabel: nil, action: nil)
    }
}
