import Foundation
import Combine
import UserNotifications

/// ViewModel pentru SettingsView - gestionează toate setările aplicației
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var coffeePreferences = UserCoffeePreferences()
    @Published var autoSettings = AutoModeSettings()
    @Published var notificationSettings = NotificationSettings()
    @Published var esp32Settings = ESP32ConnectionSettings()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var validationErrors: [String] = []
    @Published var connectionTestInProgress = false
    @Published var connectionTestResult: ConnectionTestResult?
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    // MARK: - Data Loading & Saving
    
    /// Încarcă toate setările din storage
    func loadSettings() async {
        isLoading = true
        
        do {
            // Load coffee preferences
            if let data = userDefaults.data(forKey: "coffee_preferences"),
               let preferences = try? JSONDecoder().decode(UserCoffeePreferences.self, from: data) {
                coffeePreferences = preferences
            }
            
            // Load auto mode settings
            if let data = userDefaults.data(forKey: "auto_mode_settings"),
               let settings = try? JSONDecoder().decode(AutoModeSettings.self, from: data) {
                autoSettings = settings
            }
            
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
            
        } catch {
            errorMessage = "Eroare la încărcarea setărilor: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Salvează toate setările
    func saveSettings() async {
        do {
            // Save coffee preferences
            let coffeeData = try JSONEncoder().encode(coffeePreferences)
            userDefaults.set(coffeeData, forKey: "coffee_preferences")
            
            // Save auto mode settings
            let autoData = try JSONEncoder().encode(autoSettings)
            userDefaults.set(autoData, forKey: "auto_mode_settings")
            
            // Save notification settings
            let notificationData = try JSONEncoder().encode(notificationSettings)
            userDefaults.set(notificationData, forKey: "notification_settings")
            
            // Save ESP32 connection settings
            let esp32Data = try JSONEncoder().encode(esp32Settings)
            userDefaults.set(esp32Data, forKey: "esp32_connection_settings")
            
            // Update last modified
            coffeePreferences.lastUpdated = Date()
            autoSettings.lastUpdated = Date()
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
    
    /// Actualizează preferințele de cafea
    func updateCoffeePreferences(_ preferences: UserCoffeePreferences) {
        coffeePreferences = preferences
        
        Task {
            await saveSettings()
        }
    }
    
    /// Actualizează setările modului automat
    func updateAutoModeSettings(_ settings: AutoModeSettings) {
        autoSettings = settings
        
        Task {
            await saveSettings()
        }
    }
    
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
    
    // MARK: - Reset Functions
    
    /// Resetează toate setările la valorile implicite
    func resetToDefaults() {
        coffeePreferences = UserCoffeePreferences()
        autoSettings = AutoModeSettings()
        notificationSettings = NotificationSettings()
        esp32Settings = ESP32ConnectionSettings()
        
        Task {
            await saveSettings()
        }
    }
    
    /// Resetează doar preferințele de cafea
    func resetCoffeePreferences() {
        coffeePreferences = UserCoffeePreferences()
        
        Task {
            await saveSettings()
        }
    }
    
    /// Resetează doar setările modului automat
    func resetAutoModeSettings() {
        autoSettings = AutoModeSettings()
        
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
        
        // Validate coffee preferences
        if coffeePreferences.maxCaffeinePerDay < 100 || coffeePreferences.maxCaffeinePerDay > 600 {
            errors.append("Limita de cafeină trebuie să fie între 100-600mg")
        }
        
        if coffeePreferences.preferredStrength < 0.1 || coffeePreferences.preferredStrength > 1.0 {
            errors.append("Intensitatea preferată trebuie să fie între 10-100%")
        }
        
        // Validate auto mode settings
        if autoSettings.countdownDuration < 10 || autoSettings.countdownDuration > 60 {
            errors.append("Durata countdown trebuie să fie între 10-60 secunde")
        }
        
        if autoSettings.wakeDetectionSensitivity < 0.3 || autoSettings.wakeDetectionSensitivity > 1.0 {
            errors.append("Sensibilitatea detectării trebuie să fie între 30-100%")
        }
        
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
            let url = URL(string: esp32Settings.endpoint(for: "test"))!
            var request = URLRequest(url: url)
            request.timeoutInterval = esp32Settings.connectionTimeout
            request.httpMethod = "GET"
            request.setValue("SmartCoffeeApp/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Încearcă să parseze răspunsul JSON
                    if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let status = jsonData["status"] as? String,
                       status == "connected" {
                        
                        // Salvează ultimele informații de conexiune reușită
                        esp32Settings.lastSuccessfulConnection = Date()
                        esp32Settings.lastKnownIP = extractIPFromURL(esp32Settings.baseURL)
                        
                        connectionTestResult = ConnectionTestResult(
                            success: true,
                            responseTime: responseTime,
                            statusCode: httpResponse.statusCode,
                            message: "Conexiunea a fost stabilită cu succes",
                            deviceInfo: jsonData
                        )
                        
                        await saveSettings()
                    } else {
                        connectionTestResult = ConnectionTestResult(
                            success: false,
                            responseTime: responseTime,
                            statusCode: httpResponse.statusCode,
                            message: "ESP32 a răspuns, dar cu format neașteptat",
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
        // Observer pentru schimbări în preferințele de cafea
        $coffeePreferences
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveSettings()
                }
            }
            .store(in: &cancellables)
        
        // Observer pentru schimbări în setările auto
        $autoSettings
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveSettings()
                }
            }
            .store(in: &cancellables)
        
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
    }
}

// MARK: - Supporting Models

/// Setări pentru modul automat
struct AutoModeSettings: Codable {
    var autoModeEnabled: Bool
    var requireConfirmation: Bool
    var autoOnlyOnWeekdays: Bool
    var countdownDuration: TimeInterval
    var wakeDetectionSensitivity: Double
    var preferredWakeTime: Date
    var lastUpdated: Date
    
    init() {
        self.autoModeEnabled = true
        self.requireConfirmation = true
        self.autoOnlyOnWeekdays = false
        self.countdownDuration = 30.0
        self.wakeDetectionSensitivity = 0.75
        self.preferredWakeTime = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
        self.lastUpdated = Date()
    }
}

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
        
        // Export coffee preferences
        if let data = userDefaults.data(forKey: "coffee_preferences"),
           let preferences = try? JSONDecoder().decode(UserCoffeePreferences.self, from: data) {
            settings["coffee_preferences"] = try? JSONEncoder().encode(preferences).base64EncodedString()
        }
        
        // Export auto mode settings
        if let data = userDefaults.data(forKey: "auto_mode_settings"),
           let autoSettings = try? JSONDecoder().decode(AutoModeSettings.self, from: data) {
            settings["auto_mode_settings"] = try? JSONEncoder().encode(autoSettings).base64EncodedString()
        }
        
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
        
        // Import coffee preferences
        if let encodedString = dictionary["coffee_preferences"] as? String,
           let data = Data(base64Encoded: encodedString) {
            userDefaults.set(data, forKey: "coffee_preferences")
        }
        
        // Import auto mode settings
        if let encodedString = dictionary["auto_mode_settings"] as? String,
           let data = Data(base64Encoded: encodedString) {
            userDefaults.set(data, forKey: "auto_mode_settings")
        }
        
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
        
        // Check if coffee preferences are valid
        if let data = userDefaults.data(forKey: "coffee_preferences") {
            guard (try? JSONDecoder().decode(UserCoffeePreferences.self, from: data)) != nil else {
                return false
            }
        }
        
        // Check if auto settings are valid
        if let data = userDefaults.data(forKey: "auto_mode_settings") {
            guard (try? JSONDecoder().decode(AutoModeSettings.self, from: data)) != nil else {
                return false
            }
        }
        
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
        
        // Reset coffee preferences if corrupted
        if let data = userDefaults.data(forKey: "coffee_preferences"),
           (try? JSONDecoder().decode(UserCoffeePreferences.self, from: data)) == nil {
            let defaultPreferences = UserCoffeePreferences()
            if let encodedData = try? JSONEncoder().encode(defaultPreferences) {
                userDefaults.set(encodedData, forKey: "coffee_preferences")
            }
        }
        
        // Reset auto settings if corrupted
        if let data = userDefaults.data(forKey: "auto_mode_settings"),
           (try? JSONDecoder().decode(AutoModeSettings.self, from: data)) == nil {
            let defaultSettings = AutoModeSettings()
            if let encodedData = try? JSONEncoder().encode(defaultSettings) {
                userDefaults.set(encodedData, forKey: "auto_mode_settings")
            }
        }
        
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

