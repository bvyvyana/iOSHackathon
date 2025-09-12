import SwiftUI
import PlaygroundSupport

// Mock Data pentru Preview
struct MockSleepData {
    static let good = SleepData(
        date: Date(),
        sleepDuration: 8.0 * 3600,
        sleepQuality: 85.0,
        averageHeartRate: 55.0,
        stepsYesterday: 9500,
        energyBurned: 2300.0,
        wakeUpDetected: Date(),
        wakeUpConfirmed: nil,
        deepSleepPercentage: 18.5,
        remSleepPercentage: 22.3
    )
}

// Mini HomeView pentru Preview
struct MiniHomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Connection Status
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("ESP32 Conectat")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Răspuns: 1.2s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    // Sleep Summary
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("💤 Rezumatul Somnului")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("Odihnit")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                        
                        HStack(spacing: 20) {
                            VStack {
                                Image(systemName: "clock.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("8h 30m")
                                    .font(.headline)
                                Text("Durata")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Image(systemName: "star.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("85%")
                                    .font(.headline)
                                Text("Calitate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("55 BPM")
                                    .font(.headline)
                                Text("Ritm Cardiac")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    // Coffee Recommendation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("☕ Recomandare")
                            .font(.headline)
                        
                        HStack {
                            Text("🥛")
                                .font(.title)
                            
                            VStack(alignment: .leading) {
                                Text("Latte")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Intensitate Blândă")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Încredere")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("87%")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text("✅ Durată optimă • ⭐ Calitate excelentă • 🕊️ Intensitate blândă")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                Text("Comandă Cafea")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Acțiuni Rapide")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(["🥛 Latte", "☕️ Espresso", "⚡️ Shot"], id: \.self) { coffee in
                                Button(action: {}) {
                                    VStack(spacing: 8) {
                                        Text(String(coffee.prefix(2)))
                                            .font(.title)
                                        Text(String(coffee.dropFirst(3)))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(.brown.opacity(0.1))
                                    .foregroundColor(.brown)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("☕ Smart Coffee")
        }
    }
}

// Set up the playground live view
PlaygroundPage.current.setLiveView(MiniHomeView())
