import CoreData
import Foundation

/// Controller pentru gestionarea persistenței datelor cu Core Data
class PersistenceController {
    static let shared = PersistenceController()
    
    /// Pentru preview-uri în SwiftUI
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Creează date de test pentru preview
        createPreviewData(in: viewContext)
        
        do {
            try viewContext.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }
        
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SmartCoffee")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configurare store
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        
        // Auto-merge din remote notifications
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Salvează contextul dacă există modificări
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
                let nsError = error as NSError
                fatalError("Unresolved Core Data save error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// Șterge toate datele din store (pentru reset)
    func clearAllData() {
        let context = container.viewContext
        
        // Lista entităților de șters
        let entityNames = ["SleepSession", "CoffeeOrder", "DeviceSettings", "AppMetrics", "ESP32PerformanceLog"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }
        
        save()
    }
    
    /// Background context pentru operații heavy
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Data Saving Methods
    
    /// Salvează o comandă de cafea în Core Data
    func saveCoffeeOrder(
        type: String,
        trigger: String,
        success: Bool,
        responseTime: Double,
        esp32ResponseCode: Int16 = 200,
        wakeDetectionConfidence: Double = 0.0,
        userOverride: Bool = false,
        countdownCancelled: Bool = false,
        estimatedBrewTime: Double = 0.0,
        sleepSession: SleepSession? = nil
    ) {
        let context = container.viewContext
        
        context.performAndSaveAsync {
            let coffeeOrder = CoffeeOrder(context: context)
            coffeeOrder.timestamp = Date()
            coffeeOrder.type = type
            coffeeOrder.trigger = trigger
            coffeeOrder.success = success
            coffeeOrder.responseTime = responseTime
            coffeeOrder.esp32ResponseCode = esp32ResponseCode
            coffeeOrder.wakeDetectionConfidence = wakeDetectionConfidence
            coffeeOrder.userOverride = userOverride
            coffeeOrder.countdownCancelled = countdownCancelled
            coffeeOrder.estimatedBrewTime = estimatedBrewTime
            coffeeOrder.sleepSession = sleepSession
        }
    }
    
    /// Salvează metrici de performance ESP32
    func saveESP32Performance(
        averageResponseTime: Double,
        successRate: Double,
        totalCommands: Int32,
        failedCommands: Int32,
        uptime: Double,
        isConnected: Bool,
        wifiStrength: Int16 = 0
    ) {
        let context = container.viewContext
        
        context.performAndSaveAsync {
            let performanceLog = ESP32PerformanceLog(context: context)
            performanceLog.date = Date()
            performanceLog.averageResponseTime = averageResponseTime
            performanceLog.successRate = successRate
            performanceLog.totalCommands = totalCommands
            performanceLog.failedCommands = failedCommands
            performanceLog.uptime = uptime
            performanceLog.isConnected = isConnected
            performanceLog.wifiStrength = wifiStrength
        }
    }
    
    /// Obține ultimele metrici de performance ESP32
    func getLatestESP32Performance() -> ESP32PerformanceLog? {
        let context = container.viewContext
        let request: NSFetchRequest<ESP32PerformanceLog> = ESP32PerformanceLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ESP32PerformanceLog.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Error fetching ESP32 performance: \(error)")
            return nil
        }
    }
    
    /// Obține prima conexiune ESP32 din DeviceSettings sau ESP32PerformanceLog
    func getFirstESP32Connection() -> Date? {
        let context = container.viewContext
        
        // Încearcă să găsești prima conexiune din DeviceSettings
        let deviceRequest: NSFetchRequest<DeviceSettings> = DeviceSettings.fetchRequest()
        deviceRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DeviceSettings.lastConnectionTest, ascending: true)]
        deviceRequest.fetchLimit = 1
        
        do {
            let deviceResults = try context.fetch(deviceRequest)
            if let firstDeviceConnection = deviceResults.first?.lastConnectionTest {
                print("📅 Found first ESP32 connection from DeviceSettings: \(firstDeviceConnection)")
                return firstDeviceConnection
            }
        } catch {
            print("Error fetching first ESP32 connection from DeviceSettings: \(error)")
        }
        
        // Fallback: caută prima înregistrare din ESP32PerformanceLog
        let performanceRequest: NSFetchRequest<ESP32PerformanceLog> = ESP32PerformanceLog.fetchRequest()
        performanceRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ESP32PerformanceLog.date, ascending: true)]
        performanceRequest.fetchLimit = 1
        
        do {
            let performanceResults = try context.fetch(performanceRequest)
            if let firstPerformanceLog = performanceResults.first?.date {
                print("📅 Found first ESP32 connection from PerformanceLog: \(firstPerformanceLog)")
                return firstPerformanceLog
            }
        } catch {
            print("Error fetching first ESP32 connection from PerformanceLog: \(error)")
        }
        
        print("⚠️ No ESP32 connection data found in Core Data")
        return nil
    }
    
    /// Calculează uptime-ul real ESP32 de la prima conexiune
    func calculateRealESP32Uptime() -> Double {
        guard let firstConnection = getFirstESP32Connection() else {
            print("⚠️ No first ESP32 connection found in Core Data")
            return 0.0
        }
        
        let uptimeInHours = Date().timeIntervalSince(firstConnection) / 3600.0
        let realUptime = max(0.0, uptimeInHours)
        
        print("📊 Real ESP32 uptime calculated: \(String(format: "%.2f", realUptime)) hours since \(firstConnection)")
        return realUptime
    }
    
    /// Calculează media timpului de răspuns pentru ultimele 5 comenzi ESP32
    func calculateLast5CommandsResponseTime() -> Double {
        let context = container.viewContext
        let request: NSFetchRequest<CoffeeOrder> = CoffeeOrder.fetchRequest()
        
        // Sortează după timestamp descrescător pentru a obține ultimele comenzi
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoffeeOrder.timestamp, ascending: false)]
        request.fetchLimit = 5
        
        do {
            let last5Orders = try context.fetch(request)
            
            // Filtrează doar comenzile cu succes și care au responseTime > 0
            let successfulOrders = last5Orders.filter { $0.success && $0.responseTime > 0 }
            
            guard !successfulOrders.isEmpty else {
                print("⚠️ No successful coffee orders found for response time calculation")
                return 0.0
            }
            
            let averageResponseTime = successfulOrders.reduce(0.0) { $0 + $1.responseTime } / Double(successfulOrders.count)
            
            print("📊 Last 5 commands response time: \(String(format: "%.2f", averageResponseTime))s (from \(successfulOrders.count) successful orders)")
            return averageResponseTime
            
        } catch {
            print("Error fetching last 5 coffee orders: \(error)")
            return 0.0
        }
    }
    
    /// Calculează media timpului de răspuns pentru ultimele N comenzi ESP32 (cu fallback)
    func calculateLastNCommandsResponseTime(maxCommands: Int = 5) -> Double {
        let context = container.viewContext
        let request: NSFetchRequest<CoffeeOrder> = CoffeeOrder.fetchRequest()
        
        // Sortează după timestamp descrescător pentru a obține ultimele comenzi
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoffeeOrder.timestamp, ascending: false)]
        request.fetchLimit = maxCommands * 2 // Ia mai multe pentru a avea suficiente cu succes
        
        do {
            let recentOrders = try context.fetch(request)
            
            // Filtrează doar comenzile cu succes și care au responseTime > 0
            let successfulOrders = recentOrders.filter { $0.success && $0.responseTime > 0 }
            
            // Ia doar ultimele N comenzi cu succes
            let lastNSuccessful = Array(successfulOrders.prefix(maxCommands))
            
            guard !lastNSuccessful.isEmpty else {
                print("⚠️ No successful coffee orders found for response time calculation")
                return 0.0
            }
            
            let averageResponseTime = lastNSuccessful.reduce(0.0) { $0 + $1.responseTime } / Double(lastNSuccessful.count)
            
            print("📊 Last \(lastNSuccessful.count) commands response time: \(String(format: "%.2f", averageResponseTime))s")
            return averageResponseTime
            
        } catch {
            print("Error fetching last \(maxCommands) coffee orders: \(error)")
            return 0.0
        }
    }
    
    /// Obține comenzile de cafea din ultimele N zile
    func getCoffeeOrders(fromDays days: Int) -> [CoffeeOrder] {
        let context = container.viewContext
        let request: NSFetchRequest<CoffeeOrder> = CoffeeOrder.fetchRequest()
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        request.predicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoffeeOrder.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching coffee orders: \(error)")
            return []
        }
    }
    
    /// Curăță manual datele vechi (apelat din Settings)
    func performManualCleanup() async -> (performanceRecords: Int, coffeeOrders: Int) {
        return await withCheckedContinuation { continuation in
            let context = newBackgroundContext()
            
            context.perform {
                var performanceCount = 0
                var coffeeCount = 0
                
                // Cleanup performance data older than 30 days
                let performanceRequest: NSFetchRequest<ESP32PerformanceLog> = ESP32PerformanceLog.fetchRequest()
                let calendar = Calendar.current
                let performanceCutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                performanceRequest.predicate = NSPredicate(format: "date < %@", performanceCutoff as NSDate)
                
                do {
                    let oldPerformanceRecords = try context.fetch(performanceRequest)
                    performanceCount = oldPerformanceRecords.count
                    for record in oldPerformanceRecords {
                        context.delete(record)
                    }
                } catch {
                    print("Error cleaning up performance data: \(error)")
                }
                
                // Cleanup coffee orders older than 6 months
                let coffeeRequest: NSFetchRequest<CoffeeOrder> = CoffeeOrder.fetchRequest()
                let coffeeCutoff = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                coffeeRequest.predicate = NSPredicate(format: "timestamp < %@", coffeeCutoff as NSDate)
                
                do {
                    let oldCoffeeOrders = try context.fetch(coffeeRequest)
                    coffeeCount = oldCoffeeOrders.count
                    for order in oldCoffeeOrders {
                        context.delete(order)
                    }
                } catch {
                    print("Error cleaning up coffee orders: \(error)")
                }
                
                // Save changes
                do {
                    if context.hasChanges {
                        try context.save()
                    }
                    print("🧹 Manual cleanup completed: \(performanceCount) performance records, \(coffeeCount) coffee orders")
                } catch {
                    print("Error saving cleanup changes: \(error)")
                }
                
                continuation.resume(returning: (performanceCount, coffeeCount))
            }
        }
    }
    
    /// Curăță datele vechi de performance (păstrează doar ultimele 30 de zile)
    private func cleanupOldPerformanceData() {
        let context = newBackgroundContext()
        
        context.performAndSaveAsync {
            let request: NSFetchRequest<ESP32PerformanceLog> = ESP32PerformanceLog.fetchRequest()
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            request.predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
            
            do {
                let oldRecords = try context.fetch(request)
                for record in oldRecords {
                    context.delete(record)
                }
                print("Cleaned up \(oldRecords.count) old performance records")
            } catch {
                print("Error cleaning up old performance data: \(error)")
            }
        }
    }
}

// MARK: - Preview Data Creation

private func createPreviewData(in context: NSManagedObjectContext) {
    // Sample sleep session
    let sleepSession = SleepSession()
    sleepSession.date = Date()
    sleepSession.duration = 8.5 * 3600 // 8.5 hours
    sleepSession.quality = 78.5
    sleepSession.heartRate = 58.0
    sleepSession.steps = 8247
    sleepSession.energyBurned = 2150.0
    sleepSession.wakeUpTime = Date().addingTimeInterval(-2 * 3600) // 2 hours ago
    sleepSession.deepSleepPercentage = 18.5
    sleepSession.remSleepPercentage = 22.3
    
    // Sample coffee orders
    let coffeeOrder1 = CoffeeOrder()
    coffeeOrder1.timestamp = Date().addingTimeInterval(-1800) // 30 min ago
    coffeeOrder1.type = "latte"
    coffeeOrder1.trigger = "auto"
    coffeeOrder1.success = true
    coffeeOrder1.responseTime = 2.3
    coffeeOrder1.wakeDetectionConfidence = 85.5
    coffeeOrder1.userOverride = false
    coffeeOrder1.countdownCancelled = false
    coffeeOrder1.esp32ResponseCode = 200
    coffeeOrder1.estimatedBrewTime = 90.0
    coffeeOrder1.sleepSession = sleepSession
    
    let coffeeOrder2 = CoffeeOrder()
    coffeeOrder2.timestamp = Date().addingTimeInterval(-3600) // 1 hour ago
    coffeeOrder2.type = "espresso"
    coffeeOrder2.trigger = "manual"
    coffeeOrder2.success = true
    coffeeOrder2.responseTime = 1.8
    coffeeOrder2.wakeDetectionConfidence = 0.0
    coffeeOrder2.userOverride = true
    coffeeOrder2.countdownCancelled = false
    coffeeOrder2.esp32ResponseCode = 200
    coffeeOrder2.estimatedBrewTime = 75.0
    
    let coffeeOrder3 = CoffeeOrder()
    coffeeOrder3.timestamp = Date().addingTimeInterval(-7200) // 2 hours ago
    coffeeOrder3.type = "espresso_large"
    coffeeOrder3.trigger = "auto"
    coffeeOrder3.success = true
    coffeeOrder3.responseTime = 2.1
    coffeeOrder3.wakeDetectionConfidence = 92.3
    coffeeOrder3.userOverride = false
    coffeeOrder3.countdownCancelled = false
    coffeeOrder3.esp32ResponseCode = 200
    coffeeOrder3.estimatedBrewTime = 120.0
    coffeeOrder3.sleepSession = sleepSession
    
    // Device settings
    let deviceSettings = DeviceSettings()
    deviceSettings.autoModeEnabled = true
    deviceSettings.countdownDuration = 30
    deviceSettings.requireConfirmation = true
    deviceSettings.wakeDetectionSensitivity = 0.75
    deviceSettings.autoOnlyOnWeekdays = false
    deviceSettings.esp32IpAddress = "192.168.1.100"
    deviceSettings.esp32Port = 80
    deviceSettings.lastConnectionTest = Date().addingTimeInterval(-300) // 5 min ago
    deviceSettings.preferredWakeTime = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date())
    deviceSettings.coffeeStrengthOverride = "medium"
    
    // App metrics
    let metrics = AppMetrics()
    metrics.date = Date()
    metrics.totalCoffeesRequested = 5
    metrics.successfulAutoTriggers = 3
    metrics.failedAutoTriggers = 0
    metrics.manualOverrides = 2
    metrics.averageResponseTime = 2.1
    metrics.healthKitAccessErrors = 0
    metrics.esp32ConnectionErrors = 1
}

// MARK: - Core Data Extensions

extension NSManagedObjectContext {
    /// Execută o operație și salvează contextul
    func performAndSave(_ block: () throws -> Void) throws {
        try block()
        if hasChanges {
            try save()
        }
    }
    
    /// Execută async și salvează
    func performAndSaveAsync(_ block: @escaping () throws -> Void) {
        perform {
            do {
                try self.performAndSave(block)
            } catch {
                print("Context save error: \(error)")
            }
        }
    }
}
