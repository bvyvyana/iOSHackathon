import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Statistics Overview
                    StatisticsOverview(viewModel: viewModel)
                    
                    // Sleep Trends Chart
                    SleepTrendsChart()
                    
                    // Coffee Consumption Chart
                    CoffeeConsumptionChart(viewModel: viewModel)
                    
                    // Performance Metrics
                    PerformanceMetricsView(viewModel: viewModel)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("📊 Dashboard")
            .refreshable {
                await viewModel.refreshData()
            }
        }
        .task {
            do {
                try await viewModel.loadDashboardData()
            } catch {
                print("Error loading dashboard data: \(error)")
            }
        }
    }
}

// MARK: - Statistics Overview

struct StatisticsOverview: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistici Săptămânale")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let dashboardData = viewModel.dashboardData {
                    StatCard(
                        title: "Cafele Totale",
                        value: "\(dashboardData.coffeeStatistics.totalCups)",
                        change: dashboardData.coffeeStatistics.consumptionTrend == .improving ? "+15%" : 
                               dashboardData.coffeeStatistics.consumptionTrend == .stable ? "0%" : "-5%",
                        changeType: dashboardData.coffeeStatistics.consumptionTrend == .improving ? .positive : 
                                   dashboardData.coffeeStatistics.consumptionTrend == .stable ? .neutral : .negative,
                        icon: "cup.and.saucer.fill"
                    )
                    
                    StatCard(
                        title: "Somn Mediu",
                        value: dashboardData.sleepStatistics.formattedDuration,
                        change: dashboardData.sleepStatistics.durationTrend == .improving ? "+8%" : 
                               dashboardData.sleepStatistics.durationTrend == .stable ? "0%" : "-3%",
                        changeType: dashboardData.sleepStatistics.durationTrend == .improving ? .positive : 
                                   dashboardData.sleepStatistics.durationTrend == .stable ? .neutral : .negative,
                        icon: "moon.zzz.fill"
                    )
                    
                    StatCard(
                        title: "Calitate Somn",
                        value: "\(Int(dashboardData.sleepStatistics.averageQuality))%",
                        change: dashboardData.sleepStatistics.qualityTrend == .improving ? "+5%" : 
                               dashboardData.sleepStatistics.qualityTrend == .stable ? "0%" : "-3%",
                        changeType: dashboardData.sleepStatistics.qualityTrend == .improving ? .positive : 
                                   dashboardData.sleepStatistics.qualityTrend == .stable ? .neutral : .negative,
                        icon: "star.fill"
                    )
                    
                    StatCard(
                        title: "Auto Comenzi",
                        value: "\(Int(dashboardData.coffeeStatistics.autoOrderPercentage))%",
                        change: dashboardData.coffeeStatistics.autoOrderPercentage > 50 ? "+12%" : "-5%",
                        changeType: dashboardData.coffeeStatistics.autoOrderPercentage > 50 ? .positive : .negative,
                        icon: "gear.badge.checkmark"
                    )
                } else {
                    // Loading state
                    ForEach(0..<4, id: \.self) { _ in
                        StatCard(
                            title: "Se încarcă...",
                            value: "--",
                            change: "--",
                            changeType: .neutral,
                            icon: "hourglass"
                        )
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let change: String
    let changeType: ChangeType
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color.primaryBlue)
                
                Spacer()
                
                Text(change)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(changeType.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(changeType.color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

enum ChangeType {
    case positive, negative, neutral
    
    var color: Color {
        switch self {
        case .positive: return Color.primaryGreen
        case .negative: return Color.primaryRed
        case .neutral: return .gray
        }
    }
}

// MARK: - Sleep Trends Chart

struct SleepTrendsChart: View {
    @State private var selectedTimeRange: TimeRange = .week
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tendințe Somn")
                    .font(.headline)
                
                Spacer()
                
                Picker("Perioada", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Chart placeholder - în iOS 16+ ai putea folosi Swift Charts
            VStack {
                Text("Grafic Tendințe Somn")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Simulare grafic
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7) { day in
                        VStack {
                            Rectangle()
                                .fill(Color.primaryBlue.gradient)
                                .frame(width: 30, height: CGFloat.random(in: 40...120))
                            
                            Text("L\(day + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .background(.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

enum TimeRange: CaseIterable {
    case week, month, quarter
    
    var displayName: String {
        switch self {
        case .week: return "7 zile"
        case .month: return "30 zile"
        case .quarter: return "3 luni"
        }
    }
}

// MARK: - Coffee Consumption Chart

struct CoffeeConsumptionChart: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consumul de Cafea")
                .font(.headline)
            
            // Pie chart placeholder
            HStack {
                if let coffeeStats = viewModel.dashboardData?.coffeeStatistics {
                    VStack(spacing: 8) {
                        CoffeeTypeRow(
                            type: .latte, 
                            count: coffeeStats.latteCount, 
                            percentage: coffeeStats.totalCups > 0 ? Int(Double(coffeeStats.latteCount) / Double(coffeeStats.totalCups) * 100) : 0, 
                            color: Color(red: 0.8, green: 0.6, blue: 0.4)
                        )
                        CoffeeTypeRow(
                            type: .espressoLung, 
                            count: coffeeStats.espressoLungCount, 
                            percentage: coffeeStats.totalCups > 0 ? Int(Double(coffeeStats.espressoLungCount) / Double(coffeeStats.totalCups) * 100) : 0, 
                            color: Color.primaryOrange
                        )
                        CoffeeTypeRow(
                            type: .espressoScurt, 
                            count: coffeeStats.espressoScurtCount, 
                            percentage: coffeeStats.totalCups > 0 ? Int(Double(coffeeStats.espressoScurtCount) / Double(coffeeStats.totalCups) * 100) : 0, 
                            color: Color.primaryRed
                        )
                    }
                    
                    Spacer()
                    
                    // Simplified pie chart representation
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.8, green: 0.6, blue: 0.4))
                            .frame(width: 100, height: 100)
                        
                        if coffeeStats.totalCups > 0 {
                            let espressoLungPercentage = Double(coffeeStats.espressoLungCount) / Double(coffeeStats.totalCups)
                            let espressoScurtPercentage = Double(coffeeStats.espressoScurtCount) / Double(coffeeStats.totalCups)
                            
                            Circle()
                                .trim(from: 0, to: espressoLungPercentage)
                                .stroke(Color.primaryOrange, lineWidth: 20)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            Circle()
                                .trim(from: 0, to: espressoScurtPercentage)
                                .stroke(Color.primaryRed, lineWidth: 20)
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(Double(coffeeStats.espressoLungCount) / Double(coffeeStats.totalCups) * 360 - 90))
                        }
                        
                        Text("\(coffeeStats.totalCups)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            CoffeeTypeRow(type: .latte, count: 0, percentage: 0, color: .gray)
                        }
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                        
                        Text("--")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct CoffeeTypeRow: View {
    let type: CoffeeType
    let count: Int
    let percentage: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(type.displayName)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count) (\(percentage)%)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Performance Metrics

struct PerformanceMetricsView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performanța Sistemului")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let performanceMetrics = viewModel.dashboardData?.performanceMetrics {
                    PerformanceRow(
                        title: "Timp Răspuns ESP32",
                        value: String(format: "%.2fs", performanceMetrics.esp32ResponseTime),
                        status: performanceMetrics.responseTimeStatus,
                        description: "Mediu ultimele comenzi"
                    )
                    
                    PerformanceRow(
                        title: "Rata de Succes",
                        value: String(format: "%.1f%%", performanceMetrics.successRate),
                        status: performanceMetrics.successRateStatus,
                        description: "Comenzi executate cu succes"
                    )
                    
                    PerformanceRow(
                        title: "Acuratețe Detectare",
                        value: String(format: "%.0f%%", performanceMetrics.wakeDetectionAccuracy),
                        status: performanceMetrics.wakeDetectionAccuracy >= 85 ? .excellent : 
                                performanceMetrics.wakeDetectionAccuracy >= 70 ? .good : 
                                performanceMetrics.wakeDetectionAccuracy >= 50 ? .warning : .poor,
                        description: "Treziri detectate corect"
                    )
                    
                    PerformanceRow(
                        title: "Uptime ESP32",
                        value: formatUptime(performanceMetrics.esp32Uptime),
                        status: performanceMetrics.esp32Uptime >= 20 ? .excellent :
                                performanceMetrics.esp32Uptime >= 10 ? .good :
                                performanceMetrics.esp32Uptime >= 5 ? .warning : .poor,
                        description: "Timp funcționare continuă"
                    )
                } else {
                    // Loading state
                    ForEach(0..<4, id: \.self) { _ in
                        PerformanceRow(
                            title: "Se încarcă...",
                            value: "--",
                            status: .warning,
                            description: "Obținere date..."
                        )
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatUptime(_ uptime: Double) -> String {
        let hours = Int(uptime)
        let minutes = Int((uptime - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
}

struct PerformanceRow: View {
    let title: String
    let value: String
    let status: PerformanceStatus
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(status.color)
        }
        .padding(.vertical, 4)
    }
}


#Preview {
    DashboardView()
}
