import Foundation
import SwiftUI

/// Demo pentru testarea funcționalității de comandă automată de cafea
struct AutoCoffeeDemo: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var esp32Manager = ESP32CommunicationManager()
    @State private var isSimulating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("☕ Auto Coffee Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Simulează tranziția din dormit în treaz pentru a testa comanda automată de cafea")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Status curent
                HStack {
                    Text("Status curent:")
                        .font(.headline)
                    Spacer()
                    Text(healthKitManager.currentAwakeStatus.displayName)
                        .font(.headline)
                        .foregroundColor(healthKitManager.currentAwakeStatus.color)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Butoane de simulare
                VStack(spacing: 12) {
                    Button("🌅 Simulează Trezirea") {
                        simulateWakeUp()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSimulating)
                    
                    Button("😴 Simulează Adormirea") {
                        simulateSleep()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSimulating)
                    
                    Button("🔄 Resetează Status") {
                        resetStatus()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSimulating)
                }
                
                // Informații despre proces
                if isSimulating {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Se simulează tranziția...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            
            Spacer()
            
            // Instrucțiuni
            VStack(alignment: .leading, spacing: 8) {
                Text("Instrucțiuni:")
                    .font(.headline)
                
                Text("1. Apasă 'Simulează Trezirea' pentru a simula tranziția din dormit în treaz")
                Text("2. Aplicația va actualiza automat datele HealthKit")
                Text("3. După 2 minute, va fi trimisă comanda automată de cafea")
                Text("4. Verifică în HomeView pentru a vedea statusul comenzii")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .environmentObject(healthKitManager)
        .environmentObject(esp32Manager)
    }
    
    private func simulateWakeUp() {
        isSimulating = true
        
        // Simulează tranziția din dormit în treaz
        let statusChange = AwakeStatusChange(
            oldStatus: .sleeping,
            newStatus: .awake,
            confidence: 85.0,
            timestamp: Date(),
            detectionMethod: .combined,
            source: .automatic
        )
        
        // Trimite notificarea pentru schimbarea statusului
        NotificationCenter.default.post(
            name: .awakeStatusChanged,
            object: statusChange
        )
        
        // Resetează flag-ul după 2 secunde
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSimulating = false
        }
    }
    
    private func simulateSleep() {
        isSimulating = true
        
        // Simulează tranziția în dormit
        let statusChange = AwakeStatusChange(
            oldStatus: .awake,
            newStatus: .sleeping,
            confidence: 90.0,
            timestamp: Date(),
            detectionMethod: .combined,
            source: .automatic
        )
        
        // Trimite notificarea pentru schimbarea statusului
        NotificationCenter.default.post(
            name: .awakeStatusChanged,
            object: statusChange
        )
        
        // Resetează flag-ul după 2 secunde
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSimulating = false
        }
    }
    
    private func resetStatus() {
        healthKitManager.setManualAwakeStatus(.awake)
    }
}

#Preview {
    AutoCoffeeDemo()
}
