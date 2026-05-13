import SwiftUI

struct CategoryManagementView: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = CategoryManagementViewModel()
    @State private var showAddAlert = false
    @State private var newName = ""
    @State private var editingCategory: CategoryModel?
    @State private var editName = ""
    @State private var toast: ToastMessage?

    var body: some View {
        ZStack {
            GTColor.bgDeepest.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(GTColor.accentCyan)
            } else {
                List {
                    ForEach(viewModel.categories) { cat in
                        HStack {
                            Text(cat.name)
                                .foregroundStyle(GTColor.textPrimary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingCategory = cat
                            editName = cat.name
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    let success = await viewModel.deleteCategory(id: cat.id, api: api)
                                    if !success, let error = viewModel.errorMessage {
                                        toast = ToastMessage(text: error, actionLabel: nil, action: nil)
                                    }
                                }
                            } label: {
                                Label("Loeschen", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        viewModel.move(from: source, to: destination)
                        Task { await viewModel.saveOrder(api: api) }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Kategorien")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
                    .foregroundStyle(GTColor.textSecondary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(GTColor.accentCyan)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .foregroundStyle(GTColor.accentCyan)
            }
        }
        .toast($toast)
        .onAppear {
            Task { await viewModel.load(api: api) }
        }
        .alert("Neue Kategorie", isPresented: $showAddAlert) {
            TextField("Name (z.B. Essen🍕)", text: $newName)
            Button("Erstellen") {
                Task {
                    _ = await viewModel.addCategory(name: newName, api: api)
                    newName = ""
                }
            }
            Button("Abbrechen", role: .cancel) { newName = "" }
        }
        .alert("Kategorie umbenennen", isPresented: Binding(
            get: { editingCategory != nil },
            set: { if !$0 { editingCategory = nil } }
        )) {
            TextField("Name", text: $editName)
            Button("Speichern") {
                if let cat = editingCategory {
                    Task {
                        _ = await viewModel.renameCategory(id: cat.id, name: editName, api: api)
                        editingCategory = nil
                    }
                }
            }
            Button("Abbrechen", role: .cancel) { editingCategory = nil }
        }
    }
}
