import SwiftUI

/// Compares each category's spending in the anchor month (last entry of `comparison.months`)
/// with the average of the months before it.
struct CategoryComparisonSection: View {
    let comparison: CategoryComparison
    @Binding var months: Int

    private static let monthOptions = [3, 6, 12]
    private static let barColor = Color(hex: 0x475569)
    private static let averageColor = Color(hex: 0xF59E0B)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            legend

            if comparison.categories.isEmpty {
                Text("Keine Ausgaben in diesem Zeitraum")
                    .font(.system(size: 13))
                    .foregroundStyle(GTColor.textMuted)
                    .padding(.vertical, 8)
            } else {
                ForEach(comparison.categories) { category in
                    NavigationLink {
                        CategoryDetailView(
                            categoryId: category.categoryId,
                            categoryName: category.categoryName,
                            month: comparison.months.last
                        )
                    } label: {
                        categoryCard(category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kategorienvergleich")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GTColor.textPrimary)
                Text("\(currentLabel) vs. Ø der letzten \(months) Monate")
                    .font(.system(size: 12))
                    .foregroundStyle(GTColor.textSecondary)
            }

            Spacer()

            Picker("", selection: $months) {
                ForEach(Self.monthOptions, id: \.self) { option in
                    Text("\(option) M").tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Capsule().fill(GTColor.accentCyan).frame(width: 10, height: 6)
                Text(currentLabel)
            }
            HStack(spacing: 4) {
                Rectangle().fill(Self.averageColor).frame(width: 2, height: 12)
                Text("Ø \(baseRangeLabel)")
            }
            HStack(spacing: 2) {
                Text("▲").foregroundStyle(GTColor.accentRed)
                Text("teurer ·")
                Text("▼").foregroundStyle(GTColor.accentGreen)
                Text("günstiger")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(GTColor.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    // MARK: - Card

    private func categoryCard(_ category: CategoryMonthly) -> some View {
        let amounts = category.amounts
        let current = amounts.last ?? 0
        let base = amounts.dropLast()
        let average = base.isEmpty ? 0 : base.reduce(0, +) / Double(base.count)
        let maxAmount = amounts.max() ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.categoryName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(GTColor.textPrimary)
                    Text("\(currentLabel) CHF \(formatAmount(current)) · Ø CHF \(formatAmount(average))")
                        .font(.system(size: 12))
                        .foregroundStyle(GTColor.textSecondary)
                }

                Spacer()

                deltaBadge(current: current, average: average)
            }

            VStack(spacing: 6) {
                ForEach(Array(amounts.enumerated()), id: \.offset) { index, amount in
                    let isCurrent = index == amounts.count - 1
                    HStack(spacing: 10) {
                        Text(monthLabel(comparison.months[index]))
                            .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                            .foregroundStyle(isCurrent ? GTColor.accentCyan : GTColor.textSecondary)
                            .frame(width: 48, alignment: .leading)

                        bar(amount: amount, average: average, maxAmount: maxAmount, isCurrent: isCurrent)

                        Text(formatAmount(amount))
                            .font(.system(size: 13, weight: isCurrent ? .bold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(GTColor.textPrimary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func bar(amount: Double, average: Double, maxAmount: Double, isCurrent: Bool) -> some View {
        GeometryReader { geo in
            let fill = maxAmount > 0 ? amount / maxAmount : 0
            let averagePosition = maxAmount > 0 ? average / maxAmount : 0

            ZStack(alignment: .leading) {
                Capsule().fill(GTColor.bgHover)
                Capsule()
                    .fill(isCurrent ? GTColor.accentCyan : Self.barColor)
                    .frame(width: geo.size.width * fill)
                if average > 0 {
                    Rectangle()
                        .fill(Self.averageColor)
                        .frame(width: 2, height: 16)
                        .offset(x: geo.size.width * averagePosition - 1)
                }
            }
        }
        .frame(height: 10)
    }

    @ViewBuilder
    private func deltaBadge(current: Double, average: Double) -> some View {
        let (text, color): (String, Color) = {
            guard average > 0 else {
                return current > 0 ? ("neu", GTColor.accentRed) : ("–", GTColor.textSecondary)
            }
            let percent = Int(((current - average) / average * 100).rounded())
            if percent > 0 { return ("▲ +\(percent)%", GTColor.accentRed) }
            if percent < 0 { return ("▼ \(percent)%", GTColor.accentGreen) }
            return ("0%", GTColor.textSecondary)
        }()

        Text(text)
            .font(.system(size: 13, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Formatting

    private var currentLabel: String {
        comparison.months.last.map(monthLabel) ?? ""
    }

    private var baseRangeLabel: String {
        let base = comparison.months.dropLast()
        guard let first = base.first, let last = base.last else { return "" }
        return first == last ? monthLabel(first) : "\(monthLabel(first))–\(monthLabel(last))"
    }

    /// "2026-07" -> "Jul"; months from another year than the anchor month get the year appended ("Nov 25").
    private func monthLabel(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), (1...12).contains(month) else { return key }
        let names = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
        let anchorYear = comparison.months.last?.split(separator: "-").first
        if let anchorYear, parts[0] != anchorYear {
            return "\(names[month - 1]) \(parts[0].suffix(2))"
        }
        return names[month - 1]
    }

    private func formatAmount(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}
