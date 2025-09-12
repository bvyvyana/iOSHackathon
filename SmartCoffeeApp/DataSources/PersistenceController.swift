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
        let entityNames = ["SleepSession", "CoffeeOrder", "DeviceSettings", "AppMetrics"]
        
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
    coffeeOrder2.type = "scurt"
    coffeeOrder2.trigger = "manual"
    coffeeOrder2.success = true
    coffeeOrder2.responseTime = 1.8
    coffeeOrder2.wakeDetectionConfidence = 0.0
    coffeeOrder2.userOverride = true
    coffeeOrder2.countdownCancelled = false
    coffeeOrder2.esp32ResponseCode = 200
    coffeeOrder2.estimatedBrewTime = 75.0
    
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
    func performAndSave(_ block: @escaping () throws -> Void) {
        perform {
            do {
                try self.performAndSave(block)
            } catch {
                print("Context save error: \(error)")
            }
        }
    }
}
