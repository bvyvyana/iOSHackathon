import Foundation
import HealthKit

/// Core model pentru datele de somn colectate din HealthKit
struct SleepData {
    let date: Date
    let sleepDuration: TimeInterval        // în secunde
    let sleepQuality: Double              // scor 0-100
    let averageHeartRate: Double          // BPM mediu
    let stepsYesterday: Int               // pași din ziua precedentă
    let energyBurned: Double              // kcal consumate
    let wakeUpDetected: Date?             // momentul detectat de trezire
    let wakeUpConfirmed: Date?            // momentul confirmat de user
    let deepSleepPercentage: Double       // % somn profund
    let remSleepPercentage: Double        // % somn REM
    
    /// Calculează calitatea somnului pe baza diferitelor factori
    var computedQuality: Double {
        var score: Double = 0.0
        
        // Factor 1: Durata somnului (40% din scor)
        let sleepHours = sleepDuration / 3600
        let durationScore = calculateDurationScore(hours: sleepHours)
        score += durationScore * 0.4
        
        // Factor 2: Procentul de somn profund (30% din scor)
        let deepScore = calculateDeepSleepScore(percentage: deepSleepPercentage)
        score += deepScore * 0.3
        
        // Factor 3: Procentul de somn REM (20% din scor)
        let remScore = calculateREMScore(percentage: remSleepPercentage)
        score += remScore * 0.2
        
        // Factor 4: Stabilitatea ritmului cardiac (10% din scor)
        let heartRateScore = calculateHeartRateScore(avgHR: averageHeartRate)
        score += heartRateScore * 0.1
        
        return min(100.0, max(0.0, score))
    }
    
    /// Determină nivelul de oboseală pe baza datelor de somn
    var fatigueLevel: FatigueLevel {
        let quality = computedQuality
        let hours = sleepDuration / 3600
        
        switch (quality, hours) {
        case (80..., 7...):
            return .low
        case (60..<80, 6..<7):
            return .moderate
        case (40..<60, 5..<6):
            return .high
        default:
            return .severe
        }
    }
    
    // MARK: - Private Calculation Methods
    
    private func calculateDurationScore(hours: Double) -> Double {
        // Optimul: 7-9 ore
        switch hours {
        case 7...9:
            return 100.0
        case 6..<7, 9..<10:
            return 80.0
        case 5..<6, 10..<11:
            return 60.0
        case 4..<5, 11..<12:
            return 40.0
        default:
            return 20.0
        }
    }
    
    private func calculateDeepSleepScore(percentage: Double) -> Double {
        // Optimul: 15-20% somn profund
        switch percentage {
        case 15...20:
            return 100.0
        case 12..<15, 20..<25:
            return 80.0
        case 10..<12, 25..<30:
            return 60.0
        case 8..<10, 30..<35:
            return 40.0
        default:
            return 20.0
        }
    }
    
    private func calculateREMScore(percentage: Double) -> Double {
        // Optimul: 20-25% somn REM
        switch percentage {
        case 20...25:
            return 100.0
        case 15..<20, 25..<30:
            return 80.0
        case 10..<15, 30..<35:
            return 60.0
        case 5..<10, 35..<40:
            return 40.0
        default:
            return 20.0
        }
    }
    
    private func calculateHeartRateScore(avgHR: Double) -> Double {
        // Pentru adulți, ritmul cardiac de odihnă optim: 60-100 BPM
        switch avgHR {
        case 50...70:
            return 100.0  // Excellent
        case 70...80:
            return 80.0   // Good
        case 80...90:
            return 60.0   // Fair
        case 90...100:
            return 40.0   // Poor
        default:
            return 20.0   // Concerning
        }
    }
}

/// Nivelul de oboseală determinat pe baza calității somnului
enum FatigueLevel: String, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case severe = "severe"
    
    var displayName: String {
        switch self {
        case .low:
            return "Odihnit"
        case .moderate:
            return "Ușor obosit"
        case .high:
            return "Obosit"
        case .severe:
            return "Foarte obosit"
        }
    }
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .moderate:
            return "yellow"
        case .high:
            return "orange"
        case .severe:
            return "red"
        }
    }
    
    /// Recomandarea de cafea bazată pe nivelul de oboseală
    var recommendedCoffeeStrength: Double {
        switch self {
        case .low:
            return 0.3      // Cafea slabă
        case .moderate:
            return 0.6      // Cafea medie
        case .high:
            return 0.8      // Cafea tare
        case .severe:
            return 1.0      // Cafea foarte tare
        }
    }
}

/// Model pentru rezultatul detectării trezirii
struct WakeDetectionResult {
    let isAwake: Bool
    let confidence: Double              // 0-100
    let heartRateBaseline: Double       // BPM de referință din somn
    let currentHeartRate: Double        // BPM actual
    let timestamp: Date
    let detectionMethod: WakeDetectionMethod
    
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 90...:
            return .veryHigh
        case 70..<90:
            return .high
        case 50..<70:
            return .medium
        case 30..<50:
            return .low
        default:
            return .veryLow
        }
    }
}

enum WakeDetectionMethod: String {
    case heartRate = "heart_rate"
    case movement = "movement"
    case timeOfDay = "time_of_day"
    case combined = "combined"
    
    var displayName: String {
        switch self {
        case .heartRate:
            return "Ritm cardiac"
        case .movement:
            return "Mișcare"
        case .timeOfDay:
            return "Ora zilei"
        case .combined:
            return "Combinat"
        }
    }
}

enum ConfidenceLevel: String, CaseIterable {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .veryLow:
            return "Foarte scăzută"
        case .low:
            return "Scăzută"
        case .medium:
            return "Medie"
        case .high:
            return "Ridicată"
        case .veryHigh:
            return "Foarte ridicată"
        }
    }
}
