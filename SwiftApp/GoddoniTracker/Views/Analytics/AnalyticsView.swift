import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AnalyticsViewModel()
    @State private var budgetExpanded = false

    var body: some View {
        ZStack {
            GTColor.bgDeepest.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    periodSelector

                    if let summary = viewModel.summary {
                        budgetSection(summary: summary)

                        HStack {
                            Text("Total: CHF \(String(format: "%.2f", summary.total))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(GTColor.accentCyan)

                            Spacer()

                            if viewModel.period == .month {
                                HStack(spacing: 12) {
                                    Button { viewModel.goToPreviousMonth() } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(GTColor.textSecondary)
                                    }
                                    Text(viewModel.monthLabel)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(GTColor.textPrimary)
                                    Button { viewModel.goToNextMonth() } label: {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(GTColor.textSecondary)
                                    }
                                }
                            }
                        }

                        if !summary.categories.isEmpty {
                            donutChart(categories: summary.categories)
                        }

                        categoryList(categories: summary.categories)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .tint(GTColor.accentCyan)
                            .padding(.top, 40)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
                    .foregroundStyle(GTColor.textSecondary)
            }
        }
        .onAppear {
            Task { await viewModel.load(api: api) }
        }
        .onChange(of: viewModel.currentMonth) {
            Task { await viewModel.load(api: api) }
        }
        .onChange(of: viewModel.period) {
            Task { await viewModel.load(api: api) }
        }
    }

    private var periodSelector: some View {
        HStack {
            Text("Zeitraum")
                .font(.system(size: 13))
                .foregroundStyle(GTColor.textSecondary)

            Spacer()

            Picker("", selection: $viewModel.period) {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
    }


    private func donutChart(categories: [CategoryBreakdown]) -> some View {
        let colors: [Color] = [
            GTColor.accentCyan, GTColor.accentViolet, GTColor.accentGreen,
            GTColor.accentRed, Color(hex: 0xF59E0B), Color(hex: 0xEC4899),
            Color(hex: 0x14B8A6), Color(hex: 0x6366F1), Color(hex: 0xA855F7),
            Color(hex: 0x84CC16), Color(hex: 0xF97316), Color(hex: 0x22D3EE),
        ]

        return ZStack {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                let startAngle = startAngle(for: index, categories: categories)
                let endAngle = startAngle + Angle(degrees: cat.percentage / 100 * 360)
                let color = colors[index % colors.count]

                Path { path in
                    path.addArc(center: CGPoint(x: 100, y: 100), radius: 80,
                                startAngle: startAngle, endAngle: endAngle, clockwise: false)
                }
                .stroke(color, lineWidth: 28)
            }
        }
        .frame(width: 200, height: 200)
        .padding(.vertical, 8)
    }

    private func startAngle(for index: Int, categories: [CategoryBreakdown]) -> Angle {
        let precedingPercentage = categories.prefix(index).reduce(0) { $0 + $1.percentage }
        return Angle(degrees: precedingPercentage / 100 * 360 - 90)
    }

    private func categoryList(categories: [CategoryBreakdown]) -> some View {
        VStack(spacing: 0) {
            ForEach(categories) { cat in
                NavigationLink {
                    CategoryDetailView(
                        categoryId: cat.categoryId,
                        categoryName: cat.categoryName,
                        month: viewModel.period == .allTime ? nil : viewModel.currentMonth.monthKey
                    )
                } label: {
                    HStack {
                        Text(cat.categoryName)
                            .font(.system(size: 15))
                            .foregroundStyle(GTColor.textPrimary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("CHF \(String(format: "%.2f", cat.total))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(GTColor.textPrimary)
                            Text("\(String(format: "%.1f", cat.percentage))%")
                                .font(.system(size: 12))
                                .foregroundStyle(GTColor.textMuted)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(GTColor.textMuted)
                    }
                }
                .padding(.vertical, 10)

                if cat.id != categories.last?.id {
                    Divider().overlay(GTColor.borderSubtle)
                }
            }
        }
    }

    private func budgetSection(summary: AnalyticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GTColor.textPrimary)
                Spacer()
                Image(systemName: budgetExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(GTColor.textMuted)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) { budgetExpanded.toggle() }
            }

            if let budget = summary.budget, let usedPercent = summary.budgetUsedPercent {
                ProgressView(value: min(usedPercent, 100), total: 100)
                    .tint(usedPercent > 100 ? GTColor.accentRed : GTColor.accentCyan)

                HStack {
                    Text("CHF \(String(format: "%.2f", summary.total)) / \(String(format: "%.0f", budget))")
                        .font(.system(size: 13))
                        .foregroundStyle(GTColor.textSecondary)
                    Spacer()
                    Text("\(String(format: "%.0f", usedPercent))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(usedPercent > 100 ? GTColor.accentRed : GTColor.accentCyan)
                }
            } else {
                Text("Kein Budget gesetzt")
                    .font(.system(size: 13))
                    .foregroundStyle(GTColor.textMuted)
            }

            Divider().overlay(GTColor.borderSubtle)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tagesdurchschnitt")
                        .font(.system(size: 12))
                        .foregroundStyle(GTColor.textMuted)
                    Text("CHF \(String(format: "%.2f", summary.dailyAverage))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(GTColor.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Hochrechnung Monat")
                        .font(.system(size: 12))
                        .foregroundStyle(GTColor.textMuted)
                    Text("CHF \(String(format: "%.2f", summary.projectedMonthly))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(summary.budget != nil && summary.projectedMonthly > (summary.budget ?? 0)
                            ? GTColor.accentRed : GTColor.textPrimary)
                }
            }

            if budgetExpanded && !summary.dailyCumulative.isEmpty {
                Divider().overlay(GTColor.borderSubtle)

                Text("Monatsverlauf")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GTColor.textPrimary)

                budgetChart(summary: summary)

                if let budget = summary.budget {
                    let allowedPerDay = budget / Double(daysInCurrentMonth)
                    Divider().overlay(GTColor.borderSubtle)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Erlaubt pro Tag")
                                .font(.system(size: 12))
                                .foregroundStyle(GTColor.textMuted)
                            Text("CHF \(String(format: "%.2f", allowedPerDay))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(GTColor.textPrimary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Status")
                                .font(.system(size: 12))
                                .foregroundStyle(GTColor.textMuted)
                            Text(summary.projectedMonthly <= budget ? "Im Rahmen" : "Über Budget")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(summary.projectedMonthly <= budget ? GTColor.accentGreen : GTColor.accentRed)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func budgetChart(summary: AnalyticsSummary) -> some View {
        let data = summary.dailyCumulative
        let maxDay = daysInCurrentMonth
        let budget = summary.budget

        return Chart {
            ForEach(data) { point in
                if let day = point.day {
                    LineMark(
                        x: .value("Tag", day),
                        y: .value("CHF", point.cumulative)
                    )
                    .foregroundStyle(GTColor.accentCyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Tag", day),
                        y: .value("CHF", point.cumulative)
                    )
                    .foregroundStyle(GTColor.accentCyan.opacity(0.1))
                }
            }

            if let budget {
                RuleMark(y: .value("Budget", budget))
                    .foregroundStyle(GTColor.accentRed.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                ForEach([1, maxDay], id: \.self) { day in
                    LineMark(
                        x: .value("Tag", day),
                        y: .value("Soll", budget / Double(maxDay) * Double(day))
                    )
                    .foregroundStyle(GTColor.textMuted.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
        }
        .chartXScale(domain: 1...maxDay)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(.system(size: 9))
                            .foregroundStyle(GTColor.textMuted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 5)) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.system(size: 9))
                            .foregroundStyle(GTColor.textMuted)
                    }
                }
            }
        }
        .frame(height: 180)
    }

    private var daysInCurrentMonth: Int {
        let cal = Calendar.current
        let d = viewModel.currentMonth
        return cal.range(of: .day, in: .month, for: d)?.count ?? 30
    }
}
