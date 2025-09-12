import Foundation

/// Engine pentru luarea deciziilor inteligente despre tipul și intensitatea cafelei
class CoffeeDecisionEngine {
    
    private let userPreferences: UserCoffeePreferences
    private let historicalData: HistoricalDataAnalyzer
    
    init(userPreferences: UserCoffeePreferences = UserCoffeePreferences()) {
        self.userPreferences = userPreferences
        self.historicalData = HistoricalDataAnalyzer()
    }
    
    /// Funcția principală de decizie pentru tipul de cafea
    func decideCoffeeType(
        sleepData: SleepData,
        userPreferences: UserCoffeePreferences? = nil,
        timeOfDay: Date = Date(),
        consumedCaffeineToday: Double = 0
    ) -> CoffeeRecommendation {
        
        let prefs = userPreferences ?? self.userPreferences
        
        // 1. Analiza de bază pe baza somnului
        var baseRecommendation = calculateBasicRecommendation(sleepData)
        
        // 2. Ajustări temporale
        baseRecommendation = applyTimeAdjustments(baseRecommendation, timeOfDay)
        
        // 3. Aplicare preferințe utilizator
        baseRecommendation = applyUserPreferences(baseRecommendation, prefs)
        
        // 4. Verificare limite de cafeină
        baseRecommendation = applyCaffeineConstraints(baseRecommendation, consumedCaffeineToday, prefs)
        
        // 5. Învățare din date istorice
        baseRecommendation = applyHistoricalLearning(baseRecommendation, sleepData)
        
        // 6. Verificări finale de siguranță
        baseRecommendation = applyFinalSafetyChecks(baseRecommendation, timeOfDay)
        
        return baseRecommendation
    }
    
    // MARK: - Core Decision Algorithm
    
    private func calculateBasicRecommendation(_ sleepData: SleepData) -> CoffeeRecommendation {
        let sleepHours = sleepData.sleepDuration / 3600
        let quality = sleepData.sleepQuality
        let fatigue = sleepData.fatigueLevel
        
        // Calculează factorii de decizie
        let coffeeStrength = calculateCoffeeStrength(sleepHours: sleepHours, quality: quality, fatigue: fatigue)
        let urgency = calculateUrgency(sleepHours: sleepHours, quality: quality, fatigue: fatigue)
        let confidence = calculateConfidence(sleepHours: sleepHours, quality: quality)
        
        // Determină tipul de cafea
        let coffeeType = determineCoffeeType(strength: coffeeStrength, fatigue: fatigue)
        
        // Creează explicația
        let reasoning = generateReasoning(
            sleepHours: sleepHours,
            quality: quality,
            fatigue: fatigue,
            type: coffeeType,
            strength: coffeeStrength
        )
        
        let sleepFactors = SleepFactors(
            duration: sleepHours,
            quality: quality,
            deepSleepPercent: sleepData.deepSleepPercentage,
            remSleepPercent: sleepData.remSleepPercentage,
            averageHeartRate: sleepData.averageHeartRate,
            wakeUpTime: sleepData.wakeUpDetected
        )
        
        let timeFactors = TimeFactors(
            currentTime: Date(),
            isWeekend: Calendar.current.isDateInWeekend(Date()),
            hourOfDay: Calendar.current.component(.hour, from: Date()),
            minutesSinceWake: calculateMinutesSinceWake(sleepData.wakeUpDetected)
        )
        
        return CoffeeRecommendation(
            type: coffeeType,
            strength: coffeeStrength,
            urgency: urgency,
            confidence: confidence,
            reasoning: reasoning,
            sleepFactors: sleepFactors,
            timeFactors: timeFactors
        )
    }
    
    private func calculateCoffeeStrength(sleepHours: Double, quality: Double, fatigue: FatigueLevel) -> Double {
        var strength: Double = 0.5 // Start cu intensitate medie
        
        // Factor 1: Durata somnului (40% impact)
        let durationFactor = max(0, (8.0 - sleepHours) / 8.0)
        strength += durationFactor * 0.4
        
        // Factor 2: Calitatea somnului (35% impact)
        let qualityFactor = max(0, (80.0 - quality) / 80.0)
        strength += qualityFactor * 0.35
        
        // Factor 3: Nivelul de oboseală direct (25% impact)
        strength += fatigue.recommendedCoffeeStrength * 0.25
        
        return min(1.0, max(0.1, strength))
    }
    
    private func calculateUrgency(sleepHours: Double, quality: Double, fatigue: FatigueLevel) -> Double {
        var urgency: Double = 0.5
        
        // Urgența crește cu oboseala
        switch fatigue {
        case .severe:
            urgency = 0.9
        case .high:
            urgency = 0.7
        case .moderate:
            urgency = 0.5
        case .low:
            urgency = 0.3
        }
        
        // Ajustează în funcție de somn foarte puțin
        if sleepHours < 5.0 {
            urgency = min(1.0, urgency + 0.3)
        }
        
        // Calitate foarte proastă mărește urgența
        if quality < 40.0 {
            urgency = min(1.0, urgency + 0.2)
        }
        
        return urgency
    }
    
    private func calculateConfidence(sleepHours: Double, quality: Double) -> Double {
        var confidence: Double = 0.8 // Încredere de bază ridicată
        
        // Scade încrederea pentru date incomplete sau extreme
        if sleepHours < 3.0 || sleepHours > 12.0 {
            confidence -= 0.3
        }
        
        if quality < 20.0 || quality > 95.0 {
            confidence -= 0.2
        }
        
        // Mărește încrederea pentru date în range normal
        if sleepHours >= 6.0 && sleepHours <= 9.0 && quality >= 60.0 {
            confidence = min(1.0, confidence + 0.1)
        }
        
        return max(0.3, confidence)
    }
    
    private func determineCoffeeType(strength: Double, fatigue: FatigueLevel) -> CoffeeType {
        // Decizie pe baza intensității și oboselii
        switch (strength, fatigue) {
        case (0.8..., _), (_, .severe):
            return .espressoScurt  // Maximum impact
        case (0.5..<0.8, _), (_, .high):
            return .espressoLung   // Medium-high impact
        default:
            return .latte          // Gentle impact
        }
    }
    
    // MARK: - Adjustment Methods
    
    private func applyTimeAdjustments(_ recommendation: CoffeeRecommendation, _ time: Date) -> CoffeeRecommendation {
        var adjusted = recommendation
        let hour = Calendar.current.component(.hour, from: time)
        let isWeekend = Calendar.current.isDateInWeekend(time)
        
        // Ajustări pe ora zilei
        switch hour {
        case 6...8:
            // Dimineața devreme - poate fi mai tare
            adjusted.strength = min(1.0, adjusted.strength + 0.1)
        case 9...11:
            // Dimineața normală - păstrează
            break
        case 12...14:
            // Prânz - reduce ușor
            adjusted.strength *= 0.9
        case 15...:
            // După-amiază/seară - reduce semnificativ
            adjusted.strength *= 0.6
            if hour >= 18 {
                // După ora 18 -> doar latte
                adjusted.type = .latte
                adjusted.strength = min(0.4, adjusted.strength)
            }
        default:
            // Foarte devreme sau târziu
            adjusted.strength *= 0.7
        }
        
        // Ajustări weekend
        if isWeekend {
            adjusted.urgency *= 0.7
            adjusted.strength *= 0.9
        }
        
        return adjusted
    }
    
    private func applyUserPreferences(_ recommendation: CoffeeRecommendation, _ preferences: UserCoffeePreferences) -> CoffeeRecommendation {
        var adjusted = recommendation
        
        // Override tip preferat
        if let preferredType = preferences.preferredType {
            adjusted.type = preferredType
        }
        
        // Ajustează intensitatea la preferința utilizatorului
        let userStrengthFactor = preferences.preferredStrength
        adjusted.strength = (adjusted.strength + userStrengthFactor) / 2.0
        
        return adjusted
    }
    
    private func applyCaffeineConstraints(_ recommendation: CoffeeRecommendation, _ consumedToday: Double, _ preferences: UserCoffeePreferences) -> CoffeeRecommendation {
        var adjusted = recommendation
        
        let recommendedCaffeine = adjusted.type.caffeineContent * adjusted.strength
        let totalAfterCoffee = consumedToday + recommendedCaffeine
        
        // Verifică dacă depășește limita zilnică
        if totalAfterCoffee > preferences.maxCaffeinePerDay {
            let remainingCaffeine = preferences.remainingCaffeineToday(consumedToday: consumedToday)
            
            if remainingCaffeine <= 0 {
                // Nu mai poate consume cafeină
                adjusted.type = .latte // Cea mai slabă opțiune
                adjusted.strength = 0.1
                adjusted.reasoning += "\n⚠️ Limită zilnică de cafeină atinsă"
            } else {
                // Ajustează pentru a rămâne în limite
                let maxStrength = remainingCaffeine / adjusted.type.caffeineContent
                adjusted.strength = min(adjusted.strength, maxStrength)
                adjusted.reasoning += "\n📊 Ajustat pentru limita de cafeină"
            }
        }
        
        return adjusted
    }
    
    private func applyHistoricalLearning(_ recommendation: CoffeeRecommendation, _ sleepData: SleepData) -> CoffeeRecommendation {
        // TODO: Implementează învățarea din date istorice
        // Pentru acum returnează recomandarea nemodificată
        return recommendation
    }
    
    private func applyFinalSafetyChecks(_ recommendation: CoffeeRecommendation, _ time: Date) -> CoffeeRecommendation {
        var adjusted = recommendation
        let hour = Calendar.current.component(.hour, from: time)
        
        // Verificări de siguranță
        
        // 1. Nu permite cafea foarte tare după ora 16
        if hour >= 16 && adjusted.strength > 0.6 {
            adjusted.strength = 0.6
            adjusted.reasoning += "\n🕐 Intensitate redusă pentru ora târzie"
        }
        
        // 2. Forțează latte după ora 18
        if hour >= 18 {
            adjusted.type = .latte
            adjusted.strength = min(0.4, adjusted.strength)
            adjusted.reasoning += "\n🌙 Latte pentru seară"
        }
        
        // 3. Limitează intensitatea maximă
        adjusted.strength = min(1.0, max(0.1, adjusted.strength))
        
        // 4. Limitează urgența
        adjusted.urgency = min(1.0, max(0.1, adjusted.urgency))
        
        return adjusted
    }
    
    // MARK: - Helper Methods
    
    private func generateReasoning(sleepHours: Double, quality: Double, fatigue: FatigueLevel, type: CoffeeType, strength: Double) -> String {
        var reasons: [String] = []
        
        // Analiză somn
        if sleepHours < 6.0 {
            reasons.append("💤 Somn scurt (\(String(format: "%.1f", sleepHours))h)")
        } else if sleepHours > 9.0 {
            reasons.append("😴 Somn lung (\(String(format: "%.1f", sleepHours))h)")
        } else {
            reasons.append("✅ Durată optimă de somn")
        }
        
        // Analiză calitate
        if quality < 50 {
            reasons.append("📉 Calitate scăzută (\(Int(quality))%)")
        } else if quality > 80 {
            reasons.append("⭐ Calitate excelentă (\(Int(quality))%)")
        }
        
        // Nivel oboseală
        reasons.append("\(fatigue.displayName.lowercased())")
        
        // Recomandare
        reasons.append("\(type.emoji) \(type.displayName)")
        
        if strength > 0.8 {
            reasons.append("💪 Intensitate maximă")
        } else if strength < 0.3 {
            reasons.append("🕊️ Intensitate blândă")
        }
        
        return reasons.joined(separator: " • ")
    }
    
    private func calculateMinutesSinceWake(_ wakeTime: Date?) -> Int? {
        guard let wakeTime = wakeTime else { return nil }
        return Int(Date().timeIntervalSince(wakeTime) / 60)
    }
}

// MARK: - Historical Data Analyzer

/// Analizor pentru învățarea din datele istorice ale utilizatorului
class HistoricalDataAnalyzer {
    
    func analyzeUserPatterns() {
        // TODO: Implementează analiza pattern-urilor utilizatorului
        // - Ora preferată pentru cafea
        // - Tipul preferat în funcție de oboseală
        // - Reacția la diferite intensități
        // - Pattern-uri weekend vs zilele de lucru
    }
    
    func predictOptimalCoffeeTime(based sleepData: SleepData) -> Date? {
        // TODO: Prezice ora optimă pentru cafea pe baza datelor istorice
        return nil
    }
    
    func calculatePersonalizedStrength(for fatigueLevel: FatigueLevel) -> Double {
        // TODO: Calculează intensitatea personalizată pe baza istoricului
        return fatigueLevel.recommendedCoffeeStrength
    }
}

// MARK: - Decision Context

/// Context pentru luarea deciziilor de cafea
struct CoffeeDecisionContext {
    let sleepData: SleepData
    let userPreferences: UserCoffeePreferences
    let timeOfDay: Date
    let consumedCaffeineToday: Double
    let dayOfWeek: Int
    let isWorkday: Bool
    let weatherConditions: WeatherConditions?
    let userMood: UserMood?
    let physicalActivity: PhysicalActivityLevel?
    
    var isOptimalCoffeeTime: Bool {
        let hour = Calendar.current.component(.hour, from: timeOfDay)
        return hour >= 6 && hour <= 10
    }
    
    var shouldAvoidCaffeine: Bool {
        let hour = Calendar.current.component(.hour, from: timeOfDay)
        return hour >= 18 || consumedCaffeineToday >= userPreferences.maxCaffeinePerDay
    }
}

// MARK: - Supporting Enums

enum WeatherConditions {
    case sunny, cloudy, rainy, cold, hot
    
    var caffeineAdjustment: Double {
        switch self {
        case .cold: return 0.1      // Mărește intensitatea pe frig
        case .hot: return -0.1      // Scade intensitatea pe cald
        default: return 0.0
        }
    }
}

enum UserMood {
    case energetic, tired, stressed, relaxed, neutral
    
    var recommendedCoffeeType: CoffeeType? {
        switch self {
        case .energetic: return .latte
        case .tired: return .espressoScurt
        case .stressed: return .latte
        case .relaxed: return .espressoLung
        case .neutral: return nil
        }
    }
}

enum PhysicalActivityLevel {
    case sedentary, light, moderate, vigorous
    
    var caffeineMultiplier: Double {
        switch self {
        case .sedentary: return 0.9
        case .light: return 1.0
        case .moderate: return 1.1
        case .vigorous: return 1.2
        }
    }
}
