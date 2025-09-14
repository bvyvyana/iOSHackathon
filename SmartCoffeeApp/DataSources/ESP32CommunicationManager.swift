import Foundation
import Network
import Combine

/// Manager pentru comunicarea cu ESP32 controller
@MainActor
class ESP32CommunicationManager: ObservableObject {
    
    @Published var isConnected: Bool = false
    @Published var lastResponseTime: TimeInterval = 0
    @Published var discoveryInProgress: Bool = false
    @Published var connectionError: String?
    
    private var baseURL: String = "http://192.168.81.60"
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Connection management
    
    // Performance tracking
    private var commandTimes: [TimeInterval] = []
    private let maxCommandHistory = 50
    @Published var performanceMetrics: ESP32PerformanceMetrics = ESP32PerformanceMetrics()
    private var totalCommands: Int = 0
    private var failedCommands: Int = 0
    private var connectionStartTime: Date?
    private let persistenceController = PersistenceController.shared
    
    init() {
        // Configurează session cu timeouts optimizate
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        config.waitsForConnectivity = false
        
        self.session = URLSession(configuration: config)
        
        startNetworkMonitoring()
        setupNotificationObservers()
        
        // Load saved performance data
        Task {
            await loadPerformanceDataFromCoreData()
        }
    }
    
    deinit {
        stopNetworkMonitoring()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Observer pentru comenzile automate de cafea
        NotificationCenter.default.publisher(for: .executeAutoCoffee)
            .sink { [weak self] notification in
                if let command = notification.object as? AutoCoffeeCommand {
                    Task { @MainActor in
                        await self?.handleAutoCoffeeCommand(command)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Gestionează comanda automată de cafea primită prin notificare
    private func handleAutoCoffeeCommand(_ command: AutoCoffeeCommand) async {
        print("🤖 Processing auto-coffee command: \(command.type.displayName)")
        
        // Verifică dacă ESP32 este conectat
        guard isConnected else {
            print("❌ ESP32 not connected, cannot execute auto-coffee")
            return
        }
        
        do {
            // Trimite comanda către ESP32
            let response = try await makeCoffee(
                type: command.type,
                trigger: command.trigger,
                sleepData: command.sleepData
            )
            
            if response.isSuccess {
                print("✅ Auto-coffee executed successfully: \(command.type.displayName)")
                
                // Notifică aplicația despre succes
                NotificationCenter.default.post(
                    name: .autoCoffeeCompleted,
                    object: AutoCoffeeResult(
                        success: true,
                        type: command.type,
                        response: response,
                        timestamp: Date()
                    )
                )
            } else {
                print("❌ Auto-coffee failed: \(response.message)")
                
                // Notifică aplicația despre eșec
                NotificationCenter.default.post(
                    name: .autoCoffeeCompleted,
                    object: AutoCoffeeResult(
                        success: false,
                        type: command.type,
                        response: response,
                        timestamp: Date()
                    )
                )
            }
            
        } catch {
            print("💥 Auto-coffee error: \(error.localizedDescription)")
            
            // Notifică aplicația despre eroare
            NotificationCenter.default.post(
                name: .autoCoffeeCompleted,
                object: AutoCoffeeResult(
                    success: false,
                    type: command.type,
                    response: nil,
                    timestamp: Date(),
                    error: error
                )
            )
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.connectionError = nil
                } else {
                    self?.isConnected = false
                    self?.connectionError = "Fără conexiune la internet"
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    nonisolated private func stopNetworkMonitoring() {
        monitor.cancel()
    }
    
    // MARK: - ESP32 Discovery
    
    /// Descoperă ESP32 în rețeaua locală
    func discoverESP32() async throws -> String? {
        guard !discoveryInProgress else {
            return nil
        }
        
        discoveryInProgress = true
        connectionError = nil
        
        defer {
            discoveryInProgress = false
        }
        
        // Folosește IP-ul fix configurat
        let fixedIP = "192.168.81.60"
        
        do {
            print("🔍 Trying to connect to ESP32 at \(fixedIP):80...")
            
            // Testează conexiunea la IP-ul fix
            if let discoveredIP = try await testESP32Connection(ip: fixedIP, port: 80, timeout: 5.0) {
                print("✅ ESP32 found at \(discoveredIP)")
                baseURL = "http://\(fixedIP)"
                await updateConnectionStatus(true)
                return fixedIP
            }
            
            print("❌ ESP32 not responding at \(fixedIP)/relay")
            connectionError = "ESP32 nu răspunde la \(fixedIP)/relay"
            return nil
            
        } catch {
            print("💥 Connection error: \(error.localizedDescription)")
            connectionError = "Eroare la conectare: \(error.localizedDescription)"
            throw error
        }
    }
    
    
    
    
    private func testESP32Connection(ip: String, port: Int, timeout: TimeInterval) async throws -> String? {
        // Folosește endpoint-ul principal de ping
        let testEndpoints = ["/relay"]
        
        for endpoint in testEndpoints {
            let testURL = "http://\(ip)\(endpoint)"
            print("🔗 Testing ESP32 ping endpoint: \(testURL)")
            
            do {
                let request = createRequest(url: testURL, method: "GET", timeout: timeout)
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response for \(testURL)")
                    continue
                }
                
                print("📡 Response status: \(httpResponse.statusCode) for \(testURL)")
                
                if httpResponse.statusCode == 200 {
                    // Încearcă să parseze răspunsul
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 Response body: \(responseString)")
                        
                        // Verifică dacă este un ESP32 (orice răspuns valid)
                        if !responseString.isEmpty {
                            print("✅ ESP32 Smart Coffee detected at \(ip)\(endpoint)")
                            return ip
                        }
                    }
                }
            } catch {
                print("❌ Error testing \(testURL): \(error.localizedDescription)")
                continue
            }
        }
        
        print("❌ No valid ESP32 response from \(ip)/relay")
        return nil
    }
    
    
    
    // MARK: - Coffee Commands
    
    /// Trimite comandă de cafea către ESP32
    func makeCoffee(type: CoffeeType, trigger: TriggerType, sleepData: SleepData? = nil) async throws -> CoffeeResponse {
        let startTime = Date()
        
        let command = CoffeeCommand(type: type)
        
        do {
            print("☕ Sending coffee command: \(command.coffee)")
            
            let response: CoffeeResponse = try await performRequest<CoffeeCommand, CoffeeResponse>(
                method: "POST",
                endpoint: "/coffee",
                body: command
            )
            
            // Track response time
            let responseTime = Date().timeIntervalSince(startTime)
            await updateResponseTime(responseTime)
            
            // Save coffee order to Core Data
            await saveCoffeeOrderToCoreData(
                command: command,
                response: response,
                responseTime: responseTime,
                trigger: trigger
            )
            
            // Log pentru analytics
            await logCoffeeCommand(command: command, response: response, responseTime: responseTime)
            
            print("✅ Coffee command successful: \(response.message)")
            return response
            
        } catch {
            print("❌ Coffee command failed: \(error)")
            await recordFailedCommand()
            
            // Save failed coffee order to Core Data
            await saveCoffeeOrderToCoreData(
                command: command,
                response: nil,
                responseTime: Date().timeIntervalSince(startTime),
                trigger: trigger,
                success: false
            )
            
            await logCoffeeError(command: command, error: error)
            throw error
        }
    }
    
    
    
    
    // MARK: - Generic Request Handler
    
    private func performRequest<T: Codable, U: Codable>(
        method: String,
        endpoint: String,
        body: T? = nil
    ) async throws -> U {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw ESP32Error.invalidURL
        }
        
        let request = createRequest(url: url.absoluteString, method: method, body: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ESP32Error.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw ESP32Error.httpError(httpResponse.statusCode)
            }
            
            // Debug: afișează răspunsul brut de la ESP32
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 ESP32 Raw Response: \(responseString)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                return try decoder.decode(U.self, from: data)
            } catch {
                print("❌ JSON Decoding Error: \(error)")
                print("📄 Raw data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                throw error
            }
            
        } catch let error as ESP32Error {
            throw error
        } catch {
            throw ESP32Error.networkError(error)
        }
    }
    
    private func createRequest(
        url: String,
        method: String,
        timeout: TimeInterval = 10.0
    ) -> URLRequest {
        guard let url = URL(string: url) else {
            fatalError("Invalid URL: \(url)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("SmartCoffeeApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    private func createRequest<T: Codable>(
        url: String,
        method: String,
        body: T,
        timeout: TimeInterval = 10.0
    ) -> URLRequest {
        
        guard let url = URL(string: url) else {
            fatalError("Invalid URL: \(url)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("SmartCoffeeApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        } catch {
            print("Encoding error: \(error)")
        }
        
        return request
    }
    
    // MARK: - Connection Management
    
    private func updateConnectionStatus(_ connected: Bool) async {
        isConnected = connected
        
        if connected {
            connectionError = nil
            connectionStartTime = Date()
        } else {
            connectionStartTime = nil
        }
        
        await updatePerformanceMetrics()
    }
    
    
    
    
    // MARK: - Performance Tracking
    
    private func updateResponseTime(_ time: TimeInterval) async {
        lastResponseTime = time
        totalCommands += 1
        
        commandTimes.append(time)
        if commandTimes.count > maxCommandHistory {
            commandTimes.removeFirst()
        }
        
        await updatePerformanceMetrics()
    }
    
    private func recordFailedCommand() async {
        failedCommands += 1
        totalCommands += 1
        await updatePerformanceMetrics()
    }
    
    private func updatePerformanceMetrics() async {
        let averageResponseTime = commandTimes.isEmpty ? 0 : commandTimes.reduce(0, +) / Double(commandTimes.count)
        let successRate = totalCommands > 0 ? Double(totalCommands - failedCommands) / Double(totalCommands) * 100 : 0
        let uptime = connectionStartTime != nil ? Date().timeIntervalSince(connectionStartTime!) / 3600 : 0 // hours
        
        performanceMetrics = ESP32PerformanceMetrics(
            responseTime: averageResponseTime,
            successRate: successRate,
            uptime: uptime,
            totalCommands: totalCommands,
            failedCommands: failedCommands,
            isConnected: isConnected,
            lastUpdated: Date()
        )
        
        // Save performance metrics to Core Data every 10 commands or every 5 minutes
        if totalCommands % 10 == 0 || shouldSavePerformanceMetrics() {
            await savePerformanceMetricsToCoreData()
        }
        
        // Notify dashboard about performance updates
        NotificationCenter.default.post(name: .esp32PerformanceUpdated, object: performanceMetrics)
    }
    
    var averageResponseTime: TimeInterval {
        guard !commandTimes.isEmpty else { return 0 }
        return commandTimes.reduce(0, +) / Double(commandTimes.count)
    }
    
    // MARK: - Data Persistence
    
    private var lastPerformanceSave: Date = Date()
    
    private func saveCoffeeOrderToCoreData(
        command: CoffeeCommand,
        response: CoffeeResponse?,
        responseTime: TimeInterval,
        trigger: TriggerType,
        success: Bool = true
    ) async {
        let esp32ResponseCode: Int16 = response?.isSuccess == true ? 200 : 500
        
        persistenceController.saveCoffeeOrder(
            type: command.coffee,
            trigger: trigger.rawValue,
            success: success,
            responseTime: responseTime,
            esp32ResponseCode: esp32ResponseCode,
            wakeDetectionConfidence: 0.0, // TODO: Calculate from sleep data if available
            userOverride: trigger == .manual,
            countdownCancelled: false,
            estimatedBrewTime: 90.0 // Default brew time
        )
        
        print("💾 Coffee order saved to Core Data: \(command.coffee) - \(success ? "Success" : "Failed")")
    }
    
    private func savePerformanceMetricsToCoreData() async {
        // Use default WiFi strength since we don't have real data from /relay
        let wifiStrength: Int16 = isConnected ? -45 : -100
        
        persistenceController.saveESP32Performance(
            averageResponseTime: performanceMetrics.responseTime,
            successRate: performanceMetrics.successRate,
            totalCommands: Int32(performanceMetrics.totalCommands),
            failedCommands: Int32(performanceMetrics.failedCommands),
            uptime: performanceMetrics.uptime,
            isConnected: performanceMetrics.isConnected,
            wifiStrength: wifiStrength
        )
        
        lastPerformanceSave = Date()
        print("💾 ESP32 performance metrics saved to Core Data")
    }
    
    private func shouldSavePerformanceMetrics() -> Bool {
        // Save every 5 minutes
        return Date().timeIntervalSince(lastPerformanceSave) > 300
    }
    
    /// Load performance data from Core Data on startup
    private func loadPerformanceDataFromCoreData() async {
        if let latestPerformance = persistenceController.getLatestESP32Performance() {
            // Initialize counters from saved data
            totalCommands = Int(latestPerformance.totalCommands)
            failedCommands = Int(latestPerformance.failedCommands)
            
            print("📊 Loaded ESP32 performance from Core Data: \(totalCommands) total commands")
        }
    }
    
    // MARK: - Logging & Analytics
    
    private func logCoffeeCommand(command: CoffeeCommand, response: CoffeeResponse, responseTime: TimeInterval) async {
        print("COFFEE_COMMAND: \(command.coffee) - \(response.status) (\(String(format: "%.2f", responseTime))s)")
        
        // TODO: Trimite către serviciu de analytics
    }
    
    private func logCoffeeError(command: CoffeeCommand, error: Error) async {
        print("COFFEE_ERROR: \(command.coffee) - \(error.localizedDescription)")
        
        // TODO: Trimite către serviciu de error tracking
    }
    
    // MARK: - Helper Methods
    
}

// MARK: - Data Models

struct NetworkInfo {
    let subnet: String
    let gateway: String
}






// MARK: - Errors

enum ESP32Error: Error, LocalizedError {
    case notConnected
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case timeout
    case deviceNotFound
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Nu există conexiune cu ESP32"
        case .invalidURL:
            return "URL invalid pentru ESP32"
        case .invalidResponse:
            return "Răspuns invalid de la ESP32"
        case .httpError(let code):
            return "Eroare HTTP: \(code)"
        case .networkError(let error):
            return "Eroare rețea: \(error.localizedDescription)"
        case .timeout:
            return "Timeout conexiune ESP32"
        case .deviceNotFound:
            return "Dispozitivul ESP32 nu a fost găsit"
        case .authenticationFailed:
            return "Autentificare eșuată cu ESP32"
        }
    }
}

// MARK: - ESP32 Performance Metrics Model

struct ESP32PerformanceMetrics {
    let responseTime: TimeInterval
    let successRate: Double
    let uptime: TimeInterval
    let totalCommands: Int
    let failedCommands: Int
    let isConnected: Bool
    let lastUpdated: Date
    
    init(responseTime: TimeInterval = 0, successRate: Double = 0, uptime: TimeInterval = 0, 
         totalCommands: Int = 0, failedCommands: Int = 0, isConnected: Bool = false, lastUpdated: Date = Date()) {
        self.responseTime = responseTime
        self.successRate = successRate
        self.uptime = uptime
        self.totalCommands = totalCommands
        self.failedCommands = failedCommands
        self.isConnected = isConnected
        self.lastUpdated = lastUpdated
    }
    
    var formattedResponseTime: String {
        return String(format: "%.2fs", responseTime)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate)
    }
    
    var formattedUptime: String {
        let hours = Int(uptime)
        let minutes = Int((uptime - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
    
    var responseTimeStatus: PerformanceStatus {
        switch responseTime {
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
}

// MARK: - Helper Structs

struct EmptyBody: Codable {}

extension Notification.Name {
    static let esp32PerformanceUpdated = Notification.Name("esp32PerformanceUpdated")
    static let autoCoffeeCompleted = Notification.Name("autoCoffeeCompleted")
}
