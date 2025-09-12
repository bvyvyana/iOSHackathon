import Foundation
import UIKit

/// Tipurile de cafea disponibile
enum CoffeeType: String, CaseIterable, Codable {
    case latte = "latte"
    case espressoLung = "lung"
    case espressoScurt = "scurt"
    
    var displayName: String {
        switch self {
        case .latte:
            return "Latte"
        case .espressoLung:
            return "Espresso Lung"
        case .espressoScurt:
            return "Espresso Scurt"
        }
    }
    
    var caffeineContent: Double {
        switch self {
        case .latte:
            return 63.0        // mg cafeină
        case .espressoLung:
            return 77.0
        case .espressoScurt:
            return 63.0
        }
    }
    
    var description: String {
        switch self {
        case .latte:
            return "Cafea cu lapte pentru o trezire blândă"
        case .espressoLung:
            return "Espresso clasic pentru energie constantă"
        case .espressoScurt:
            return "Shot de energie concentrată"
        }
    }
    
    var emoji: String {
        switch self {
        case .latte:
            return "🥛"
        case .espressoLung:
            return "☕️"
        case .espressoScurt:
            return "⚡️"
        }
    }
}

/// Tipul de trigger pentru comandă
enum TriggerType: String, Codable {
    case auto = "auto"              // Trigger automat din analiza somnului
    case manual = "manual"          // Comandă manuală din app
    case override = "override"      // Override user peste recomandare auto
    case emergency = "emergency"    // Comandă de urgență
    
    var displayName: String {
        switch self {
        case .auto:
            return "Automat"
        case .manual:
            return "Manual"
        case .override:
            return "Suprascris"
        case .emergency:
            return "Urgență"
        }
    }
}

/// Recomandarea algoritmului pentru cafea
struct CoffeeRecommendation {
    var type: CoffeeType
    var strength: Double              // 0-1 scala intensității
    var urgency: Double               // 0-1 scala urgenței
    let confidence: Double            // 0-1 încrederea algoritmului
    var reasoning: String             // Explicația recomandării
    let sleepFactors: SleepFactors    // Factorii de somn care au influențat decizia
    let timeFactors: TimeFactors      // Factorii temporali
    
    var strengthDescription: String {
        switch strength {
        case 0..<0.3:
            return "Slabă"
        case 0.3..<0.6:
            return "Medie"
        case 0.6..<0.8:
            return "Tare"
        default:
            return "Foarte tare"
        }
    }
    
    var urgencyDescription: String {
        switch urgency {
        case 0..<0.3:
            return "Relaxată"
        case 0.3..<0.6:
            return "Moderată"
        case 0.6..<0.8:
            return "Urgentă"
        default:
            return "Foarte urgentă"
        }
    }
    
    /// Estimează timpul până la efectul complet al cofeinei
    var estimatedEffectTime: TimeInterval {
        // Cafeina ajunge la concentrația maximă în 15-45 minute
        let baseTime: TimeInterval = 1800 // 30 minute
        let strengthModifier = strength * 900 // +15 minute pentru cafea tare
        
        return baseTime + strengthModifier
    }
}

/// Factorii de somn care influențează recomandarea
struct SleepFactors {
    let duration: Double              // Durata somnului în ore
    let quality: Double               // Calitatea 0-100
    let deepSleepPercent: Double      // % somn profund
    let remSleepPercent: Double       // % somn REM
    let averageHeartRate: Double      // BPM mediu
    let wakeUpTime: Date?             // Momentul trezirii
    
    var isDurationOptimal: Bool {
        return duration >= 7.0 && duration <= 9.0
    }
    
    var isQualityGood: Bool {
        return quality >= 70.0
    }
    
    var hasAdequateDeepSleep: Bool {
        return deepSleepPercent >= 15.0 && deepSleepPercent <= 25.0
    }
    
    var hasAdequateREMSleep: Bool {
        return remSleepPercent >= 20.0 && remSleepPercent <= 25.0
    }
}

/// Factorii temporali care influențează recomandarea
struct TimeFactors {
    let currentTime: Date
    let isWeekend: Bool
    let hourOfDay: Int
    let minutesSinceWake: Int?
    
    var isOptimalCoffeeTime: Bool {
        // Timpul optim pentru cafea: 6-10 AM
        return hourOfDay >= 6 && hourOfDay <= 10
    }
    
    var isLateInDay: Bool {
        // După ora 14, cafeina poate afecta somnul
        return hourOfDay >= 14
    }
    
    var shouldReduceCaffeine: Bool {
        return isLateInDay || isWeekend
    }
}

/// Răspunsul de la ESP32 pentru comandă de cafea
struct CoffeeResponse: Codable {
    let status: CoffeeCommandStatus
    let message: String
    let triggerType: String
    let estimatedCompletion: String?
    let errorCode: Int?
    let timestamp: Date
    
    var isSuccess: Bool {
        return status == .success
    }
    
    var isInProgress: Bool {
        return status == .inProgress
    }
    
    var hasError: Bool {
        return status == .error
    }
}

enum CoffeeCommandStatus: String, Codable {
    case success = "success"
    case error = "error"
    case inProgress = "in_progress"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .success:
            return "Succes"
        case .error:
            return "Eroare"
        case .inProgress:
            return "În curs"
        case .cancelled:
            return "Anulat"
        }
    }
}

/// Comanda trimisă către ESP32
struct CoffeeCommand: Codable {
    let command: String               // "make_coffee"
    let type: String                  // CoffeeType.rawValue
    let trigger: String               // TriggerType.rawValue
    let sleepScore: Double?           // Scorul calității somnului
    let timestamp: String             // ISO8601
    let userId: String                // ID unic al utilizatorului
    let requestId: String             // ID unic al cererii
    
    init(type: CoffeeType, trigger: TriggerType, sleepScore: Double?, userId: String) {
        self.command = "make_coffee"
        self.type = type.rawValue
        self.trigger = trigger.rawValue
        self.sleepScore = sleepScore
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.userId = userId
        self.requestId = UUID().uuidString
    }
}

/// Setările utilizatorului pentru preferințe de cafea
struct UserCoffeePreferences: Codable {
    var preferredType: CoffeeType?           // Tipul preferat
    var maxCaffeinePerDay: Double            // mg max pe zi
    var preferredStrength: Double            // 0-1 intensitatea preferată
    var autoModeEnabled: Bool                // Activează modul automat
    var requireConfirmation: Bool            // Necesită confirmare pentru auto
    var countdownDuration: TimeInterval      // Durata countdown-ului
    var autoOnlyOnWeekdays: Bool            // Auto doar în zilele de lucru
    var preferredWakeTime: Date?            // Ora preferată de trezire
    var lastUpdated: Date
    
    init() {
        self.preferredType = nil
        self.maxCaffeinePerDay = 400.0      // Limita FDA recomandată
        self.preferredStrength = 0.6
        self.autoModeEnabled = true
        self.requireConfirmation = true
        self.countdownDuration = 30.0       // 30 secunde
        self.autoOnlyOnWeekdays = false
        self.preferredWakeTime = nil
        self.lastUpdated = Date()
    }
    
    /// Verifică dacă utilizatorul a depășit limita zilnică de cafeină
    func hasExceededDailyCaffeineLimit(consumedToday: Double) -> Bool {
        return consumedToday >= maxCaffeinePerDay
    }
    
    /// Calculează cafeina rămasă permisă pentru azi
    func remainingCaffeineToday(consumedToday: Double) -> Double {
        return max(0, maxCaffeinePerDay - consumedToday)
    }
}

/// Statisticile zilnice de consum de cafea
struct DailyCoffeeStats {
    let date: Date
    let totalCups: Int
    let autoCups: Int
    let manualCups: Int
    let totalCaffeine: Double           // mg
    let averageResponseTime: TimeInterval
    let successRate: Double             // 0-1
    let mostConsumedType: CoffeeType?
    let peakConsumptionHour: Int?
    
    var cupsByType: [CoffeeType: Int] {
        // TODO: Calculate from actual data
        return [:]
    }
    
    var isHealthyConsumption: Bool {
        return totalCaffeine <= 400.0 && totalCups <= 4
    }
}

/// Setările pentru conexiunea ESP32
struct ESP32ConnectionSettings: Codable {
    var baseURL: String
    var port: Int
    var discoveryEnabled: Bool
    var connectionTimeout: TimeInterval
    var commandTimeout: TimeInterval
    var retryAttempts: Int
    var lastSuccessfulConnection: Date?
    var lastKnownIP: String?
    var useHTTPS: Bool
    var customEndpoints: [String: String]
    var lastUpdated: Date
    
    init() {
        self.baseURL = "http://192.168.1.100"
        self.port = 80
        self.discoveryEnabled = true
        self.connectionTimeout = 5.0
        self.commandTimeout = 10.0
        self.retryAttempts = 3
        self.lastSuccessfulConnection = nil
        self.lastKnownIP = nil
        self.useHTTPS = false
        self.customEndpoints = [
            "coffee": "/coffee/make",
            "status": "/status",
            "health": "/health",
            "settings": "/settings",
            "test": "/test"
        ]
        self.lastUpdated = Date()
    }
    
    /// URL complet pentru conexiunea ESP32
    var fullURL: String {
        let scheme = useHTTPS ? "https" : "http"
        let cleanURL = baseURL.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        
        if port == 80 && !useHTTPS || port == 443 && useHTTPS {
            return "\(scheme)://\(cleanURL)"
        } else {
            return "\(scheme)://\(cleanURL):\(port)"
        }
    }
    
    /// Validează setările conexiunii
    func validate() -> [String] {
        var errors: [String] = []
        
        // Validare URL
        if baseURL.isEmpty {
            errors.append("URL-ul ESP32 nu poate fi gol")
        } else if !isValidURL(baseURL) {
            errors.append("URL-ul ESP32 nu este valid")
        }
        
        // Validare port
        if port < 1 || port > 65535 {
            errors.append("Portul trebuie să fie între 1 și 65535")
        }
        
        // Validare timeout-uri
        if connectionTimeout < 1.0 || connectionTimeout > 30.0 {
            errors.append("Timeout-ul de conexiune trebuie să fie între 1-30 secunde")
        }
        
        if commandTimeout < 1.0 || commandTimeout > 60.0 {
            errors.append("Timeout-ul pentru comenzi trebuie să fie între 1-60 secunde")
        }
        
        // Validare retry attempts
        if retryAttempts < 0 || retryAttempts > 10 {
            errors.append("Numărul de încercări trebuie să fie între 0-10")
        }
        
        return errors
    }
    
    /// Verifică dacă URL-ul este valid
    private func isValidURL(_ urlString: String) -> Bool {
        // Remove protocol if present for validation
        let cleanURL = urlString.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        
        // Check for IP address pattern
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        if cleanURL.range(of: ipPattern, options: .regularExpression) != nil {
            // Validate IP address ranges
            let components = cleanURL.split(separator: ".").compactMap { Int($0) }
            return components.count == 4 && components.allSatisfy { $0 >= 0 && $0 <= 255 }
        }
        
        // Check for hostname pattern
        let hostnamePattern = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#
        return cleanURL.range(of: hostnamePattern, options: .regularExpression) != nil
    }
    
    /// Generează endpoint-ul complet pentru o comandă
    func endpoint(for command: String) -> String {
        let endpoint = customEndpoints[command] ?? "/\(command)"
        return fullURL + endpoint
    }
}

/// Status-ul calității semnalului WiFi
enum WiFiSignalQuality {
    case excellent  // > -30 dBm
    case good      // -30 to -50 dBm
    case fair      // -50 to -60 dBm
    case weak      // -60 to -70 dBm
    case poor      // < -70 dBm
    
    init(rssi: Int) {
        switch rssi {
        case -30...0:
            self = .excellent
        case -50..<(-30):
            self = .good
        case -60..<(-50):
            self = .fair
        case -70..<(-60):
            self = .weak
        default:
            self = .poor
        }
    }
    
    var displayName: String {
        switch self {
        case .excellent: return "Excelent"
        case .good: return "Bun"
        case .fair: return "Acceptabil"
        case .weak: return "Slab"
        case .poor: return "Foarte slab"
        }
    }
    
    var color: UIColor {
        switch self {
        case .excellent: return .systemGreen
        case .good: return .systemGreen
        case .fair: return .systemYellow
        case .weak: return .systemOrange
        case .poor: return .systemRed
        }
    }
}

// MARK: - ESP32 Status Models


/// Metrici de sănătate ESP32
struct ESP32HealthMetrics: Codable {
    let wifiStrength: Int
    let uptime: Int
    let autoCommandsToday: Int
    let manualCommandsToday: Int
    let totalCommandsAllTime: Int
    let successRate: Double
    let averageResponseTime: Double
    let lastReboot: String
    let freeHeapMemory: Int
    let systemVoltage: Double?
    let temperature: Double?
    let connectionErrors: Int?
    let commandErrors: Int?
}