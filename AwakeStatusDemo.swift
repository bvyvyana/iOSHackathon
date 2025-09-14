import SwiftUI

/// Demo pentru funcționalitatea de status treaz/dormit
struct AwakeStatusDemo: View {
    @State private var currentStatus: AwakeStatus = .awake
    
    var body: some View {
        VStack(spacing: 30) {
            Text("☕ Smart Coffee - Status Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            // Status Card Demo
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: currentStatus.icon)
                        .font(.title)
                        .foregroundColor(currentStatus.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status Personal")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(currentStatus.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(currentStatus.color)
                    }
                    
                    Spacer()
                    
                    Text(currentStatus.emoji)
                        .font(.title)
                }
                
                Text(currentStatus.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                
                // Animated indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentStatus.color)
                        .frame(width: 12, height: 12)
                        .scaleEffect(currentStatus == .awake ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: currentStatus)
                    
                    Text(currentStatus == .awake ? "Activ și gata de cafea" : "În repaus, detectez trezirea")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            // Status Picker
            Picker("Status", selection: $currentStatus) {
                ForEach(AwakeStatus.allCases, id: \.self) { status in
                    HStack {
                        Image(systemName: status.icon)
                        Text(status.displayName)
                        Text(status.emoji)
                    }
                    .tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Features List
            VStack(alignment: .leading, spacing: 12) {
                Text("Funcționalități implementate:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "checkmark.circle.fill", text: "Model AwakeStatus cu emoji și iconițe")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Persistență în UserDefaults")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Card frumos în HomeView cu animație")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Secțiune în SettingsView cu picker")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Sincronizare automată între view-uri")
                }
            }
            .padding()
            .background(.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
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
    AwakeStatusDemo()
}
