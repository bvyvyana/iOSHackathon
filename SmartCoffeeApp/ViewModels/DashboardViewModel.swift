import Foundation
import Combine
import SwiftUI

/// ViewModel pentru DashboardView - gestionează datele și logica de afișare pentru dashboard
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dashboardData: DashboardData?
    @Published var selectedTimeRange: TimeRange = .week
    
    private var cancellables = Set<AnyCancellable>()
    private let esp32Manager = ESP32CommunicationManager()
    private let persistenceController = PersistenceController.shared
    
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
            // Initialize ESP32 connection if not already connected
            if !esp32Manager.isConnected {
                _ = try? await esp32Manager.discoverESP32()
            }
            
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
        // Get real coffee data from Core Data
        let days = selectedTimeRange.numberOfDays
        let coffeeOrders = persistenceController.getCoffeeOrders(fromDays: days)
        
        let totalCups = coffeeOrders.count
        let autoCups = coffeeOrders.filter { $0.trigger == "auto" }.count
        let manualCups = coffeeOrders.filter { $0.trigger == "manual" }.count
        
        // Count coffee types from real data
        let latteCount = coffeeOrders.filter { $0.type == "latte" }.count
        let espressoLungCount = coffeeOrders.filter { $0.type == "espresso_large" }.count
        let espressoScurtCount = coffeeOrders.filter { $0.type == "espresso" }.count
        
        // Calculate average response time from real data
        let averageOrderTime = coffeeOrders.isEmpty ? 1.2 : 
            coffeeOrders.reduce(0.0) { $0 + $1.responseTime } / Double(coffeeOrders.count)
        
        let autoPercentage = totalCups > 0 ? Double(autoCups) / Double(totalCups) * 100 : 0
        let manualPercentage = 100 - autoPercentage
        
        // Calculate caffeine based on real coffee types
        let totalCaffeine = Double(latteCount) * CoffeeType.latte.caffeineContent + 
                           Double(espressoLungCount) * CoffeeType.espressoLung.caffeineContent + 
                           Double(espressoScurtCount) * CoffeeType.espressoScurt.caffeineContent
        
        // Determine trend based on recent vs older orders
        let recentOrders = coffeeOrders.filter { 
            $0.timestamp?.timeIntervalSinceNow ?? 0 > -86400 * 3 // Last 3 days
        }
        let recentAutoPercentage = recentOrders.isEmpty ? 0 : 
            Double(recentOrders.filter { $0.trigger == "auto" }.count) / Double(recentOrders.count) * 100
        
        let trend: Trend = recentAutoPercentage > autoPercentage + 5 ? .improving :
                          recentAutoPercentage < autoPercentage - 5 ? .declining : .stable
        
        return CoffeeStatistics(
            totalCups: totalCups,
            latteCount: latteCount,
            espressoLungCount: espressoLungCount,
            espressoScurtCount: espressoScurtCount,
            autoOrderPercentage: autoPercentage,
            manualOrderPercentage: manualPercentage,
            averageOrderTime: averageOrderTime,
            totalCaffeine: totalCaffeine,
            consumptionTrend: trend
        )
    }
    
    private func loadPerformanceMetrics() async throws -> PerformanceMetrics {
        // Get real performance data from ESP32 manager
        let esp32Metrics = esp32Manager.performanceMetrics
        
        // Use default WiFi strength based on connection status
        let wifiStrength = esp32Manager.isConnected ? -45 : -100
        
        // Calculate wake detection accuracy from real Core Data instead of ESP32Status
        let days = selectedTimeRange.numberOfDays
        let coffeeOrders = persistenceController.getCoffeeOrders(fromDays: days)
        let totalCoffees = coffeeOrders.count
        let autoCoffees = coffeeOrders.filter { $0.trigger == "auto" }.count
        
        var wakeDetectionAccuracy: Double = 0.0
        if totalCoffees > 0 {
            wakeDetectionAccuracy = Double(autoCoffees) / Double(totalCoffees) * 100
        }
        
        // Calculate real uptime from first connection, fallback to ESP32 manager uptime
        let realUptime = persistenceController.calculateRealESP32Uptime()
        let finalUptime = realUptime > 0 ? realUptime : esp32Metrics.uptime
        
        // Calculate response time from last 5 successful commands (with fallback)
        let last5ResponseTime = persistenceController.calculateLastNCommandsResponseTime(maxCommands: 5)
        let finalResponseTime = last5ResponseTime > 0 ? last5ResponseTime : esp32Metrics.responseTime
        
        return PerformanceMetrics(
            esp32ResponseTime: finalResponseTime,
            successRate: esp32Metrics.successRate,
            wakeDetectionAccuracy: wakeDetectionAccuracy,
            esp32Uptime: finalUptime,
            networkSignalStrength: wifiStrength,
            lastConnectionTest: esp32Metrics.lastUpdated,
            totalCommands: esp32Metrics.totalCommands,
            failedCommands: esp32Metrics.failedCommands
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
                espressoLungCount: Int.random(in: 0...2),
                espressoScurtCount: Int.random(in: 0...2),
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
        
        // Observer pentru actualizări performance ESP32
        NotificationCenter.default.publisher(for: .esp32PerformanceUpdated)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshPerformanceData()
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
    
    private func refreshPerformanceData() async {
        // Refresh doar datele de performance
        do {
            let performanceMetrics = try await loadPerformanceMetrics()
            dashboardData?.performanceMetrics = performanceMetrics
        } catch {
            print("Error refreshing performance data: \(error)")
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
    let espressoLungCount: Int
    let espressoScurtCount: Int
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

/// Status pentru performanța sistemului
enum PerformanceStatus {
    case excellent, good, warning, poor
    
    var color: Color {
        switch self {
        case .excellent: return Color.primaryGreen
        case .good: return Color.primaryBlue
        case .warning: return Color.primaryOrange
        case .poor: return Color.primaryRed
        }
    }
}
