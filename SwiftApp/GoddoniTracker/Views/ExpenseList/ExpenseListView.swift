import SwiftUI

struct ExpenseListView: View {
    @Environment(APIClient.self) private var api
    @Bindable var viewModel: ExpenseListViewModel
    var onEdit: (ExpenseModel) -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if let data = viewModel.monthExpenses {
                summaryBar(data: data)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(GTColor.accentCyan)
                Spacer()
            } else if viewModel.isSearching && !viewModel.searchResults.isEmpty {
                searchResultsList
            } else if let data = viewModel.monthExpenses {
                expenseList(data: data)
            } else if let error = viewModel.errorMessage {
                Spacer()
                Text(error)
                    .foregroundStyle(GTColor.accentRed)
                    .padding()
                Spacer()
            } else {
                Spacer()
                Text("Keine Ausgaben")
                    .foregroundStyle(GTColor.textMuted)
                Spacer()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(GTColor.textMuted)
            TextField("Ausgaben durchsuchen", text: $viewModel.searchText)
                .foregroundStyle(GTColor.textPrimary)
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchText) {
                    Task { await viewModel.search(api: api) }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(GTColor.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func summaryBar(data: MonthExpenses) -> some View {
        HStack {
            Text("Gesamt: -CHF \(String(format: "%.2f", data.allTimeTotal))")
                .font(.system(size: 13))
                .foregroundStyle(GTColor.accentCyan)

            Spacer()

            Text("Monat: -CHF \(String(format: "%.2f", data.monthTotal))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GTColor.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { expense in
                    ExpenseRowView(expense: expense)
                        .onTapGesture { onEdit(expense) }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func expenseList(data: MonthExpenses) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(data.days) { day in
                    dayHeader(day: day)

                    ForEach(day.expenses) { expense in
                        ExpenseRowView(expense: expense)
                            .onTapGesture { onEdit(expense) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { _ = await viewModel.deleteExpense(expense.id, api: api) }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func dayHeader(day: DayGroup) -> some View {
        HStack {
            Text(day.dateObject?.dayGroupLabel ?? day.date)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GTColor.textPrimary)

            Spacer()

            Text("-CHF \(String(format: "%.2f", day.total))")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GTColor.textPrimary)
        }
        .padding(.vertical, 10)
        .padding(.top, 8)
    }
}
