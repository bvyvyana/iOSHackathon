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
    private let sleepAnalyzer = SleepAnalyzer()
    private let wakeDetectionEngine = WakeDetectionEngine()
    
    init() {
        checkAuthorizationStatus()
    }
    
    deinit {
        stopWakeDetection()
    }
    
    // MARK: - Authorization
    
    func requestPermissions() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
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
            throw HealthKitError.notAuthorized
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Colectează date paralel pentru performanță
        async let sleepData = fetchSleepData(from: startOfDay, to: now)
        async let heartRateData = fetchHeartRateData(from: startOfDay, to: now)
        async let stepsData = fetchStepsData(from: startOfDay, to: now)
        async let energyData = fetchEnergyData(from: startOfDay, to: now)
        
        let (sleep, heartRate, steps, energy) = try await (sleepData, heartRateData, stepsData, energyData)
        
        let processedSleepData = try sleepAnalyzer.processSleepData(
            sleepSamples: sleep,
            heartRateSamples: heartRate,
            stepsSamples: steps,
            energySamples: energy,
            date: now
        )
        
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
               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                return total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            
            // Check for asleepCore only on iOS 16.0+
            if #available(iOS 16.0, *) {
                if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue {
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                }
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
        
        let (heartRate, sleep) = try await (heartRateData, sleepState)
        
        // Analiză multi-factor
        let baseline = calculateSleepingBaseline(heartRate)
        let currentHR = heartRate.last?.quantity.doubleValue(for: HKUnit(from: "count/min")) ?? 0
        
        let heartRateSpike = currentHR > (baseline + 15)
        let sleepStateAwake = sleep
        let timeBasedLikelihood = calculateTimeBasedWakeProbability(currentTime)
        
        // Calculează încrederea
        var confidence: Double = 0.0
        if heartRateSpike { confidence += 40.0 }
        if sleepStateAwake { confidence += 30.0 }
        confidence += timeBasedLikelihood * 30.0
        
        return WakeDetectionResult(
            isAwake: confidence > 70.0,
            confidence: min(100.0, confidence),
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
        case 0...5: return 0.1
        case 6...8: return 0.9
        case 9...11: return 0.7
        case 12...21: return 0.3
        case 22...23: return 0.2
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

// MARK: - Notifications

extension Notification.Name {
    static let wakeDetected = Notification.Name("wakeDetected")
}
