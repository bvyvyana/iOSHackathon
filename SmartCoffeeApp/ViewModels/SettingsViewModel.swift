import Foundation
import Combine
import UserNotifications

/// ViewModel pentru SettingsView - gestionează toate setările aplicației
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var notificationSettings = NotificationSettings()
    @Published var esp32Settings = ESP32ConnectionSettings()
    @Published var awakeStatus = AwakeStatus.awake
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var validationErrors: [String] = []
    @Published var connectionTestInProgress = false
    @Published var connectionTestResult: ConnectionTestResult?
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
        setupHealthKitIntegration()
    }
    
    // MARK: - Data Loading & Saving
    
    /// Încarcă toate setările din storage
    func loadSettings() async {
        isLoading = true
        
        do {
            
            
            // Load notification settings
            if let data = userDefaults.data(forKey: "notification_settings"),
               let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
                notificationSettings = settings
            }
            
            // Load ESP32 connection settings
            if let data = userDefaults.data(forKey: "esp32_connection_settings"),
               let settings = try? JSONDecoder().decode(ESP32ConnectionSettings.self, from: data) {
                esp32Settings = settings
            }
            
            // Load awake status
            if let data = userDefaults.data(forKey: "awake_status"),
               let status = try? JSONDecoder().decode(AwakeStatus.self, from: data) {
                awakeStatus = status
            }
            
        } catch {
            errorMessage = "Eroare la încărcarea setărilor: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Salvează toate setările
    func saveSettings() async {
        do {
            
            
            // Save notification settings
            let notificationData = try JSONEncoder().encode(notificationSettings)
            userDefaults.set(notificationData, forKey: "notification_settings")
            
            // Save ESP32 connection settings
            let esp32Data = try JSONEncoder().encode(esp32Settings)
            userDefaults.set(esp32Data, forKey: "esp32_connection_settings")
            
            // Save awake status
            let awakeData = try JSONEncoder().encode(awakeStatus)
            userDefaults.set(awakeData, forKey: "awake_status")
            
            // Update last modified
            notificationSettings.lastUpdated = Date()
            esp32Settings.lastUpdated = Date()
            
            // Notify other parts of the app
            NotificationCenter.default.post(name: .userPreferencesChanged, object: nil)
            
        } catch {
            errorMessage = "Eroare la salvarea setărilor: \(error.localizedDescription)"
        }
    }
    
    /// Reîmprospătează setările
    func refreshSettings() async {
        await loadSettings()
    }
    
    // MARK: - Specific Setting Updates
    
    
    
    /// Actualizează setările de notificări
    func updateNotificationSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        
        Task {
            await saveSettings()
            await requestNotificationPermissions()
        }
    }
    
    /// Actualizează setările ESP32
    func updateESP32Settings(_ settings: ESP32ConnectionSettings) {
        esp32Settings = settings
        
        Task {
            await saveSettings()
        }
    }
    
    /// Actualizează statusul de treaz/dormit
    func updateAwakeStatus(_ status: AwakeStatus) {
        awakeStatus = status
        
        Task {
            await saveSettings()
        }
        
        // Notifică HealthKitManager despre schimbarea manuală
        NotificationCenter.default.post(
            name: .manualAwakeStatusChanged,
            object: AwakeStatusChange(
                oldStatus: awakeStatus,
                newStatus: status,
                confidence: 100.0,
                timestamp: Date(),
                detectionMethod: .manual,
                source: .manual
            )
        )
    }
    
    // MARK: - Reset Functions
    
    /// Resetează toate setările la valorile implicite
    func resetToDefaults() {
        notificationSettings = NotificationSettings()
        esp32Settings = ESP32ConnectionSettings()
        
        Task {
            await saveSettings()
        }
    }
    
    
    
    /// Resetează doar setările ESP32
    func resetESP32Settings() {
        esp32Settings = ESP32ConnectionSettings()
        
        Task {
            await saveSettings()
        }
    }
    
    // MARK: - Validation
    
    /// Validează setările înainte de salvare
    func validateSettings() -> [String] {
        var errors: [String] = []
        
        
        
        // Validate ESP32 settings
        errors.append(contentsOf: esp32Settings.validate())
        
        return errors
    }
    
    /// Validează doar setările ESP32 și actualizează erorile de validare
    func validateESP32Settings() {
        validationErrors = esp32Settings.validate()
    }
    
    // MARK: - ESP32 Connection Testing
    
    /// Testează conexiunea la ESP32 cu setările actuale
    func testESP32Connection() async {
        connectionTestInProgress = true
        connectionTestResult = nil
        
        let startTime = Date()
        
        do {
            // Folosește același endpoint ca în Home (/relay)
            let testURL = esp32Settings.fullURL + "/relay"
            let url = URL(string: testURL)!
            var request = URLRequest(url: url)
            request.timeoutInterval = esp32Settings.connectionTimeout
            request.httpMethod = "GET"
            request.setValue("SmartCoffeeApp/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Verifică dacă răspunsul este valid (orice răspuns de la /relay)
                    if let responseString = String(data: data, encoding: .utf8),
                       !responseString.isEmpty {
                        
                        // Salvează ultimele informații de conexiune reușită
                        esp32Settings.lastSuccessfulConnection = Date()
                        esp32Settings.lastKnownIP = extractIPFromURL(esp32Settings.baseURL)
                        
                        connectionTestResult = ConnectionTestResult(
                            success: true,
                            responseTime: responseTime,
                            statusCode: httpResponse.statusCode,
                            message: "ESP32 Smart Coffee detectat și funcțional",
                            deviceInfo: ["response": responseString]
                        )
                        
                        await saveSettings()
                    } else {
                        connectionTestResult = ConnectionTestResult(
                            success: false,
                            responseTime: responseTime,
                            statusCode: httpResponse.statusCode,
                            message: "ESP32 a răspuns, dar cu răspuns gol",
                            deviceInfo: nil
                        )
                    }
                } else {
                    connectionTestResult = ConnectionTestResult(
                        success: false,
                        responseTime: responseTime,
                        statusCode: httpResponse.statusCode,
                        message: "ESP32 a răspuns cu cod de eroare: \(httpResponse.statusCode)",
                        deviceInfo: nil
                    )
                }
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            connectionTestResult = ConnectionTestResult(
                success: false,
                responseTime: responseTime,
                statusCode: nil,
                message: "Eroare de conexiune: \(error.localizedDescription)",
                deviceInfo: nil
            )
        }
        
        connectionTestInProgress = false
    }
    
    /// Scanează rețeaua locală pentru ESP32
    func scanForESP32() async {
        connectionTestInProgress = true
        
        // TODO: Implementare scan subnet local
        // Pentru moment, returnăm câteva IP-uri comune
        let commonIPs = [
            "192.168.81.60",  // IP-ul principal folosit de ESP32CommunicationManager
            "192.168.1.100",
            "192.168.1.101",
            "192.168.1.102",
            "192.168.0.100",
            "192.168.0.101",
            "192.168.4.1"  // IP default ESP32 AP mode
        ]
        
        for ip in commonIPs {
            let testSettings = ESP32ConnectionSettings()
            let originalURL = esp32Settings.baseURL
            esp32Settings.baseURL = "http://\(ip)"
            
            await testESP32Connection()
            
            if connectionTestResult?.success == true {
                // Am găsit ESP32
                break
            } else {
                // Restaurează URL-ul original pentru următoarea încercare
                esp32Settings.baseURL = originalURL
            }
        }
        
        connectionTestInProgress = false
    }
    
    private func extractIPFromURL(_ url: String) -> String? {
        let cleanURL = url.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        let components = cleanURL.split(separator: ":")
        return components.first.map(String.init)
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermissions() async {
        guard notificationSettings.pushNotificationsEnabled else { return }
        
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("Notification permissions granted")
            } else {
                print("Notification permissions denied")
                // Update settings to reflect denial
                notificationSettings.pushNotificationsEnabled = false
            }
        } catch {
            print("Error requesting notification permissions: \(error)")
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        
        
        // Observer pentru schimbări în setările de notificări
        $notificationSettings
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveSettings()
                }
            }
            .store(in: &cancellables)
        
        // Observer pentru schimbări în setările ESP32
        $esp32Settings
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveSettings()
                    self?.validateESP32Settings()
                }
            }
            .store(in: &cancellables)
        
        // Observer pentru schimbări în statusul de treaz/dormit
        $awakeStatus
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveSettings()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - HealthKit Integration
    
    /// Configurează integrarea cu HealthKit pentru detectarea automată a statusului
    private func setupHealthKitIntegration() {
        // Observer pentru schimbările de status detectate automat de HealthKit
        NotificationCenter.default.publisher(for: .awakeStatusChanged)
            .sink { [weak self] notification in
                if let statusChange = notification.object as? AwakeStatusChange {
                    self?.handleAutomaticStatusChange(statusChange)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Configurează sincronizarea cu HealthKitManager
    func setupHealthKitManagerSync(_ healthKitManager: HealthKitManager) {
        // Observer pentru schimbările din HealthKitManager
        healthKitManager.$currentAwakeStatus
            .dropFirst() // Ignoră valoarea inițială
            .sink { [weak self] newStatus in
                // Actualizează statusul local doar dacă e diferit
                if self?.awakeStatus != newStatus {
                    self?.awakeStatus = newStatus
                    print("🔄 SettingsViewModel synced with HealthKitManager: \(newStatus.displayName)")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Gestionează schimbarea automată a statusului detectată de HealthKit
    private func handleAutomaticStatusChange(_ statusChange: AwakeStatusChange) {
        // Actualizează statusul local
        awakeStatus = statusChange.newStatus
        
        print("🔄 HealthKit detected status change: \(statusChange.description)")
        
        // Salvează automat noul status
        Task {
            await saveSettings()
        }
        
        // Notifică utilizatorul despre schimbarea automată (opțional)
        if statusChange.confidence > 80.0 {
            // Poți adăuga aici o notificare push sau un alert
            print("📱 High confidence status change detected: \(statusChange.newStatus.displayName)")
        }
    }
    
    /// Sincronizează statusul cu HealthKitManager
    func syncWithHealthKitManager(_ healthKitManager: HealthKitManager) {
        // Încarcă statusul din HealthKitManager
        awakeStatus = healthKitManager.currentAwakeStatus
        
        print("🔄 Synced awake status with HealthKitManager: \(awakeStatus.displayName)")
    }
    
}

// MARK: - Supporting Models


/// Setări pentru notificări
struct NotificationSettings: Codable {
    var pushNotificationsEnabled: Bool
    var coffeeConfirmationEnabled: Bool
    var connectivityAlertsEnabled: Bool
    var dailySummaryEnabled: Bool
    var caffeineAlertsEnabled: Bool
    var lastUpdated: Date
    
    init() {
        self.pushNotificationsEnabled = true
        self.coffeeConfirmationEnabled = true
        self.connectivityAlertsEnabled = true
        self.dailySummaryEnabled = false
        self.caffeineAlertsEnabled = true
        self.lastUpdated = Date()
    }
}

/// Setări pentru sistemul de export
struct ExportSettings: Codable {
    var includeHealthData: Bool
    var includeCoffeeHistory: Bool
    var includeSystemLogs: Bool
    var exportFormat: ExportFormat
    var lastExport: Date?
    
    init() {
        self.includeHealthData = true
        self.includeCoffeeHistory = true
        self.includeSystemLogs = false
        self.exportFormat = .json
        self.lastExport = nil
    }
}

enum ExportFormat: String, CaseIterable, Codable {
    case json = "json"
    case csv = "csv"
    case pdf = "pdf"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .pdf: return "PDF"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - Settings Utilities

/// Utilități pentru managementul setărilor
class SettingsManager {
    static let shared = SettingsManager()
    
    private init() {}
    
    /// Exportă toate setările într-un dicționar
    func exportAllSettings() -> [String: Any] {
        let userDefaults = UserDefaults.standard
        
        var settings: [String: Any] = [:]
        
        
        
        // Export notification settings
        if let data = userDefaults.data(forKey: "notification_settings"),
           let notificationSettings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            settings["notification_settings"] = try? JSONEncoder().encode(notificationSettings).base64EncodedString()
        }
        
        settings["export_date"] = ISO8601DateFormatter().string(from: Date())
        settings["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        return settings
    }
    
    /// Importă setările dintr-un dicționar
    func importSettings(from dictionary: [String: Any]) throws {
        let userDefaults = UserDefaults.standard
        
        
        
        // Import notification settings
        if let encodedString = dictionary["notification_settings"] as? String,
           let data = Data(base64Encoded: encodedString) {
            userDefaults.set(data, forKey: "notification_settings")
        }
        
        // Notify about settings change
        NotificationCenter.default.post(name: .userPreferencesChanged, object: nil)
    }
    
    /// Validează integritatea setărilor
    func validateSettingsIntegrity() -> Bool {
        let userDefaults = UserDefaults.standard
        
        
        
        // Check if notification settings are valid
        if let data = userDefaults.data(forKey: "notification_settings") {
            guard (try? JSONDecoder().decode(NotificationSettings.self, from: data)) != nil else {
                return false
            }
        }
        
        return true
    }
    
    /// Repară setările corupte resetându-le la valorile implicite
    func repairCorruptedSettings() {
        let userDefaults = UserDefaults.standard
        
        
        
        // Reset notification settings if corrupted
        if let data = userDefaults.data(forKey: "notification_settings"),
           (try? JSONDecoder().decode(NotificationSettings.self, from: data)) == nil {
            let defaultSettings = NotificationSettings()
            if let encodedData = try? JSONEncoder().encode(defaultSettings) {
                userDefaults.set(encodedData, forKey: "notification_settings")
            }
        }
    }
}

// MARK: - Settings Migration

/// Sistem de migrare pentru actualizările setărilor între versiuni
class SettingsMigration {
    static let currentVersion = 1
    
    static func migrateIfNeeded() {
        let userDefaults = UserDefaults.standard
        let currentMigrationVersion = userDefaults.integer(forKey: "settings_migration_version")
        
        if currentMigrationVersion < currentVersion {
            print("Migrating settings from version \(currentMigrationVersion) to \(currentVersion)")
            
            // Perform migrations
            for version in (currentMigrationVersion + 1)...currentVersion {
                performMigration(to: version)
            }
            
            userDefaults.set(currentVersion, forKey: "settings_migration_version")
        }
    }
    
    private static func performMigration(to version: Int) {
        switch version {
        case 1:
            // Migration to version 1 - add new fields, rename existing ones, etc.
            migrateToVersion1()
        default:
            break
        }
    }
    
    private static func migrateToVersion1() {
        // Example migration - add default notification settings if missing
        let userDefaults = UserDefaults.standard
        
        if userDefaults.data(forKey: "notification_settings") == nil {
            let defaultSettings = NotificationSettings()
            if let data = try? JSONEncoder().encode(defaultSettings) {
                userDefaults.set(data, forKey: "notification_settings")
            }
        }
    }
}

// MARK: - Connection Test Result

/// Rezultatul testului de conexiune ESP32
struct ConnectionTestResult {
    let success: Bool
    let responseTime: TimeInterval
    let statusCode: Int?
    let message: String
    let deviceInfo: [String: Any]?
    let timestamp: Date
    
    init(success: Bool, responseTime: TimeInterval, statusCode: Int?, message: String, deviceInfo: [String: Any]?) {
        self.success = success
        self.responseTime = responseTime
        self.statusCode = statusCode
        self.message = message
        self.deviceInfo = deviceInfo
        self.timestamp = Date()
    }
    
    var responseTimeDescription: String {
        return String(format: "%.3f s", responseTime)
    }
    
    var statusDescription: String {
        if success {
            return "✅ Conectat"
        } else {
            return "❌ Deconectat"
        }
    }
}

