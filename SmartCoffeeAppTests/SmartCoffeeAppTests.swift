import XCTest
@testable import SmartCoffeeApp

/// Test suite principal pentru Smart Coffee App
class SmartCoffeeAppTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Basic App Tests
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}

// MARK: - Sleep Analysis Tests

class SleepAnalysisTests: XCTestCase {
    var sleepAnalyzer: SleepAnalyzer!
    
    override func setUpWithError() throws {
        sleepAnalyzer = SleepAnalyzer()
    }
    
    override func tearDownWithError() throws {
        sleepAnalyzer = nil
    }
    
    // MARK: - Sleep Quality Tests
    
    func testSleepQualityCalculation_ExcellentSleep() throws {
        // Given: Excellent sleep data
        let sleepData = createMockSleepData(
            duration: 8.0 * 3600, // 8 hours
            deepSleepPercent: 18.0,
            remSleepPercent: 22.0,
            averageHeartRate: 55.0
        )
        
        // When: Calculate quality
        let quality = sleepData.computedQuality
        
        // Then: Should be excellent quality
        XCTAssertGreaterThan(quality, 80.0, "Excellent sleep should have high quality score")
        XCTAssertLessThanOrEqual(quality, 100.0, "Quality should not exceed 100%")
    }
    
    func testSleepQualityCalculation_PoorSleep() throws {
        // Given: Poor sleep data
        let sleepData = createMockSleepData(
            duration: 4.0 * 3600, // 4 hours
            deepSleepPercent: 8.0,
            remSleepPercent: 12.0,
            averageHeartRate: 75.0
        )
        
        // When: Calculate quality
        let quality = sleepData.computedQuality
        
        // Then: Should be poor quality
        XCTAssertLessThan(quality, 50.0, "Poor sleep should have low quality score")
        XCTAssertGreaterThanOrEqual(quality, 0.0, "Quality should not be negative")
    }
    
    func testFatigueLevel_Calculation() throws {
        // Test different fatigue levels
        let testCases: [(duration: Double, quality: Double, expectedFatigue: FatigueLevel)] = [
            (8.0 * 3600, 85.0, .low),      // Good sleep
            (6.5 * 3600, 70.0, .moderate), // Average sleep
            (5.0 * 3600, 50.0, .high),     // Poor sleep
            (3.0 * 3600, 30.0, .severe)    // Very poor sleep
        ]
        
        for testCase in testCases {
            let sleepData = createMockSleepData(
                duration: testCase.duration,
                deepSleepPercent: 15.0,
                remSleepPercent: 20.0,
                averageHeartRate: 60.0
            )
            
            // When
            let fatigueLevel = sleepData.fatigueLevel
            
            // Then
            XCTAssertEqual(fatigueLevel, testCase.expectedFatigue,
                          "Duration: \(testCase.duration/3600)h, Quality: \(testCase.quality)% should result in \(testCase.expectedFatigue)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockSleepData(
        duration: TimeInterval,
        deepSleepPercent: Double,
        remSleepPercent: Double,
        averageHeartRate: Double
    ) -> SleepData {
        return SleepData(
            date: Date(),
            sleepDuration: duration,
            sleepQuality: 75.0, // Will be recalculated
            averageHeartRate: averageHeartRate,
            stepsYesterday: 8000,
            energyBurned: 2000.0,
            wakeUpDetected: Date(),
            wakeUpConfirmed: nil,
            deepSleepPercentage: deepSleepPercent,
            remSleepPercentage: remSleepPercent
        )
    }
}

// MARK: - Coffee Decision Engine Tests

class CoffeeDecisionEngineTests: XCTestCase {
    var decisionEngine: CoffeeDecisionEngine!
    var mockUserPreferences: UserCoffeePreferences!
    
    override func setUpWithError() throws {
        mockUserPreferences = UserCoffeePreferences()
        decisionEngine = CoffeeDecisionEngine(userPreferences: mockUserPreferences)
    }
    
    override func tearDownWithError() throws {
        decisionEngine = nil
        mockUserPreferences = nil
    }
    
    // MARK: - Coffee Type Decision Tests
    
    func testCoffeeDecision_GoodSleep_ShouldRecommendLatte() throws {
        // Given: Good sleep data
        let sleepData = createMockSleepData(
            duration: 8.0 * 3600,
            quality: 85.0,
            fatigue: .low
        )
        
        // When: Get recommendation
        let recommendation = decisionEngine.decideCoffeeType(sleepData: sleepData)
        
        // Then: Should recommend gentle coffee
        XCTAssertEqual(recommendation.type, .latte, "Good sleep should recommend latte")
        XCTAssertLessThan(recommendation.strength, 0.5, "Good sleep should have low strength")
        XCTAssertGreaterThan(recommendation.confidence, 0.7, "Should have high confidence")
    }
    
    func testCoffeeDecision_PoorSleep_ShouldRecommendStrongCoffee() throws {
        // Given: Poor sleep data
        let sleepData = createMockSleepData(
            duration: 4.0 * 3600,
            quality: 35.0,
            fatigue: .severe
        )
        
        // When: Get recommendation
        let recommendation = decisionEngine.decideCoffeeType(sleepData: sleepData)
        
        // Then: Should recommend strong coffee
        XCTAssertEqual(recommendation.type, .espressoScurt, "Poor sleep should recommend strong espresso")
        XCTAssertGreaterThan(recommendation.strength, 0.7, "Poor sleep should have high strength")
        XCTAssertGreaterThan(recommendation.confidence, 0.5, "Should have reasonable confidence")
    }
    
    func testCoffeeDecision_TimeOfDay_AfternoonReduction() throws {
        // Given: Afternoon time (3 PM)
        let afternoonTime = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
        let sleepData = createMockSleepData(duration: 6.0 * 3600, quality: 60.0, fatigue: .moderate)
        
        // When: Get recommendation for afternoon
        let recommendation = decisionEngine.decideCoffeeType(
            sleepData: sleepData,
            timeOfDay: afternoonTime
        )
        
        // Then: Should reduce caffeine
        XCTAssertLessThan(recommendation.strength, 0.7, "Afternoon should reduce caffeine strength")
    }
    
    func testCoffeeDecision_EveningTime_ShouldForceLatte() throws {
        // Given: Evening time (7 PM)
        let eveningTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!
        let sleepData = createMockSleepData(duration: 4.0 * 3600, quality: 30.0, fatigue: .severe)
        
        // When: Get recommendation for evening
        let recommendation = decisionEngine.decideCoffeeType(
            sleepData: sleepData,
            timeOfDay: eveningTime
        )
        
        // Then: Should force latte regardless of sleep quality
        XCTAssertEqual(recommendation.type, .latte, "Evening should force latte")
        XCTAssertLessThan(recommendation.strength, 0.5, "Evening should have low strength")
    }
    
    func testCoffeeDecision_CaffeineLimit_ShouldRespectDailyLimit() throws {
        // Given: Already consumed near daily limit
        let sleepData = createMockSleepData(duration: 6.0 * 3600, quality: 60.0, fatigue: .moderate)
        let consumedToday = 350.0 // mg (near 400mg limit)
        
        // When: Get recommendation
        let recommendation = decisionEngine.decideCoffeeType(
            sleepData: sleepData,
            consumedCaffeineToday: consumedToday
        )
        
        // Then: Should reduce strength to stay within limit
        let estimatedCaffeine = recommendation.type.caffeineContent * recommendation.strength
        XCTAssertLessThanOrEqual(consumedToday + estimatedCaffeine, 400.0, 
                               "Should not exceed daily caffeine limit")
    }
    
    // MARK: - User Preferences Tests
    
    func testCoffeeDecision_UserPreferredType_ShouldRespectPreference() throws {
        // Given: User prefers espresso lung
        mockUserPreferences.preferredType = .espressoLung
        let sleepData = createMockSleepData(duration: 8.0 * 3600, quality: 85.0, fatigue: .low)
        
        // When: Get recommendation
        let recommendation = decisionEngine.decideCoffeeType(sleepData: sleepData, userPreferences: mockUserPreferences)
        
        // Then: Should respect user preference
        XCTAssertEqual(recommendation.type, .espressoLung, "Should respect user preferred coffee type")
    }
    
    func testCoffeeDecision_UserStrengthPreference_ShouldInfluenceStrength() throws {
        // Given: User prefers strong coffee
        mockUserPreferences.preferredStrength = 0.9
        let sleepData = createMockSleepData(duration: 8.0 * 3600, quality: 85.0, fatigue: .low)
        
        // When: Get recommendation
        let recommendation = decisionEngine.decideCoffeeType(sleepData: sleepData, userPreferences: mockUserPreferences)
        
        // Then: Should influence strength towards user preference
        XCTAssertGreaterThan(recommendation.strength, 0.6, "Should be influenced by user's high strength preference")
    }
    
    // MARK: - Edge Cases Tests
    
    func testCoffeeDecision_ExtremelyLongSleep_ShouldHandleGracefully() throws {
        // Given: Extremely long sleep (12 hours)
        let sleepData = createMockSleepData(duration: 12.0 * 3600, quality: 60.0, fatigue: .low)
        
        // When: Get recommendation
        let recommendation = decisionEngine.decideCoffeeType(sleepData: sleepData)
        
        // Then: Should handle gracefully
        XCTAssertGreaterThanOrEqual(recommendation.strength, 0.1, "Strength should not be below minimum")
        XCTAssertLessThanOrEqual(recommendation.strength, 1.0, "Strength should not exceed maximum")
        XCTAssertGreaterThan(recommendation.confidence, 0.3, "Should maintain reasonable confidence")
    }
    
    func testCoffeeDecision_ZeroSleep_ShouldHandleGracefully() throws {
        // Given: Zero sleep (edge case)
        let sleepData = createMockSleepData(duration: 0, quality: 0, fatigue: .severe)
        
        // When: Get recommendation
        let recommendation = decisionEngine.decideCoffeeType(sleepData: sleepData)
        
        // Then: Should handle gracefully
        XCTAssertEqual(recommendation.type, .espressoScurt, "Zero sleep should recommend strongest coffee")
        XCTAssertGreaterThanOrEqual(recommendation.strength, 0.8, "Should recommend high strength")
    }
    
    // MARK: - Performance Tests
    
    func testCoffeeDecisionPerformance() throws {
        let sleepData = createMockSleepData(duration: 7.0 * 3600, quality: 75.0, fatigue: .moderate)
        
        measure {
            for _ in 0..<1000 {
                _ = decisionEngine.decideCoffeeType(sleepData: sleepData)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockSleepData(duration: TimeInterval, quality: Double, fatigue: FatigueLevel) -> SleepData {
        return SleepData(
            date: Date(),
            sleepDuration: duration,
            sleepQuality: quality,
            averageHeartRate: 60.0,
            stepsYesterday: 8000,
            energyBurned: 2000.0,
            wakeUpDetected: Date(),
            wakeUpConfirmed: nil,
            deepSleepPercentage: 18.0,
            remSleepPercentage: 22.0
        )
    }
}

// MARK: - Wake Detection Tests

class WakeDetectionTests: XCTestCase {
    var wakeDetectionEngine: WakeDetectionEngine!
    
    override func setUpWithError() throws {
        wakeDetectionEngine = WakeDetectionEngine()
    }
    
    override func tearDownWithError() throws {
        wakeDetectionEngine = nil
    }
    
    func testWakeDetection_HighConfidence_ShouldDetectWake() throws {
        // This would require mocking HealthKit data
        // For now, test the confidence calculation logic
        
        let currentTime = Date()
        
        // Mock detection result with high confidence
        let result = WakeDetectionResult(
            isAwake: true,
            confidence: 85.0,
            heartRateBaseline: 55.0,
            currentHeartRate: 72.0,
            timestamp: currentTime,
            detectionMethod: .combined
        )
        
        XCTAssertTrue(result.isAwake, "High confidence should detect wake")
        XCTAssertEqual(result.confidenceLevel, .high, "85% should be high confidence")
        XCTAssertGreaterThan(result.currentHeartRate, result.heartRateBaseline, "Current HR should be above baseline")
    }
    
    func testWakeDetection_LowConfidence_ShouldNotDetectWake() throws {
        let currentTime = Date()
        
        // Mock detection result with low confidence
        let result = WakeDetectionResult(
            isAwake: false,
            confidence: 45.0,
            heartRateBaseline: 55.0,
            currentHeartRate: 58.0,
            timestamp: currentTime,
            detectionMethod: .heartRate
        )
        
        XCTAssertFalse(result.isAwake, "Low confidence should not detect wake")
        XCTAssertEqual(result.confidenceLevel, .low, "45% should be low confidence")
    }
}

// MARK: - ESP32 Communication Tests

class ESP32CommunicationTests: XCTestCase {
    var communicationManager: ESP32CommunicationManager!
    
    override func setUpWithError() throws {
        communicationManager = ESP32CommunicationManager()
    }
    
    override func tearDownWithError() throws {
        communicationManager = nil
    }
    
    func testCoffeeCommand_Creation() throws {
        // Given: Coffee command parameters
        let coffeeType = CoffeeType.latte
        let triggerType = TriggerType.manual
        let sleepScore = 75.0
        let userId = "test_user_123"
        
        // When: Create command
        let command = CoffeeCommand(
            type: coffeeType,
            trigger: triggerType,
            sleepScore: sleepScore,
            userId: userId
        )
        
        // Then: Verify command properties
        XCTAssertEqual(command.command, "make_coffee")
        XCTAssertEqual(command.type, coffeeType.rawValue)
        XCTAssertEqual(command.trigger, triggerType.rawValue)
        XCTAssertEqual(command.sleepScore, sleepScore)
        XCTAssertEqual(command.userId, userId)
        XCTAssertFalse(command.requestId.isEmpty, "Request ID should not be empty")
        XCTAssertFalse(command.timestamp.isEmpty, "Timestamp should not be empty")
    }
    
    func testCoffeeResponse_StatusParsing() throws {
        // Test different response statuses
        let testCases: [(status: CoffeeCommandStatus, expectedSuccess: Bool, expectedProgress: Bool)] = [
            (.success, true, false),
            (.error, false, false),
            (.inProgress, false, true),
            (.cancelled, false, false)
        ]
        
        for testCase in testCases {
            let response = CoffeeResponse(
                status: testCase.status,
                message: "Test message",
                triggerType: "manual",
                estimatedCompletion: nil,
                errorCode: nil,
                timestamp: Date()
            )
            
            XCTAssertEqual(response.isSuccess, testCase.expectedSuccess,
                          "Status \(testCase.status) success should be \(testCase.expectedSuccess)")
            XCTAssertEqual(response.isInProgress, testCase.expectedProgress,
                          "Status \(testCase.status) progress should be \(testCase.expectedProgress)")
        }
    }
    
    // Note: Network tests would require mocking or test doubles
    // In a real implementation, you would test the network layer with MockURLSession
}

// MARK: - Data Model Tests

class DataModelTests: XCTestCase {
    
    func testCoffeeType_Properties() throws {
        // Test caffeine content
        XCTAssertEqual(CoffeeType.latte.caffeineContent, 63.0)
        XCTAssertEqual(CoffeeType.espressoLung.caffeineContent, 77.0)
        XCTAssertEqual(CoffeeType.espressoScurt.caffeineContent, 63.0)
        
        // Test display names
        XCTAssertEqual(CoffeeType.latte.displayName, "Latte")
        XCTAssertEqual(CoffeeType.espressoLung.displayName, "Espresso Lung")
        XCTAssertEqual(CoffeeType.espressoScurt.displayName, "Espresso Scurt")
        
        // Test emojis are not empty
        XCTAssertFalse(CoffeeType.latte.emoji.isEmpty)
        XCTAssertFalse(CoffeeType.espressoLung.emoji.isEmpty)
        XCTAssertFalse(CoffeeType.espressoScurt.emoji.isEmpty)
    }
    
    func testUserCoffeePreferences_CaffeineCalculations() throws {
        var preferences = UserCoffeePreferences()
        preferences.maxCaffeinePerDay = 400.0
        
        // Test limit checking
        XCTAssertTrue(preferences.hasExceededDailyCaffeineLimit(consumedToday: 450.0))
        XCTAssertFalse(preferences.hasExceededDailyCaffeineLimit(consumedToday: 350.0))
        
        // Test remaining caffeine calculation
        XCTAssertEqual(preferences.remainingCaffeineToday(consumedToday: 300.0), 100.0)
        XCTAssertEqual(preferences.remainingCaffeineToday(consumedToday: 450.0), 0.0)
    }
    
    func testFatigueLevel_Properties() throws {
        // Test recommended coffee strength
        XCTAssertEqual(FatigueLevel.low.recommendedCoffeeStrength, 0.3)
        XCTAssertEqual(FatigueLevel.moderate.recommendedCoffeeStrength, 0.6)
        XCTAssertEqual(FatigueLevel.high.recommendedCoffeeStrength, 0.8)
        XCTAssertEqual(FatigueLevel.severe.recommendedCoffeeStrength, 1.0)
        
        // Test display names are not empty
        for level in FatigueLevel.allCases {
            XCTAssertFalse(level.displayName.isEmpty, "Display name should not be empty for \(level)")
            XCTAssertFalse(level.color.isEmpty, "Color should not be empty for \(level)")
        }
    }
}

// MARK: - Integration Tests

class IntegrationTests: XCTestCase {
    
    func testCompleteWorkflow_SleepToRecommendation() throws {
        // Given: Complete sleep data
        let sleepData = SleepData(
            date: Date(),
            sleepDuration: 7.5 * 3600, // 7.5 hours
            sleepQuality: 78.0,
            averageHeartRate: 58.0,
            stepsYesterday: 9500,
            energyBurned: 2300.0,
            wakeUpDetected: Date().addingTimeInterval(-3600), // 1 hour ago
            wakeUpConfirmed: nil,
            deepSleepPercentage: 19.5,
            remSleepPercentage: 23.2
        )
        
        // When: Process through decision engine
        let decisionEngine = CoffeeDecisionEngine()
        let recommendation = decisionEngine.decideCoffeeType(sleepData: sleepData)
        
        // Then: Verify complete workflow
        XCTAssertNotNil(recommendation.type, "Should recommend a coffee type")
        XCTAssertGreaterThan(recommendation.strength, 0.0, "Should have positive strength")
        XCTAssertLessThanOrEqual(recommendation.strength, 1.0, "Should not exceed maximum strength")
        XCTAssertGreaterThan(recommendation.confidence, 0.0, "Should have positive confidence")
        XCTAssertFalse(recommendation.reasoning.isEmpty, "Should provide reasoning")
        
        // Verify sleep factors are included
        XCTAssertEqual(recommendation.sleepFactors.duration, 7.5, "Should include sleep duration")
        XCTAssertEqual(recommendation.sleepFactors.quality, 78.0, "Should include sleep quality")
    }
}

// MARK: - Mock Data Helpers

extension XCTestCase {
    func createMockSleepSession() -> SleepSession {
        let context = PersistenceController.preview.container.viewContext
        let session = SleepSession(context: context)
        
        session.date = Date()
        session.duration = 8.0 * 3600 // 8 hours
        session.quality = 75.0
        session.heartRate = 60.0
        session.steps = 8000
        session.energyBurned = 2000.0
        session.wakeUpTime = Date()
        session.deepSleepPercentage = 18.0
        session.remSleepPercentage = 22.0
        
        return session
    }
    
    func createMockCoffeeOrder(type: String = "latte") -> CoffeeOrder {
        let context = PersistenceController.preview.container.viewContext
        let order = CoffeeOrder(context: context)
        
        order.timestamp = Date()
        order.type = type
        order.trigger = "manual"
        order.success = true
        order.responseTime = 1.5
        order.wakeDetectionConfidence = 0.0
        order.userOverride = false
        order.countdownCancelled = false
        order.esp32ResponseCode = 200
        order.estimatedBrewTime = 90.0
        
        return order
    }
}
