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
    var isLoadingRate = false
    var errorMessage: String?
    var splitHalf = false
    var splitCustom = ""

    var editingExpenseId: Int?

    var isEditing: Bool { editingExpenseId != nil }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(amount.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private var cachedRates: [String: Double] = [:]
    private var preSplitAmount: String?

    func applySplit() {
        let fraction: Double?
        if splitHalf {
            fraction = 0.5
        } else if let val = Double(splitCustom.replacingOccurrences(of: ",", with: ".")), val > 0 {
            fraction = val > 1 ? val / 100.0 : val
        } else {
            fraction = nil
        }

        if fraction != nil, preSplitAmount == nil {
            preSplitAmount = amount
        }

        let baseAmount = preSplitAmount ?? amount
        guard let baseVal = Double(baseAmount.replacingOccurrences(of: ",", with: ".")) else { return }

        if let fraction {
            amount = String(format: "%.2f", baseVal * fraction)
        } else if let original = preSplitAmount {
            amount = original
            preSplitAmount = nil
        }
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

    func convertToCHF() async {
        guard currency != "CHF" else {
            amountInCHF = amount
            return
        }
        guard let parsedAmount = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return }

        if let rate = cachedRates[currency] {
            amountInCHF = String(format: "%.2f", parsedAmount * rate)
            return
        }

        isLoadingRate = true
        do {
            let rate = try await fetchRate(from: currency, to: "CHF")
            cachedRates[currency] = rate
            amountInCHF = String(format: "%.2f", parsedAmount * rate)
        } catch {
            errorMessage = "Wechselkurs konnte nicht geladen werden"
        }
        isLoadingRate = false
    }

    private func fetchRate(from: String, to: String) async throws -> Double {
        let url = URL(string: "https://api.frankfurter.app/latest?from=\(from)&to=\(to)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
        guard let rate = response.rates[to] else {
            throw URLError(.badServerResponse)
        }
        return rate
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

private struct FrankfurterResponse: Decodable {
    let rates: [String: Double]
}
