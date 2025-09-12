import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Header cu status conexiune
                    ConnectionStatusView()
                    
                    // Sleep Summary Card
                    if let sleepData = healthKitManager.currentSleepData {
                        SleepSummaryCard(sleepData: sleepData)
                    } else {
                        SleepDataPlaceholder()
                    }
                    
                    // Coffee Recommendation
                    CoffeeRecommendationCard()
                    
                    // Quick Actions
                    QuickActionsView()
                    
                    // Recent Activity
                    RecentActivityView()
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("☕ Smart Coffee")
            .refreshable {
                do {
                    try await viewModel.refreshData()
                } catch {
                    print("Error refreshing data: \(error)")
                }
            }
        }
        .task {
            do {
                try await viewModel.loadInitialData()
            } catch {
                print("Error loading initial data: \(error)")
            }
        }
    }
}

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    
    var body: some View {
        HStack {
            Image(systemName: esp32Manager.isConnected ? "wifi" : "wifi.slash")
                .foregroundColor(esp32Manager.isConnected ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(esp32Manager.isConnected ? "ESP32 Conectat" : "ESP32 Offline")
                    .font(.headline)
                    .foregroundColor(esp32Manager.isConnected ? .green : .red)
                
                if let error = esp32Manager.connectionError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if esp32Manager.isConnected {
                    Text("Răspuns: \(String(format: "%.1f", esp32Manager.lastResponseTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if esp32Manager.discoveryInProgress {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !esp32Manager.isConnected {
                Button("Conectare") {
                    Task {
                        try? await esp32Manager.discoverESP32()
                    }
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sleep Summary Card

struct SleepSummaryCard: View {
    let sleepData: SleepData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("💤 Rezumatul Somnului")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(sleepData.fatigueLevel.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(sleepData.fatigueLevel.color).opacity(0.2))
                    .foregroundColor(Color(sleepData.fatigueLevel.color))
                    .cornerRadius(8)
            }
            
            HStack(spacing: 20) {
                SleepMetricView(
                    title: "Durata",
                    value: formatSleepDuration(sleepData.sleepDuration),
                    icon: "clock.fill"
                )
                
                SleepMetricView(
                    title: "Calitate",
                    value: "\(Int(sleepData.computedQuality))%",
                    icon: "star.fill"
                )
                
                SleepMetricView(
                    title: "Ritm Cardiac",
                    value: "\(Int(sleepData.averageHeartRate)) BPM",
                    icon: "heart.fill"
                )
            }
            
            // Sleep stages visualization
            SleepStagesView(
                deepPercent: sleepData.deepSleepPercentage,
                remPercent: sleepData.remSleepPercentage
            )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatSleepDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}

struct SleepMetricView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SleepStagesView: View {
    let deepPercent: Double
    let remPercent: Double
    
    private var lightPercent: Double {
        return max(0, 100 - deepPercent - remPercent)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fazele Somnului")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Progress bar pentru faze
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: geometry.size.width * deepPercent / 100)
                    
                    Rectangle()
                        .fill(.purple)
                        .frame(width: geometry.size.width * remPercent / 100)
                    
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: geometry.size.width * lightPercent / 100)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
            
            HStack(spacing: 16) {
                LegendItem(color: .blue, label: "Profund", value: "\(Int(deepPercent))%")
                LegendItem(color: .purple, label: "REM", value: "\(Int(remPercent))%")
                LegendItem(color: .gray, label: "Ușor", value: "\(Int(lightPercent))%")
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Coffee Recommendation Card

struct CoffeeRecommendationCard: View {
    @StateObject private var viewModel = CoffeeRecommendationViewModel()
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("☕ Recomandare")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let recommendation = viewModel.currentRecommendation {
                CoffeeRecommendationContent(recommendation: recommendation)
            } else {
                Text("Analizez datele de somn...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onReceive(healthKitManager.$currentSleepData) { sleepData in
            if let sleepData = sleepData {
                viewModel.updateRecommendation(for: sleepData)
            }
        }
    }
}

struct CoffeeRecommendationContent: View {
    let recommendation: CoffeeRecommendation
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    @State private var showingConfirmation = false
    @State private var isOrdering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tipul de cafea recomandat
            HStack {
                Text(recommendation.type.emoji)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.type.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(recommendation.strengthDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Încredere")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(recommendation.confidence * 100))%")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            // Reasoning
            Text(recommendation.reasoning)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.gray.opacity(0.1))
                .cornerRadius(8)
            
            // Action Button
            Button(action: {
                if esp32Manager.isConnected {
                    showingConfirmation = true
                } else {
                    Task {
                        try? await esp32Manager.discoverESP32()
                    }
                }
            }) {
                HStack {
                    if isOrdering {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: esp32Manager.isConnected ? "cup.and.saucer.fill" : "wifi.slash")
                    }
                    
                    Text(esp32Manager.isConnected ? "Comandă Cafea" : "Conectare ESP32")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(esp32Manager.isConnected ? .blue : .orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isOrdering)
        }
        .confirmationDialog("Comandă Cafea", isPresented: $showingConfirmation) {
            Button("Comandă \(recommendation.type.displayName)") {
                orderCoffee()
            }
            Button("Anulare", role: .cancel) { }
        } message: {
            Text("Vrei să comanzi \(recommendation.type.displayName)?")
        }
    }
    
    private func orderCoffee() {
        guard !isOrdering else { return }
        
        isOrdering = true
        
        Task {
            do {
                let response = try await esp32Manager.makeCoffee(
                    type: recommendation.type,
                    trigger: .manual
                )
                
                if response.isSuccess {
                    // Show success feedback
                } else {
                    // Show error
                }
            } catch {
                // Handle error
                print("Coffee order error: \(error)")
            }
            
            isOrdering = false
        }
    }
}

// MARK: - Placeholder Views

struct SleepDataPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Date de somn indisponibile")
                        .font(.headline)
                    
                    Text("Activează accesul la HealthKit pentru analiza somnului")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button("Activează HealthKit") {
                Task {
                    // Request HealthKit permissions
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acțiuni Rapide")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Latte",
                    icon: "🥛",
                    color: .brown
                ) {
                    await orderQuickCoffee(.latte)
                }
                
                QuickActionButton(
                    title: "Espresso",
                    icon: "☕️",
                    color: .orange
                ) {
                    await orderQuickCoffee(.espressoLung)
                }
                
                QuickActionButton(
                    title: "Shot",
                    icon: "⚡️",
                    color: .red
                ) {
                    await orderQuickCoffee(.espressoScurt)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func orderQuickCoffee(_ type: CoffeeType) async {
        guard esp32Manager.isConnected else { return }
        
        do {
            _ = try await esp32Manager.makeCoffee(type: type, trigger: .manual)
        } catch {
            print("Quick coffee order error: \(error)")
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () async -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            isLoading = true
            
            Task {
                await action()
                isLoading = false
            }
        }) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(icon)
                        .font(.title)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// MARK: - Recent Activity

struct RecentActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activitate Recentă")
                .font(.headline)
            
            VStack(spacing: 8) {
                RecentActivityItem(
                    icon: "cup.and.saucer.fill",
                    title: "Latte comandat",
                    time: "acum 2 ore",
                    status: .success
                )
                
                RecentActivityItem(
                    icon: "moon.zzz.fill",
                    title: "Trezire detectată",
                    time: "acum 3 ore",
                    status: .info
                )
                
                RecentActivityItem(
                    icon: "wifi",
                    title: "ESP32 conectat",
                    time: "acum 5 ore",
                    status: .success
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RecentActivityItem: View {
    let icon: String
    let title: String
    let time: String
    let status: ActivityStatus
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

enum ActivityStatus {
    case success, error, info, warning
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HealthKitManager())
        .environmentObject(ESP32CommunicationManager())
}
