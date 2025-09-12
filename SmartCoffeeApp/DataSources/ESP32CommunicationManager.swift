import Foundation
import Network
import Combine

/// Manager pentru comunicarea cu ESP32 controller
@MainActor
class ESP32CommunicationManager: ObservableObject {
    
    @Published var isConnected: Bool = false
    @Published var lastResponseTime: TimeInterval = 0
    @Published var esp32Status: ESP32Status?
    @Published var discoveryInProgress: Bool = false
    @Published var connectionError: String?
    
    private var baseURL: String = "http://192.168.1.100"
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Discovery și connection management
    private var discoveryTask: Task<Void, Never>?
    private var healthCheckTimer: Timer?
    
    // Performance tracking
    private var commandTimes: [TimeInterval] = []
    private let maxCommandHistory = 20
    
    init() {
        // Configurează session cu timeouts optimizate
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        config.waitsForConnectivity = false
        
        self.session = URLSession(configuration: config)
        
        startNetworkMonitoring()
    }
    
    deinit {
        stopNetworkMonitoring()
        healthCheckTimer?.invalidate()
        discoveryTask?.cancel()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.connectionError = nil
                    Task {
                        await self?.checkConnection()
                    }
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
        
        do {
            // Încearcă mDNS discovery primul
            if let mdnsIP = try await discoverViaMDNS() {
                baseURL = "http://\(mdnsIP)"
                await updateConnectionStatus(true)
                return mdnsIP
            }
            
            // Fallback la scanarea subnet-ului
            if let scanIP = try await scanLocalSubnet() {
                baseURL = "http://\(scanIP)"
                await updateConnectionStatus(true)
                return scanIP
            }
            
            connectionError = "ESP32 nu a fost găsit în rețea"
            return nil
            
        } catch {
            connectionError = "Eroare discovery: \(error.localizedDescription)"
            throw error
        }
    }
    
    private func discoverViaMDNS() async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_http._tcp", domain: nil), using: .tcp)
            
            var resolved = false
            
            browser.browseResultsChangedHandler = { results, changes in
                for result in results {
                    if case .service(let name, _, _, _) = result.endpoint,
                       name.contains("smart-coffee") {
                        
                        if !resolved {
                            resolved = true
                            // Simulare - în realitate ai folosi NWConnection pentru rezolvare
                            continuation.resume(returning: "192.168.1.100")
                        }
                        return
                    }
                }
            }
            
            browser.start(queue: DispatchQueue.global())
            
            // Timeout după 5 secunde
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if !resolved {
                    resolved = true
                    browser.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func scanLocalSubnet() async throws -> String? {
        guard let networkInfo = try await getCurrentNetworkInfo() else {
            return nil
        }
        
        let subnet = networkInfo.subnet
        let commonPorts = [80, 8080, 3000, 8000]
        
        return try await withThrowingTaskGroup(of: String?.self) { group in
            // Scanează primele 50 de IP-uri din subnet
            for i in 1...50 {
                for port in commonPorts {
                    group.addTask {
                        let ip = "\(subnet).\(i)"
                        return try await self.testESP32Connection(ip: ip, port: port, timeout: 2.0)
                    }
                }
            }
            
            // Returnează primul ESP32 găsit
            for try await result in group {
                if let validIP = result {
                    return validIP
                }
            }
            return nil
        }
    }
    
    private func getCurrentNetworkInfo() async throws -> NetworkInfo? {
        return try await withCheckedThrowingContinuation { continuation in
            // Simulare - în realitate ai folosi APIs specifice pentru network info
            let networkInfo = NetworkInfo(subnet: "192.168.1", gateway: "192.168.1.1")
            continuation.resume(returning: networkInfo)
        }
    }
    
    private func testESP32Connection(ip: String, port: Int, timeout: TimeInterval) async throws -> String? {
        let testURL = "http://\(ip):\(port)/test"
        
        do {
            let request = createRequest(url: testURL, method: "GET", timeout: timeout)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            // Verifică dacă răspunsul conține semnătura ESP32
            if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let deviceId = responseData["device_id"] as? String,
               deviceId.contains("ESP32") || deviceId.contains("smart-coffee") {
                return ip
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - Coffee Commands
    
    /// Trimite comandă de cafea către ESP32
    func makeCoffee(type: CoffeeType, trigger: TriggerType, sleepData: SleepData? = nil) async throws -> CoffeeResponse {
        let startTime = Date()
        
        let command = CoffeeCommand(
            type: type,
            trigger: trigger,
            sleepScore: sleepData?.computedQuality,
            userId: await getUserId()
        )
        
        do {
            let response: CoffeeResponse = try await performRequest(
                method: "POST",
                endpoint: "/coffee/make",
                body: command
            )
            
            // Track response time
            let responseTime = Date().timeIntervalSince(startTime)
            await updateResponseTime(responseTime)
            
            // Log pentru analytics
            await logCoffeeCommand(command: command, response: response, responseTime: responseTime)
            
            return response
            
        } catch {
            await logCoffeeError(command: command, error: error)
            throw error
        }
    }
    
    /// Obține statusul curent al ESP32
    func getStatus() async throws -> ESP32Status {
        let status: ESP32Status = try await performRequest(
            method: "GET",
            endpoint: "/status"
        )
        
        esp32Status = status
        await updateConnectionStatus(true)
        
        return status
    }
    
    /// Obține metrici de sănătate ESP32
    func getHealthMetrics() async throws -> ESP32HealthMetrics {
        return try await performRequest(
            method: "GET",
            endpoint: "/health"
        )
    }
    
    /// Testează conexiunea cu ESP32
    func testConnection() async throws -> Bool {
        do {
            let _: ConnectionTestResponse = try await performRequest(
                method: "GET",
                endpoint: "/test"
            )
            await updateConnectionStatus(true)
            return true
        } catch {
            await updateConnectionStatus(false)
            throw error
        }
    }
    
    /// Actualizează setările ESP32
    func updateSettings(_ settings: ESP32Settings) async throws {
        let _: SettingsUpdateResponse = try await performRequest(
            method: "POST",
            endpoint: "/settings",
            body: settings
        )
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
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(U.self, from: data)
            
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
            startHealthChecks()
        } else {
            stopHealthChecks()
        }
    }
    
    private func startHealthChecks() {
        stopHealthChecks() // Stop existing timer
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.performHealthCheck()
            }
        }
    }
    
    private func stopHealthChecks() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    private func performHealthCheck() async {
        do {
            _ = try await testConnection()
        } catch {
            await updateConnectionStatus(false)
            connectionError = "Conexiune pierdută cu ESP32"
        }
    }
    
    private func checkConnection() async {
        do {
            _ = try await testConnection()
        } catch {
            isConnected = false
        }
    }
    
    // MARK: - Performance Tracking
    
    private func updateResponseTime(_ time: TimeInterval) async {
        lastResponseTime = time
        
        commandTimes.append(time)
        if commandTimes.count > maxCommandHistory {
            commandTimes.removeFirst()
        }
    }
    
    var averageResponseTime: TimeInterval {
        guard !commandTimes.isEmpty else { return 0 }
        return commandTimes.reduce(0, +) / Double(commandTimes.count)
    }
    
    // MARK: - Logging & Analytics
    
    private func logCoffeeCommand(command: CoffeeCommand, response: CoffeeResponse, responseTime: TimeInterval) async {
        print("COFFEE_COMMAND: \(command.type) - \(response.status) (\(String(format: "%.2f", responseTime))s)")
        
        // TODO: Trimite către serviciu de analytics
    }
    
    private func logCoffeeError(command: CoffeeCommand, error: Error) async {
        print("COFFEE_ERROR: \(command.type) - \(error.localizedDescription)")
        
        // TODO: Trimite către serviciu de error tracking
    }
    
    // MARK: - Helper Methods
    
    private func getUserId() async -> String {
        // TODO: Implementează generarea/retrieval user ID
        return "user_\(UUID().uuidString.prefix(8))"
    }
}

// MARK: - Data Models

struct NetworkInfo {
    let subnet: String
    let gateway: String
}

struct ESP32Status: Codable {
    let online: Bool
    let lastCoffee: String?
    let triggerType: String?
    let coffeeCountToday: Int
    let autoCoffeesToday: Int
    let manualCoffeesToday: Int
    let wifiStrength: Int
    let uptimeSeconds: Int
    let autoModeEnabled: Bool
    
    var signalQuality: SignalQuality {
        switch wifiStrength {
        case -30...0: return .excellent
        case -50..<(-30): return .good
        case -70..<(-50): return .fair
        default: return .poor
        }
    }
}


struct ConnectionTestResponse: Codable {
    let status: String
    let deviceId: String
    let localIP: String
    let signalStrength: Int
    let timestamp: String
}

struct ESP32Settings: Codable {
    let autoEnabled: Bool
    let cooldownSeconds: Int
    let buttonPressDuration: Int
    
    init(autoEnabled: Bool = true, cooldownSeconds: Int = 30, buttonPressDuration: Int = 1000) {
        self.autoEnabled = autoEnabled
        self.cooldownSeconds = cooldownSeconds
        self.buttonPressDuration = buttonPressDuration
    }
}

struct SettingsUpdateResponse: Codable {
    let status: String
    let message: String?
}

enum SignalQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excelent"
        case .good: return "Bun"
        case .fair: return "Acceptabil"
        case .poor: return "Slab"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
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
