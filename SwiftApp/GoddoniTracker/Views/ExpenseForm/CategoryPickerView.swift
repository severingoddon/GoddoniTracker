import SwiftUI

struct CategoryPickerView: View {
    let categories: [CategoryModel]
    @Binding var selectedCategoryId: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GTColor.bgDeepest.ignoresSafeArea()

            List {
                Button {
                    selectedCategoryId = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("Keine")
                            .foregroundStyle(GTColor.textPrimary)
                        Spacer()
                        if selectedCategoryId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(GTColor.accentCyan)
                        }
                    }
                }

                ForEach(categories) { cat in
                    Button {
                        selectedCategoryId = cat.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(cat.name)
                                .foregroundStyle(GTColor.textPrimary)
                            Spacer()
                            if selectedCategoryId == cat.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(GTColor.accentCyan)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Kategorie wählen")
        .navigationBarTitleDisplayMode(.inline)
    }
}
