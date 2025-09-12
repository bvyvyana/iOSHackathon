import Foundation
import Combine

/// ViewModel pentru DashboardView - gestionează datele și logica de afișare pentru dashboard
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dashboardData: DashboardData?
    @Published var selectedTimeRange: TimeRange = .week
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    // MARK: - Data Loading
    
    /// Încarcă toate datele pentru dashboard
    func loadDashboardData() async throws {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let sleepStats = try loadSleepStatistics()
            async let coffeeStats = try loadCoffeeStatistics()
            async let performanceData = try loadPerformanceMetrics()
            async let trends = try loadTrendData()
            
            let (sleep, coffee, performance, trendData) = try await (sleepStats, coffeeStats, performanceData, trends)
            
            dashboardData = DashboardData(
                sleepStatistics: sleep,
                coffeeStatistics: coffee,
                performanceMetrics: performance,
                trendData: trendData,
                lastUpdated: Date()
            )
            
        } catch {
            errorMessage = "Eroare la încărcarea dashboard-ului: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Reîmprospătează datele
    func refreshData() async {
        do {
            try await loadDashboardData()
        } catch {
            errorMessage = "Eroare la actualizarea datelor: \(error.localizedDescription)"
        }
    }
    
    /// Schimbă perioada de timp pentru analiza datelor
    func changeTimeRange(_ range: TimeRange) {
        selectedTimeRange = range
        
        Task {
            do {
                try await loadDashboardData()
            } catch {
                errorMessage = "Eroare la încărcarea datelor: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Loading Methods
    
    private func loadSleepStatistics() async throws -> SleepStatistics {
        // Simulare încărcare date somn
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return SleepStatistics(
            averageDuration: 7.2,
            averageQuality: 78.5,
            averageDeepSleep: 18.3,
            averageREMSleep: 22.1,
            totalSleepSessions: 7,
            qualityTrend: .improving,
            durationTrend: .stable
        )
    }
    
    private func loadCoffeeStatistics() async throws -> CoffeeStatistics {
        // Simulare încărcare date cafea
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return CoffeeStatistics(
            totalCups: 23,
            latteCount: 8,
            espressoLungCount: 10,
            espressoScurtCount: 5,
            autoOrderPercentage: 67.0,
            manualOrderPercentage: 33.0,
            averageOrderTime: 1.2,
            totalCaffeine: 1456.0,
            consumptionTrend: .improving
        )
    }
    
    private func loadPerformanceMetrics() async throws -> PerformanceMetrics {
        // Simulare încărcare metrici performance
        try await Task.sleep(nanoseconds: 200_000_000)
        
        return PerformanceMetrics(
            esp32ResponseTime: 1.2,
            successRate: 98.5,
            wakeDetectionAccuracy: 87.0,
            esp32Uptime: 23.5,
            networkSignalStrength: -45,
            lastConnectionTest: Date().addingTimeInterval(-300),
            totalCommands: 156,
            failedCommands: 2
        )
    }
    
    private func loadTrendData() async throws -> TrendData {
        // Simulare încărcare date trend
        try await Task.sleep(nanoseconds: 400_000_000)
        
        let sleepTrend = generateSleepTrendData()
        let coffeeTrend = generateCoffeeTrendData()
        
        return TrendData(
            sleepTrend: sleepTrend,
            coffeeTrend: coffeeTrend,
            period: selectedTimeRange
        )
    }
    
    private func generateSleepTrendData() -> [SleepTrendPoint] {
        let days = selectedTimeRange.numberOfDays
        
        return (0..<days).map { day in
            SleepTrendPoint(
                date: Calendar.current.date(byAdding: .day, value: -day, to: Date()) ?? Date(),
                duration: Double.random(in: 6.0...9.0),
                quality: Double.random(in: 60.0...95.0),
                deepSleepPercentage: Double.random(in: 15.0...25.0),
                remSleepPercentage: Double.random(in: 18.0...28.0)
            )
        }.reversed()
    }
    
    private func generateCoffeeTrendData() -> [CoffeeTrendPoint] {
        let days = selectedTimeRange.numberOfDays
        
        return (0..<days).map { day in
            CoffeeTrendPoint(
                date: Calendar.current.date(byAdding: .day, value: -day, to: Date()) ?? Date(),
                totalCups: Int.random(in: 0...5),
                latteCount: Int.random(in: 0...2),
                espressoCount: Int.random(in: 0...3),
                autoOrderCount: Int.random(in: 0...2),
                totalCaffeine: Double.random(in: 0...400)
            )
        }.reversed()
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observer pentru schimbări în datele de somn
        NotificationCenter.default.publisher(for: .sleepDataUpdated)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshSleepData()
                }
            }
            .store(in: &cancellables)
        
        // Observer pentru comenzi de cafea noi
        NotificationCenter.default.publisher(for: .coffeeOrderCompleted)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshCoffeeData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func refreshSleepData() async {
        // Refresh doar datele de somn
        do {
            let sleepStats = try await loadSleepStatistics()
            dashboardData?.sleepStatistics = sleepStats
        } catch {
            print("Error refreshing sleep data: \(error)")
        }
    }
    
    private func refreshCoffeeData() async {
        // Refresh doar datele de cafea
        do {
            let coffeeStats = try await loadCoffeeStatistics()
            dashboardData?.coffeeStatistics = coffeeStats
        } catch {
            print("Error refreshing coffee data: \(error)")
        }
    }
}

// MARK: - Data Models

/// Structura principală pentru datele dashboard-ului
struct DashboardData {
    var sleepStatistics: SleepStatistics
    var coffeeStatistics: CoffeeStatistics
    var performanceMetrics: PerformanceMetrics
    var trendData: TrendData
    var lastUpdated: Date
}

/// Statistici pentru somn
struct SleepStatistics {
    let averageDuration: Double        // ore
    let averageQuality: Double         // 0-100
    let averageDeepSleep: Double       // procent
    let averageREMSleep: Double        // procent
    let totalSleepSessions: Int
    let qualityTrend: Trend
    let durationTrend: Trend
    
    var formattedDuration: String {
        let hours = Int(averageDuration)
        let minutes = Int((averageDuration - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
    
    var qualityGrade: String {
        switch averageQuality {
        case 90...: return "Excelent"
        case 80..<90: return "Foarte bun"
        case 70..<80: return "Bun"
        case 60..<70: return "Acceptabil"
        default: return "Slab"
        }
    }
}

/// Statistici pentru consum de cafea
struct CoffeeStatistics {
    let totalCups: Int
    let latteCount: Int
    let espressoLungCount: Int
    let espressoScurtCount: Int
    let autoOrderPercentage: Double
    let manualOrderPercentage: Double
    let averageOrderTime: Double       // secunde
    let totalCaffeine: Double          // mg
    let consumptionTrend: Trend
    
    var mostConsumedType: CoffeeType {
        let counts = [
            (CoffeeType.latte, latteCount),
            (CoffeeType.espressoLung, espressoLungCount),
            (CoffeeType.espressoScurt, espressoScurtCount)
        ]
        
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? .latte
    }
    
    var isHealthyConsumption: Bool {
        return totalCaffeine <= 400.0 && totalCups <= 4
    }
    
    var dailyAverage: Double {
        return Double(totalCups) / 7.0
    }
}

/// Metrici de performanță pentru sistem
struct PerformanceMetrics {
    let esp32ResponseTime: Double      // secunde
    let successRate: Double            // procent
    let wakeDetectionAccuracy: Double  // procent
    let esp32Uptime: Double           // ore
    let networkSignalStrength: Int     // dBm
    let lastConnectionTest: Date
    let totalCommands: Int
    let failedCommands: Int
    
    var responseTimeStatus: PerformanceStatus {
        switch esp32ResponseTime {
        case 0...1.0: return .excellent
        case 1.0...2.0: return .good
        case 2.0...5.0: return .warning
        default: return .poor
        }
    }
    
    var successRateStatus: PerformanceStatus {
        switch successRate {
        case 95...: return .excellent
        case 90..<95: return .good
        case 80..<90: return .warning
        default: return .poor
        }
    }
    
    var signalQuality: String {
        switch networkSignalStrength {
        case -30...0: return "Excelent"
        case -50..<(-30): return "Bun"
        case -70..<(-50): return "Acceptabil"
        default: return "Slab"
        }
    }
}

/// Date pentru trend-uri și grafice
struct TrendData {
    let sleepTrend: [SleepTrendPoint]
    let coffeeTrend: [CoffeeTrendPoint]
    let period: TimeRange
}

struct SleepTrendPoint {
    let date: Date
    let duration: Double
    let quality: Double
    let deepSleepPercentage: Double
    let remSleepPercentage: Double
}

struct CoffeeTrendPoint {
    let date: Date
    let totalCups: Int
    let latteCount: Int
    let espressoCount: Int
    let autoOrderCount: Int
    let totalCaffeine: Double
}

enum Trend {
    case improving, stable, declining
    
    var displayText: String {
        switch self {
        case .improving: return "↗️ În creștere"
        case .stable: return "→ Stabil"
        case .declining: return "↘️ În scădere"
        }
    }
    
    var color: String {
        switch self {
        case .improving: return "green"
        case .stable: return "blue"
        case .declining: return "red"
        }
    }
}

// MARK: - Extensions

extension TimeRange {
    var numberOfDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

extension Notification.Name {
    static let sleepDataUpdated = Notification.Name("sleepDataUpdated")
    static let dashboardDataUpdated = Notification.Name("dashboardDataUpdated")
}
