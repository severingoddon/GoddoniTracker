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
                if viewModel.period == .month {
                    Image(systemName: budgetExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(GTColor.textMuted)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard viewModel.period == .month else { return }
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

            if budgetExpanded && viewModel.period == .month && !summary.dailyCumulative.isEmpty {
                Divider().overlay(GTColor.borderSubtle)

                Text("Monatsverlauf")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GTColor.textPrimary)

                budgetChart(summary: summary)

                if let budget = summary.budget {
                    let allowedPerDay = (budget - summary.total) / Double(remainingDaysInMonth)
                    Divider().overlay(GTColor.borderSubtle)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Erlaubt pro Tag")
                                .font(.system(size: 12))
                                .foregroundStyle(GTColor.textMuted)
                            Text("CHF \(String(format: "%.2f", allowedPerDay))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(allowedPerDay < 0 ? GTColor.accentRed : GTColor.textPrimary)
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
        let budget = summary.budget ?? summary.total * 1.5
        let prediction = predictionData(from: data)
        let yMax = max(budget, prediction.last?.cumulative ?? 0)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(GTColor.accentCyan).frame(width: 6, height: 6)
                    Text("Aktuell").font(.system(size: 10)).foregroundStyle(GTColor.textMuted)
                }
                HStack(spacing: 4) {
                    Circle().fill(GTColor.accentGreen).frame(width: 6, height: 6)
                    Text("Budget").font(.system(size: 10)).foregroundStyle(GTColor.textMuted)
                }
                if !prediction.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0xF59E0B)).frame(width: 6, height: 6)
                        Text("Vorhersage").font(.system(size: 10)).foregroundStyle(GTColor.textMuted)
                    }
                }
            }

            Chart {
                ForEach(data) { point in
                    if let day = point.day {
                        LineMark(
                            x: .value("Tag", day),
                            y: .value("CHF", point.cumulative),
                            series: .value("Serie", "Aktuell")
                        )
                        .foregroundStyle(GTColor.accentCyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }

                LineMark(
                    x: .value("Tag", 1),
                    y: .value("CHF", 0),
                    series: .value("Serie", "Budget")
                )
                .foregroundStyle(GTColor.accentGreen)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                LineMark(
                    x: .value("Tag", maxDay),
                    y: .value("CHF", budget),
                    series: .value("Serie", "Budget")
                )
                .foregroundStyle(GTColor.accentGreen)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                ForEach(0..<prediction.count, id: \.self) { i in
                    LineMark(
                        x: .value("Tag", prediction[i].day),
                        y: .value("CHF", prediction[i].cumulative),
                        series: .value("Serie", "Vorhersage")
                    )
                    .foregroundStyle(Color(hex: 0xF59E0B))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                }
            }
            .chartXScale(domain: 1...maxDay)
            .chartYScale(domain: 0...yMax)
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
    }

    private func predictionData(from data: [DailyCumulative]) -> [(day: Int, cumulative: Double)] {
        let cal = Calendar.current
        let now = Date()
        guard cal.isDate(viewModel.currentMonth, equalTo: now, toGranularity: .month) else { return [] }

        let currentDay = cal.component(.day, from: now)
        let maxDay = daysInCurrentMonth
        guard currentDay < maxDay else { return [] }

        let sorted = data.compactMap { point -> (day: Int, cumulative: Double)? in
            guard let day = point.day else { return nil }
            return (day, point.cumulative)
        }.sorted { $0.day < $1.day }

        guard sorted.count >= 2 else { return [] }

        var dailySpending: [(weekday: Int, amount: Double)] = []
        for i in 1..<sorted.count {
            let dayGap = sorted[i].day - sorted[i - 1].day
            guard dayGap > 0 else { continue }
            let spendingPerDay = (sorted[i].cumulative - sorted[i - 1].cumulative) / Double(dayGap)
            for d in sorted[i - 1].day..<sorted[i].day {
                var comps = cal.dateComponents([.year, .month], from: viewModel.currentMonth)
                comps.day = d + 1
                if let date = cal.date(from: comps) {
                    let wd = cal.component(.weekday, from: date)
                    dailySpending.append((weekday: wd, amount: spendingPerDay))
                }
            }
        }

        guard !dailySpending.isEmpty else { return [] }

        var weekdayData: [Int: [Double]] = [:]
        for entry in dailySpending {
            weekdayData[entry.weekday, default: []].append(entry.amount)
        }
        var weekdayAvg: [Int: Double] = [:]
        for (wd, amounts) in weekdayData {
            weekdayAvg[wd] = amounts.reduce(0, +) / Double(amounts.count)
        }

        let n = dailySpending.count
        var wSum = 0.0, wTotal = 0.0
        for (i, entry) in dailySpending.enumerated() {
            let w = exp(Double(i - n + 1) * 0.3)
            wSum += entry.amount * w
            wTotal += w
        }
        let weightedAvg = wTotal > 0 ? wSum / wTotal : 0

        let weekdayWeight = min(Double(n) / 14.0, 0.4)

        let lastPoint = sorted.last!
        var result: [(day: Int, cumulative: Double)] = [(lastPoint.day, lastPoint.cumulative)]
        var cumulative = lastPoint.cumulative

        for day in (lastPoint.day + 1)...maxDay {
            var comps = cal.dateComponents([.year, .month], from: viewModel.currentMonth)
            comps.day = day

            var predicted = weightedAvg
            if let date = cal.date(from: comps) {
                let wd = cal.component(.weekday, from: date)
                if let wdAvg = weekdayAvg[wd] {
                    predicted = weightedAvg * (1 - weekdayWeight) + wdAvg * weekdayWeight
                }
            }

            cumulative += max(0, predicted)
            result.append((day: day, cumulative: cumulative))
        }

        return result
    }

    private var daysInCurrentMonth: Int {
        let cal = Calendar.current
        let d = viewModel.currentMonth
        return cal.range(of: .day, in: .month, for: d)?.count ?? 30
    }

    private var remainingDaysInMonth: Int {
        let cal = Calendar.current
        let now = Date()
        if cal.isDate(viewModel.currentMonth, equalTo: now, toGranularity: .month) {
            return max(1, daysInCurrentMonth - cal.component(.day, from: now) + 1)
        }
        return daysInCurrentMonth
    }
}
