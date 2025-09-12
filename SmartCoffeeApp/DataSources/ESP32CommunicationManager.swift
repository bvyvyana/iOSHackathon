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
    
    private var baseURL: String = "http://192.168.81.60"
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Connection management
    
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
    
    /// Testează manual conexiunea cu ESP32
    func testManualConnection() async {
        print("🔄 Manual connection test started...")
        
        do {
            if let ip = try await discoverESP32() {
                print("🎉 Manual test successful: ESP32 found at \(ip)")
            } else {
                print("😞 Manual test failed: ESP32 not found")
            }
        } catch {
            print("💥 Manual test error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Coffee Commands
    
    /// Trimite comandă de cafea către ESP32
    func makeCoffee(type: CoffeeType, trigger: TriggerType, sleepData: SleepData? = nil) async throws -> CoffeeResponse {
        let startTime = Date()
        
        let command = CoffeeCommand(type: type)
        
        do {
            let response: CoffeeResponse = try await performRequest<CoffeeCommand, CoffeeResponse>(
                method: "POST",
                endpoint: "/coffee",
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
    
    
    /// Actualizează setările ESP32
    func updateSettings(_ settings: ESP32Settings) async throws {
        let _: SettingsUpdateResponse = try await performRequest<ESP32Settings, SettingsUpdateResponse>(
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
