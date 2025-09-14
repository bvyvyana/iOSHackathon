import Foundation
import HealthKit
import Combine

/// Manager pentru integrarea cu HealthKit și analiza datelor de somn
@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var currentSleepData: SleepData?
    @Published var wakeDetectionResult: WakeDetectionResult?
    @Published var isMonitoringWake = false
    @Published var currentAwakeStatus: AwakeStatus = .awake
    @Published var scheduledVerificationTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var isScheduledVerificationEnabled = false
    
    // Tipurile de date HealthKit necesare
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    ]
    
    private var wakeDetectionTimer: Timer?
    private var statusMonitoringTimer: Timer?
    private var autoCoffeeTimer: Timer?
    private let sleepAnalyzer = SleepAnalyzer()
    private let wakeDetectionEngine = WakeDetectionEngine()
    private let coffeeDecisionEngine = CoffeeDecisionEngine()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuthorizationStatus()
        // Detectarea automată se pornește automat
        startStatusMonitoring()
        setupNotificationObservers()
    }
    
    deinit {
        Task { @MainActor in
            stopWakeDetection()
            stopStatusMonitoring()
            stopAutoCoffeeTimer()
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Observer pentru schimbările manuale din SettingsViewModel
        NotificationCenter.default.publisher(for: .manualAwakeStatusChanged)
            .sink { [weak self] notification in
                if let statusChange = notification.object as? AwakeStatusChange {
                    self?.handleManualStatusChange(statusChange)
                }
            }
            .store(in: &cancellables)
        
        // Observer pentru schimbările automate de status
        NotificationCenter.default.publisher(for: .awakeStatusChanged)
            .sink { [weak self] notification in
                if let statusChange = notification.object as? AwakeStatusChange {
                    self?.handleAutomaticStatusChange(statusChange)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleManualStatusChange(_ statusChange: AwakeStatusChange) {
        // Actualizează statusul doar dacă e diferit
        if currentAwakeStatus != statusChange.newStatus {
            let oldStatus = currentAwakeStatus
            currentAwakeStatus = statusChange.newStatus
            
            print("🔄 HealthKitManager synced with manual change: \(oldStatus.displayName) → \(statusChange.newStatus.displayName)")
            
            // Salvează statusul în UserDefaults
            Task {
                await saveAwakeStatusToUserDefaults(statusChange.newStatus)
            }
        }
    }
    
    private func handleAutomaticStatusChange(_ statusChange: AwakeStatusChange) {
        // Verifică dacă statusul a trecut din dormit în treaz
        if statusChange.oldStatus == .sleeping && statusChange.newStatus == .awake {
            print("🌅 Status changed from sleeping to awake - triggering auto-coffee process")
            
            Task {
                await handleWakeUpToAwakeTransition(statusChange)
            }
        }
    }
    
    /// Gestionează tranziția din dormit în treaz - actualizează HealthKit și programează cafea
    private func handleWakeUpToAwakeTransition(_ statusChange: AwakeStatusChange) async {
        print("☕ Starting auto-coffee process after wake up detection")
        
        // 1. Actualizează datele HealthKit (ca la butonul de pe home)
        do {
            print("📊 Updating HealthKit data after wake up...")
            let _ = try await analyzeTodaysSleep()
            print("✅ HealthKit data updated successfully")
        } catch {
            print("❌ Failed to update HealthKit data: \(error.localizedDescription)")
        }
        
        // 2. Programează comanda de cafea după 1 minut
        scheduleAutoCoffeeAfterDelay(delay: 60.0) // 1 minut = 60 secunde
    }
    
    /// Programează comanda automată de cafea după o întârziere
    private func scheduleAutoCoffeeAfterDelay(delay: TimeInterval) {
        // Anulează timer-ul existent dacă există
        autoCoffeeTimer?.invalidate()
        
        print("⏰ Scheduling auto-coffee in \(Int(delay)) seconds...")
        
        autoCoffeeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.executeAutoCoffee()
            }
        }
        
        // Asigură-te că timer-ul rulează pe main run loop
        if let timer = autoCoffeeTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Execută comanda automată de cafea
    private func executeAutoCoffee() async {
        print("☕ Executing automatic coffee order...")
        
        // Anulează timer-ul
        autoCoffeeTimer?.invalidate()
        autoCoffeeTimer = nil
        
        // Verifică dacă avem date de somn pentru recomandare
        guard let sleepData = currentSleepData else {
            print("❌ No sleep data available for coffee recommendation")
            return
        }
        
        // Generează recomandarea de cafea
        let recommendation = coffeeDecisionEngine.decideCoffeeType(
            sleepData: sleepData,
            timeOfDay: Date(),
            consumedCaffeineToday: 0 // TODO: Get from actual data
        )
        
        print("🤖 Auto-coffee recommendation: \(recommendation.type.displayName) (confidence: \(Int(recommendation.confidence * 100))%)")
        
        // Notifică aplicația despre comanda automată programată
        NotificationCenter.default.post(
            name: .autoCoffeeScheduled,
            object: AutoCoffeeScheduled(
                recommendation: recommendation,
                scheduledTime: Date(),
                delay: 60.0
            )
        )
        
        // Trimite comanda către ESP32 prin notificare
        NotificationCenter.default.post(
            name: .executeAutoCoffee,
            object: AutoCoffeeCommand(
                type: recommendation.type,
                trigger: .auto,
                sleepData: sleepData,
                confidence: recommendation.confidence
            )
        )
        
        print("📱 Auto-coffee command sent: \(recommendation.type.displayName)")
    }
    
    // MARK: - Authorization
    
    func requestPermissions() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            return false
        }
        
        print("🔐 Requesting HealthKit permissions...")
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ HealthKit permission error: \(error)")
                        continuation.resume(throwing: error)
                    } else {
                        print("✅ HealthKit permissions granted: \(success)")
                        self.isAuthorized = success
                        continuation.resume(returning: success)
                    }
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let status = healthStore.authorizationStatus(for: sleepType)
        
        DispatchQueue.main.async {
            self.isAuthorized = (status == .sharingAuthorized)
        }
    }
    
    // MARK: - Sleep Data Collection
    
    /// Analizează somnul de azi și returnează datele structurate
    func analyzeTodaysSleep() async throws -> SleepData {
        guard isAuthorized else {
            print("❌ HealthKit not authorized for sleep analysis")
            throw HealthKitError.notAuthorized
        }
        
        print("📊 Starting sleep data analysis...")
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Colectează date paralel pentru performanță
        async let sleepData = fetchSleepData(from: startOfDay, to: now)
        async let heartRateData = fetchHeartRateData(from: startOfDay, to: now)
        async let stepsData = fetchStepsData(from: startOfDay, to: now)
        async let energyData = fetchEnergyData(from: startOfDay, to: now)
        
        let (sleep, heartRate, steps, energy) = try await (sleepData, heartRateData, stepsData, energyData)
        
        print("📈 Collected data - Sleep: \(sleep.count), Heart Rate: \(heartRate.count), Steps: \(steps.count), Energy: \(energy.count)")
        
        let processedSleepData = try sleepAnalyzer.processSleepData(
            sleepSamples: sleep,
            heartRateSamples: heartRate,
            stepsSamples: steps,
            energySamples: energy,
            date: now
        )
        
        print("✅ Sleep analysis completed - Duration: \(processedSleepData.sleepDuration/3600)h, Quality: \(processedSleepData.sleepQuality)")
        
        DispatchQueue.main.async {
            self.currentSleepData = processedSleepData
        }
        
        return processedSleepData
    }
    
    /// Pornește monitorizarea continuă pentru detectarea trezirii
    func startWakeDetection() {
        guard isAuthorized && !isMonitoringWake else { return }
        
        isMonitoringWake = true
        
        // Monitorizare la fiecare 30 de secunde
        wakeDetectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.performWakeDetection()
            }
        }
        
        print("Wake detection started")
    }
    
    /// Oprește monitorizarea trezirii
    func stopWakeDetection() {
        wakeDetectionTimer?.invalidate()
        wakeDetectionTimer = nil
        isMonitoringWake = false
        
        print("Wake detection stopped")
    }
    
    private func performWakeDetection() async {
        do {
            let result = try await wakeDetectionEngine.detectWakeUp(using: healthStore)
            
            DispatchQueue.main.async {
                self.wakeDetectionResult = result
                
                // Dacă detectează trezirea cu încredere mare, oprește monitorizarea
                if result.isAwake && result.confidence > 80.0 {
                    self.stopWakeDetection()
                    
                    // Notificare pentru procesul de auto-comandă cafea
                    NotificationCenter.default.post(
                        name: .wakeDetected,
                        object: result
                    )
                }
            }
        } catch {
            print("Wake detection error: \(error)")
        }
    }
    
    // MARK: - Data Fetching Methods
    
    private func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let sleepSamples = samples as? [HKCategorySample] ?? []
                    continuation.resume(returning: sleepSamples)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let heartRateSamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: heartRateSamples)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchStepsData(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepsType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let stepsSamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: stepsSamples)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchEnergyData(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: energyType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let energySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: energySamples)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Real-time Heart Rate Monitoring
    
    /// Pornește monitorizarea în timp real a ritmului cardiac pentru detectarea trezirii
    func startRealtimeHeartRateMonitoring() {
        guard isAuthorized else { return }
        
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            
            if let error = error {
                print("Real-time heart rate monitoring error: \(error)")
                return
            }
            
            guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
            
            // Procesează noile sample-uri pentru detectarea trezirii
            DispatchQueue.main.async {
                self?.processRealtimeHeartRate(samples: heartRateSamples)
            }
        }
        
        query.updateHandler = { [weak self] _, samples, _, _, error in
            if let error = error {
                print("Heart rate update error: \(error)")
                return
            }
            
            guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
            
            DispatchQueue.main.async {
                self?.processRealtimeHeartRate(samples: heartRateSamples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processRealtimeHeartRate(samples: [HKQuantitySample]) {
        // Procesare pentru detectarea în timp real a trezirii
        let recentSamples = samples.filter { sample in
            sample.endDate.timeIntervalSinceNow > -300 // Ultimele 5 minute
        }
        
        if !recentSamples.isEmpty {
            Task {
                await performWakeDetection()
            }
        }
    }
    
    // MARK: - Automatic Status Detection
    
    /// Pornește monitorizarea automată a statusului de treaz/dormit
    func startStatusMonitoring() {
        // Oprește timer-ul existent dacă există
        stopStatusMonitoring()
        
        // Verifică statusul inițial
        Task { @MainActor in
            await checkAndUpdateAwakeStatus()
        }
        
        // Programează verificări periodice la fiecare 30 de secunde pentru testare mai rapidă
        statusMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndUpdateAwakeStatus()
            }
        }
        
        // Asigură-te că timer-ul rulează pe main run loop
        if let timer = statusMonitoringTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🔄 Started automatic awake status monitoring (every 30 seconds)")
    }
    
    /// Oprește monitorizarea automată a statusului
    func stopStatusMonitoring() {
        statusMonitoringTimer?.invalidate()
        statusMonitoringTimer = nil
        print("⏹️ Stopped automatic awake status monitoring")
    }
    
    /// Oprește timer-ul pentru comanda automată de cafea
    private func stopAutoCoffeeTimer() {
        autoCoffeeTimer?.invalidate()
        autoCoffeeTimer = nil
        print("⏹️ Stopped auto-coffee timer")
    }
    
    /// Verifică și actualizează statusul de treaz/dormit pe baza datelor HealthKit
    func checkAndUpdateAwakeStatus() async {
        print("🔍 Checking awake status at \(Date().formatted(date: .omitted, time: .standard))")
        
        guard isAuthorized else { 
            print("❌ HealthKit not authorized, skipping status check")
            // Dacă HealthKit nu e autorizat, presupune că ești treaz în timpul zilei
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 6 && hour <= 22 {
                print("🌅 No HealthKit access, assuming awake during daytime")
                let newStatus: AwakeStatus = .awake
                if newStatus != currentAwakeStatus {
                    let oldStatus = currentAwakeStatus
                    currentAwakeStatus = newStatus
                    print("🔄 Status changed (no HealthKit): \(oldStatus.displayName) → \(newStatus.displayName)")
                    
                    NotificationCenter.default.post(
                        name: .awakeStatusChanged,
                        object: AwakeStatusChange(
                            oldStatus: oldStatus,
                            newStatus: newStatus,
                            confidence: 60.0,
                            timestamp: Date(),
                            detectionMethod: .timeOfDay,
                            source: .automatic
                        )
                    )
                }
            }
            return 
        }
        
        do {
            // Detectează trezirea folosind engine-ul existent
            let wakeResult = try await wakeDetectionEngine.detectWakeUp(using: healthStore)
            
            print("📊 Wake detection result: isAwake=\(wakeResult.isAwake), confidence=\(Int(wakeResult.confidence))%")
            
            // Determină noul status pe baza rezultatului
            let newStatus: AwakeStatus = wakeResult.isAwake ? .awake : .sleeping
            
            // Actualizează statusul doar dacă s-a schimbat
            if newStatus != currentAwakeStatus {
                let oldStatus = currentAwakeStatus
                currentAwakeStatus = newStatus
                
                print("🔄 Status changed: \(oldStatus.displayName) → \(newStatus.displayName) (confidence: \(Int(wakeResult.confidence))%)")
                
                // Notifică alte părți ale aplicației despre schimbarea statusului
                NotificationCenter.default.post(
                    name: .awakeStatusChanged,
                    object: AwakeStatusChange(
                        oldStatus: oldStatus,
                        newStatus: newStatus,
                        confidence: wakeResult.confidence,
                        timestamp: Date(),
                        detectionMethod: wakeResult.detectionMethod,
                        source: .healthKit
                    )
                )
                
                // Salvează statusul în UserDefaults
                await saveAwakeStatusToUserDefaults(newStatus)
            } else {
                print("✅ Status unchanged: \(newStatus.displayName)")
            }
            
        } catch {
            print("❌ Error checking awake status: \(error.localizedDescription)")
        }
    }
    
    /// Salvează statusul de treaz/dormit în UserDefaults
    private func saveAwakeStatusToUserDefaults(_ status: AwakeStatus) async {
        do {
            let data = try JSONEncoder().encode(status)
            UserDefaults.standard.set(data, forKey: "awake_status")
            print("💾 Saved awake status to UserDefaults: \(status.displayName)")
        } catch {
            print("❌ Error saving awake status: \(error.localizedDescription)")
        }
    }
    
    /// Încarcă statusul de treaz/dormit din UserDefaults
    func loadAwakeStatusFromUserDefaults() async {
        guard let data = UserDefaults.standard.data(forKey: "awake_status"),
              let status = try? JSONDecoder().decode(AwakeStatus.self, from: data) else {
            return
        }
        
        currentAwakeStatus = status
        print("📱 Loaded awake status from UserDefaults: \(status.displayName)")
    }
    
    /// Funcție de debug pentru a forța detectarea manuală
    func forceStatusCheck() async {
        print("🔧 Force checking awake status...")
        await checkAndUpdateAwakeStatus()
    }
    
    /// Funcție de debug pentru a seta manual statusul
    func setManualAwakeStatus(_ status: AwakeStatus) {
        let oldStatus = currentAwakeStatus
        currentAwakeStatus = status
        
        print("🔧 Manual status change: \(oldStatus.displayName) → \(status.displayName)")
        
        NotificationCenter.default.post(
            name: .awakeStatusChanged,
            object: AwakeStatusChange(
                oldStatus: oldStatus,
                newStatus: status,
                confidence: 100.0,
                timestamp: Date(),
                detectionMethod: .timeOfDay,
                source: .manual
            )
        )
        
        Task {
            await saveAwakeStatusToUserDefaults(status)
        }
    }
    
}

// MARK: - Supporting Classes

/// Analizor pentru procesarea datelor de somn din HealthKit
class SleepAnalyzer {
    
    func processSleepData(
        sleepSamples: [HKCategorySample],
        heartRateSamples: [HKQuantitySample],
        stepsSamples: [HKQuantitySample],
        energySamples: [HKQuantitySample],
        date: Date
    ) throws -> SleepData {
        
        let sleepDuration = calculateSleepDuration(samples: sleepSamples)
        let sleepQuality = calculateSleepQuality(samples: sleepSamples)
        let avgHeartRate = calculateAverageHeartRate(samples: heartRateSamples)
        let totalSteps = calculateTotalSteps(samples: stepsSamples)
        let totalEnergy = calculateTotalEnergy(samples: energySamples)
        let (deepPercent, remPercent) = calculateSleepStages(samples: sleepSamples)
        let wakeTime = detectWakeUpTime(sleepSamples: sleepSamples, heartRateSamples: heartRateSamples)
        
        return SleepData(
            date: date,
            sleepDuration: sleepDuration,
            sleepQuality: sleepQuality,
            averageHeartRate: avgHeartRate,
            stepsYesterday: totalSteps,
            energyBurned: totalEnergy,
            wakeUpDetected: wakeTime,
            wakeUpConfirmed: nil,
            deepSleepPercentage: deepPercent,
            remSleepPercentage: remPercent
        )
    }
    
    private func calculateSleepDuration(samples: [HKCategorySample]) -> TimeInterval {
        return samples.reduce(0) { total, sample in
            if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                return total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            return total
        }
    }
    
    private func calculateSleepQuality(samples: [HKCategorySample]) -> Double {
        let totalSleep = calculateSleepDuration(samples: samples)
        guard totalSleep > 0 else { return 0 }
        
        let deepSleep = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }
                              .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        
        let remSleep = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                             .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        
        let deepPercentage = deepSleep / totalSleep
        let remPercentage = remSleep / totalSleep
        
        // Algoritm de calitate: Deep sleep 40%, REM 30%, durata 30%
        let deepScore = min(1.0, max(0, (deepPercentage - 0.10) / 0.15)) * 40
        let remScore = min(1.0, max(0, (remPercentage - 0.15) / 0.15)) * 30
        let durationScore = min(1.0, max(0, (totalSleep / 3600 - 6) / 3)) * 30
        
        return deepScore + remScore + durationScore
    }
    
    private func calculateAverageHeartRate(samples: [HKQuantitySample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        
        let total = samples.reduce(0.0) { total, sample in
            total + sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        }
        
        return total / Double(samples.count)
    }
    
    private func calculateTotalSteps(samples: [HKQuantitySample]) -> Int {
        let total = samples.reduce(0.0) { total, sample in
            total + sample.quantity.doubleValue(for: HKUnit.count())
        }
        return Int(total)
    }
    
    private func calculateTotalEnergy(samples: [HKQuantitySample]) -> Double {
        return samples.reduce(0.0) { total, sample in
            total + sample.quantity.doubleValue(for: HKUnit.kilocalorie())
        }
    }
    
    private func calculateSleepStages(samples: [HKCategorySample]) -> (deep: Double, rem: Double) {
        let totalSleep = calculateSleepDuration(samples: samples)
        guard totalSleep > 0 else { return (0, 0) }
        
        let deepSleep = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }
                              .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        
        let remSleep = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                             .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        
        return (deepSleep / totalSleep * 100, remSleep / totalSleep * 100)
    }
    
    private func detectWakeUpTime(sleepSamples: [HKCategorySample], heartRateSamples: [HKQuantitySample]) -> Date? {
        // Găsește ultima secvență de somn
        let lastSleepSample = sleepSamples
            .filter { $0.value != HKCategoryValueSleepAnalysis.awake.rawValue }
            .max { $0.endDate < $1.endDate }
        
        return lastSleepSample?.endDate
    }
}

/// Engine pentru detectarea trezirii bazat pe multiple surse de date
class WakeDetectionEngine {
    private var heartRateBuffer: [Double] = []
    private var movementBuffer: [Double] = []
    private let bufferSize = 50
    
    func detectWakeUp(using healthStore: HKHealthStore) async throws -> WakeDetectionResult {
        let currentTime = Date()
        let last30Minutes = currentTime.addingTimeInterval(-1800)
        
        // Colectează date recente
        async let heartRateData = fetchRecentHeartRate(healthStore: healthStore, from: last30Minutes, to: currentTime)
        async let sleepState = getCurrentSleepState(healthStore: healthStore)
        async let recentActivity = getRecentActivity(healthStore: healthStore, from: last30Minutes, to: currentTime)
        
        let (heartRate, sleep, activity) = try await (heartRateData, sleepState, recentActivity)
        
        // Analiză multi-factor
        let baseline = calculateSleepingBaseline(heartRate)
        let currentHR = heartRate.last?.quantity.doubleValue(for: HKUnit(from: "count/min")) ?? 0
        
        let heartRateSpike = currentHR > (baseline + 15)
        let sleepStateAwake = sleep
        let timeBasedLikelihood = calculateTimeBasedWakeProbability(currentTime)
        let hasRecentActivity = activity > 0
        
        // Calculează încrederea cu algoritm îmbunătățit
        var confidence: Double = 0.0
        let hour = Calendar.current.component(.hour, from: currentTime)
        let isDaytime = hour >= 6 && hour <= 22
        
        // 1. Verifică dacă există date de somn recente
        if sleepStateAwake {
            confidence += 60.0 // Dacă HealthKit spune că ești treaz, încredere mare
        }
        
        // 2. Verifică ritmul cardiac
        if heartRateSpike {
            confidence += 35.0
        } else if currentHR > 0 && currentHR < 50 {
            // Ritm cardiac foarte scăzut - probabil dormi
            confidence -= 25.0
        }
        
        // 3. Verifică activitatea recentă
        if hasRecentActivity {
            confidence += 30.0
        }
        
        // 4. Verifică ora zilei - factorul cel mai important
        confidence += timeBasedLikelihood * 40.0
        
        // 5. Dacă nu avem date HealthKit suficiente, presupune că ești treaz în timpul zilei
        if heartRate.isEmpty && !sleepStateAwake {
            if isDaytime {
                confidence = 70.0 // Presupune că ești treaz în timpul zilei
            } else {
                confidence = 20.0 // Presupune că dormi noaptea
            }
        }
        
        // 6. Bonus pentru timpul zilei - dacă ești în timpul zilei, crește încrederea
        if isDaytime && confidence < 50.0 {
            confidence += 30.0 // Bonus pentru timpul zilei
        }
        
        let isAwake = confidence > 40.0 // Prag mai scăzut pentru detectare mai sensibilă
        
        print("🔍 Detection details:")
        print("   📊 Heart Rate: \(Int(currentHR)) BPM (baseline: \(Int(baseline)) BPM)")
        print("   💓 HR Spike: \(heartRateSpike ? "YES" : "NO")")
        print("   😴 Sleep State: \(sleepStateAwake ? "AWAKE" : "ASLEEP")")
        print("   🚶 Activity: \(activity) steps")
        print("   ⏰ Time: \(hour):00 (daytime: \(isDaytime ? "YES" : "NO"))")
        print("   📈 Time Probability: \(Int(timeBasedLikelihood*100))%")
        print("   🎯 Final Confidence: \(Int(confidence))%")
        print("   ✅ Result: \(isAwake ? "AWAKE" : "SLEEPING")")
        
        return WakeDetectionResult(
            isAwake: isAwake,
            confidence: min(100.0, max(0.0, confidence)),
            heartRateBaseline: baseline,
            currentHeartRate: currentHR,
            timestamp: currentTime,
            detectionMethod: .combined
        )
    }
    
    private func fetchRecentHeartRate(healthStore: HKHealthStore, from: Date, to: Date) async throws -> [HKQuantitySample] {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 10,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getCurrentSleepState(healthStore: HKHealthStore) async throws -> Bool {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let last2Hours = now.addingTimeInterval(-7200)
        let predicate = HKQuery.predicateForSamples(withStart: last2Hours, end: now, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let lastSample = samples?.first as? HKCategorySample
                    let isAwake = lastSample?.value == HKCategoryValueSleepAnalysis.awake.rawValue
                    continuation.resume(returning: isAwake)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func getRecentActivity(healthStore: HKHealthStore, from: Date, to: Date) async throws -> Int {
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepsType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let stepsSamples = samples as? [HKQuantitySample] ?? []
                    let totalSteps = stepsSamples.reduce(0) { total, sample in
                        total + Int(sample.quantity.doubleValue(for: HKUnit.count()))
                    }
                    continuation.resume(returning: totalSteps)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func calculateSleepingBaseline(_ samples: [HKQuantitySample]) -> Double {
        guard !samples.isEmpty else { return 60.0 }
        
        let heartRates = samples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
        let sortedRates = heartRates.sorted()
        
        // Folosește percentila 25 ca baseline (cele mai scăzute valori)
        let index = max(0, Int(Double(sortedRates.count) * 0.25))
        return sortedRates[index]
    }
    
    private func calculateTimeBasedWakeProbability(_ time: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: time)
        
        switch hour {
        case 0...5: return 0.1  // Noaptea - foarte puțin probabil să fii treaz
        case 6...8: return 0.9  // Dimineața - foarte probabil să fii treaz
        case 9...11: return 0.8 // Dimineața târzie - probabil treaz
        case 12...17: return 0.7 // După-amiaza - probabil treaz
        case 18...21: return 0.6 // Seara - moderat probabil treaz
        case 22...23: return 0.2 // Seara târzie - puțin probabil treaz
        default: return 0.1
        }
    }
}

// MARK: - Errors

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case notAuthorized
    case noData
    case processingError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit nu este disponibil pe acest dispozitiv"
        case .notAuthorized:
            return "Accesul la HealthKit nu este autorizat"
        case .noData:
            return "Nu sunt disponibile date de somn"
        case .processingError(let message):
            return "Eroare procesare date: \(message)"
        }
    }
}

// MARK: - Supporting Models

/// Model pentru schimbarea statusului de treaz/dormit
struct AwakeStatusChange {
    let oldStatus: AwakeStatus
    let newStatus: AwakeStatus
    let confidence: Double
    let timestamp: Date
    let detectionMethod: WakeDetectionMethod
    let source: AwakeStatusSource
    
    var description: String {
        return "Status changed from \(oldStatus.displayName) to \(newStatus.displayName) with \(Int(confidence))% confidence"
    }
}

enum AwakeStatusSource {
    case automatic
    case manual
    case healthKit
}

// MARK: - Notifications

extension Notification.Name {
    static let wakeDetected = Notification.Name("wakeDetected")
    static let awakeStatusChanged = Notification.Name("awakeStatusChanged")
    static let autoCoffeeScheduled = Notification.Name("autoCoffeeScheduled")
    static let executeAutoCoffee = Notification.Name("executeAutoCoffee")
}

