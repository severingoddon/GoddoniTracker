import SwiftUI

struct ExpenseRowView: View {
    let expense: ExpenseModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.system(size: 15))
                    .foregroundStyle(GTColor.textPrimary)

                if let category = expense.categoryName {
                    Text(category)
                        .font(.system(size: 12))
                        .foregroundStyle(GTColor.textMuted)
                }
            }

            Spacer()

            if expense.splitApplied, let factor = expense.splitFactor {
                Text("\(Int(factor * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(GTColor.accentCyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(GTColor.accentCyan.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text("-\(expense.currency) \(String(format: "%.2f", expense.amount))")
                .font(.system(size: 15))
                .foregroundStyle(GTColor.textPrimary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
