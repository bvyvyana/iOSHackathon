import Foundation
import Combine

/// ViewModel pentru HomeView - gestionează logica de afișare și interacțiunile
@MainActor
class HomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefresh: Date?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotificationObservers()
    }
    
    // MARK: - Data Loading
    
    /// Încarcă datele inițiale la pornirea view-ului
    func loadInitialData() async throws {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Aici poți adăuga logică specifică de încărcare
            // De exemplu, verificare date locale, sincronizare, etc.
            
            try await Task.sleep(nanoseconds: 500_000_000) // Simulare
            
            lastRefresh = Date()
            
        } catch {
            errorMessage = "Eroare la încărcarea datelor: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Reîmprospătează toate datele
    func refreshData() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Trigger refresh pentru HealthKit și ESP32
            // Această logică va fi implementată în managerii respectivi
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulare
            
            lastRefresh = Date()
            
        } catch {
            errorMessage = "Eroare la actualizarea datelor: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Observer pentru detectarea trezirii
        NotificationCenter.default.publisher(for: .wakeDetected)
            .sink { [weak self] notification in
                if let wakeResult = notification.object as? WakeDetectionResult {
                    self?.handleWakeDetection(wakeResult)
                }
            }
            .store(in: &cancellables)
        
        // Observer pentru schimbări în conexiunea ESP32
        NotificationCenter.default.publisher(for: .esp32ConnectionChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.handleConnectionChange()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleWakeDetection(_ result: WakeDetectionResult) {
        print("Wake detected with confidence: \(result.confidence)%")
        
        // Aici poți adăuga logică pentru auto-comandă cafea
        if result.confidence > 80.0 {
            Task {
                await handleAutoOrderCoffee()
            }
        }
    }
    
    private func handleConnectionChange() async {
        // Reacție la schimbarea conexiunii ESP32
        do {
            try await refreshData()
        } catch {
            errorMessage = "Eroare la actualizarea datelor: \(error.localizedDescription)"
        }
    }
    
    private func handleAutoOrderCoffee() async {
        // Logică pentru comanda automată de cafea
        print("Triggering automatic coffee order...")
    }
}

/// ViewModel pentru recomandarea de cafea
@MainActor
class CoffeeRecommendationViewModel: ObservableObject {
    @Published var currentRecommendation: CoffeeRecommendation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let decisionEngine = CoffeeDecisionEngine()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Recommendation Logic
    
    /// Actualizează recomandarea pe baza datelor de somn
    func updateRecommendation(for sleepData: SleepData) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Simulare procesare
                try await Task.sleep(nanoseconds: 500_000_000)
                
                let recommendation = decisionEngine.decideCoffeeType(
                    sleepData: sleepData,
                    timeOfDay: Date(),
                    consumedCaffeineToday: 0 // TODO: Get from actual data
                )
                
                currentRecommendation = recommendation
                
            } catch {
                errorMessage = "Eroare la calcularea recomandării: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    /// Actualizează recomandarea cu preferințe utilizator
    func updateRecommendationWithPreferences(_ preferences: UserCoffeePreferences) {
        // TODO: Implementează actualizarea cu preferințe
    }
    
    /// Obține recomandarea pentru un moment specific din zi
    func getRecommendationForTime(_ time: Date) async -> CoffeeRecommendation? {
        // TODO: Implementează recomandarea pentru ore specifice
        return nil
    }
}

// MARK: - Supporting Extensions

extension Notification.Name {
    static let esp32ConnectionChanged = Notification.Name("esp32ConnectionChanged")
    static let coffeeOrderCompleted = Notification.Name("coffeeOrderCompleted")
    static let userPreferencesChanged = Notification.Name("userPreferencesChanged")
}
