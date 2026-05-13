import Foundation

@Observable
final class ExpenseFormViewModel {
    var title = ""
    var amount = ""
    var currency = "CHF"
    var amountInCHF = ""
    var selectedCategoryId: Int?
    var date = Date()
    var paymentMethod = ""
    var comment = ""
    var isSaving = false
    var errorMessage: String?

    var editingExpenseId: Int?

    var isEditing: Bool { editingExpenseId != nil }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amount.replacingOccurrences(of: ",", with: ".")) != nil
    }

    func populate(from expense: ExpenseModel) {
        editingExpenseId = expense.id
        title = expense.title
        amount = String(format: "%.2f", expense.amount)
        currency = expense.currency
        amountInCHF = String(format: "%.2f", expense.amountInChf)
        selectedCategoryId = expense.categoryId
        date = expense.date
        paymentMethod = expense.paymentMethod ?? ""
        comment = expense.comment ?? ""
    }

    func save(api: APIClient) async -> Bool {
        guard isValid else { return false }
        isSaving = true
        errorMessage = nil

        let parsedAmount = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let parsedCHF: Double
        if currency == "CHF" {
            parsedCHF = parsedAmount
        } else {
            parsedCHF = Double(amountInCHF.replacingOccurrences(of: ",", with: ".")) ?? parsedAmount
        }

        let expense = ExpenseCreate(
            title: title.trimmingCharacters(in: .whitespaces),
            date: date,
            amount: parsedAmount,
            currency: currency,
            amountInChf: parsedCHF,
            categoryId: selectedCategoryId,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            comment: comment.isEmpty ? nil : comment
        )

        do {
            if let id = editingExpenseId {
                _ = try await api.updateExpense(id, expense)
            } else {
                _ = try await api.createExpense(expense)
            }
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
