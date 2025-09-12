import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Statistics Overview
                    StatisticsOverview()
                    
                    // Sleep Trends Chart
                    SleepTrendsChart()
                    
                    // Coffee Consumption Chart
                    CoffeeConsumptionChart()
                    
                    // Performance Metrics
                    PerformanceMetrics()
                    
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
            await viewModel.loadDashboardData()
        }
    }
}

// MARK: - Statistics Overview

struct StatisticsOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistici Săptămânale")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Cafele Totale",
                    value: "23",
                    change: "+15%",
                    changeType: .positive,
                    icon: "cup.and.saucer.fill"
                )
                
                StatCard(
                    title: "Somn Mediu",
                    value: "7.2h",
                    change: "+8%",
                    changeType: .positive,
                    icon: "moon.zzz.fill"
                )
                
                StatCard(
                    title: "Calitate Somn",
                    value: "78%",
                    change: "-3%",
                    changeType: .negative,
                    icon: "star.fill"
                )
                
                StatCard(
                    title: "Auto Comenzi",
                    value: "67%",
                    change: "+12%",
                    changeType: .positive,
                    icon: "gear.badge.checkmark"
                )
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
                    .foregroundColor(.blue)
                
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
        case .positive: return .green
        case .negative: return .red
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
                                .fill(.blue.gradient)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consumul de Cafea")
                .font(.headline)
            
            // Pie chart placeholder
            HStack {
                VStack(spacing: 8) {
                    CoffeeTypeRow(type: .latte, count: 8, percentage: 35, color: .brown)
                    CoffeeTypeRow(type: .espressoLung, count: 10, percentage: 43, color: .orange)
                    CoffeeTypeRow(type: .espressoScurt, count: 5, percentage: 22, color: .red)
                }
                
                Spacer()
                
                // Simplified pie chart representation
                ZStack {
                    Circle()
                        .fill(.brown)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(.orange, lineWidth: 20)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    Circle()
                        .trim(from: 0, to: 0.22)
                        .stroke(.red, lineWidth: 20)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(144))
                    
                    Text("23")
                        .font(.title2)
                        .fontWeight(.bold)
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

struct PerformanceMetrics: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performanța Sistemului")
                .font(.headline)
            
            VStack(spacing: 12) {
                PerformanceRow(
                    title: "Timp Răspuns ESP32",
                    value: "1.2s",
                    status: .good,
                    description: "Mediu ultimele 24h"
                )
                
                PerformanceRow(
                    title: "Rata de Succes",
                    value: "98.5%",
                    status: .excellent,
                    description: "Comenzi executate cu succes"
                )
                
                PerformanceRow(
                    title: "Acuratețe Detectare",
                    value: "87%",
                    status: .good,
                    description: "Treziri detectate corect"
                )
                
                PerformanceRow(
                    title: "Uptime ESP32",
                    value: "23.5h",
                    status: .excellent,
                    description: "Fără restart din ieri"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

enum PerformanceStatus {
    case excellent, good, warning, poor
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .poor: return .red
        }
    }
}

#Preview {
    DashboardView()
}
