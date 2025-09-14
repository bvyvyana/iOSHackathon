import SwiftUI

/// Demo pentru detectarea automată a statusului de treaz/dormit
struct AutoStatusDetectionDemo: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var lastStatusChange: AwakeStatusChange?
    // Detectarea este permanent activă
    
    var body: some View {
        VStack(spacing: 30) {
            Text("🔄 Auto Status Detection Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            // Current Status
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: healthKitManager.currentAwakeStatus.icon)
                        .font(.title)
                        .foregroundColor(healthKitManager.currentAwakeStatus.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status Actual")
                            .font(.headline)
                        
                        Text(healthKitManager.currentAwakeStatus.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(healthKitManager.currentAwakeStatus.color)
                    }
                    
                    Spacer()
                    
                    Text(healthKitManager.currentAwakeStatus.emoji)
                        .font(.title)
                }
                
                Text(healthKitManager.currentAwakeStatus.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // Auto Detection Status
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Detectare Automată")
                            .font(.headline)
                        
                        Text("Monitorizare continuă cu HealthKit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Verifică la fiecare 1 minut")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(.green.opacity(0.1))
            .cornerRadius(12)
            
            // Last Status Change
            if let lastChange = lastStatusChange {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ultima Schimbare Detectată")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("De la:")
                            Spacer()
                            Text(lastChange.oldStatus.displayName)
                                .fontWeight(.medium)
                                .foregroundColor(lastChange.oldStatus.color)
                        }
                        
                        HStack {
                            Text("La:")
                            Spacer()
                            Text(lastChange.newStatus.displayName)
                                .fontWeight(.medium)
                                .foregroundColor(lastChange.newStatus.color)
                        }
                        
                        HStack {
                            Text("Încredere:")
                            Spacer()
                            Text("\(Int(lastChange.confidence))%")
                                .fontWeight(.medium)
                                .foregroundColor(lastChange.confidence > 80 ? .green : .orange)
                        }
                        
                        HStack {
                            Text("Metodă:")
                            Spacer()
                            Text(lastChange.detectionMethod.rawValue)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Ora:")
                            Spacer()
                            Text(formatTime(lastChange.timestamp))
                                .fontWeight(.medium)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Features List
            VStack(alignment: .leading, spacing: 12) {
                Text("Funcționalități implementate:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "checkmark.circle.fill", text: "Monitorizare automată cu HealthKit")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Detectare bazată pe ritm cardiac și mișcare")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Verificări la fiecare 1 minut")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Actualizare automată a statusului")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Sincronizare cu SettingsViewModel")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Notificări pentru schimbări de încredere înaltă")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Persistență automată în UserDefaults")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Detectare permanent activă - fără toggle")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Nu poți dezactiva monitorizarea")
                }
            }
            .padding()
            .background(.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Detectarea este permanent activă - nu trebuie să o activezi manual
        }
        .onReceive(NotificationCenter.default.publisher(for: .awakeStatusChanged)) { notification in
            if let statusChange = notification.object as? AwakeStatusChange {
                lastStatusChange = statusChange
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.caption)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

#Preview {
    AutoStatusDetectionDemo()
}
