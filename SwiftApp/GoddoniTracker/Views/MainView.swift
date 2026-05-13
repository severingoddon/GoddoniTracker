import SwiftUI

struct MainView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(APIClient.self) private var api

    @State private var expenseListVM = ExpenseListViewModel()
    @State private var showAddExpense = false
    @State private var showSettings = false
    @State private var showAnalytics = false
    @State private var toast: ToastMessage?
    @State private var editingExpense: ExpenseModel?

    var body: some View {
        NavigationStack {
            ZStack {
                GTColor.bgDeepest.ignoresSafeArea()

                VStack(spacing: 0) {
                    ExpenseListView(
                        viewModel: expenseListVM,
                        onEdit: { expense in
                            editingExpense = expense
                            showAddExpense = true
                        }
                    )

                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    monthNavigator
                }
            }
        }
        .toast($toast)
        .sheet(isPresented: $showAddExpense) {
            ExpenseFormView(
                expense: editingExpense,
                onSaved: {
                    showAddExpense = false
                    editingExpense = nil
                    Task { await expenseListVM.load(api: api) }
                    toast = ToastMessage(text: "Ausgabe gespeichert", actionLabel: nil, action: nil)
                }
            )
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationStack {
                AnalyticsView()
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(onLogout: {
                    showSettings = false
                    authManager.logout()
                })
            }
        }
        .onAppear {
            Task { await expenseListVM.load(api: api) }
        }
        .onChange(of: expenseListVM.currentMonth) {
            Task { await expenseListVM.load(api: api) }
        }
        .onChange(of: showAddExpense) {
            if !showAddExpense { editingExpense = nil }
        }
    }

    private var monthNavigator: some View {
        HStack(spacing: 16) {
            Button { expenseListVM.goToPreviousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GTColor.textSecondary)
            }

            Text(expenseListVM.monthLabel)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GTColor.textPrimary)

            Button { expenseListVM.goToNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GTColor.textSecondary)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Spacer()

            Button { showAnalytics = true } label: {
                Image(systemName: "chart.pie")
                    .font(.system(size: 22))
                    .foregroundStyle(GTColor.accentCyan)
                    .frame(width: 50, height: 50)
                    .background(GTColor.accentCyan.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            Button { showAddExpense = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(GTColor.accentCyan)
                    .clipShape(Circle())
                    .shadow(color: GTColor.accentCyan.opacity(0.4), radius: 8, y: 4)
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22))
                    .foregroundStyle(GTColor.accentCyan)
                    .frame(width: 50, height: 50)
                    .background(GTColor.accentCyan.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .background(GTColor.bgCard)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GTColor.borderSubtle)
                .frame(height: 1)
        }
    }
}
