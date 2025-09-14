import SwiftUI
import Combine

/// Statusul comenzii automate de cafea
enum AutoCoffeeStatus {
    case none
    case scheduled(AutoCoffeeScheduled)
    case executing
    case completed(AutoCoffeeResult)
    case failed(AutoCoffeeResult)
}

struct HomeView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var autoCoffeeStatus: AutoCoffeeStatus = .none
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Header cu status conexiune
                    ConnectionStatusView()
                    
                    // Awake Status Card
                    AwakeStatusCard()
                    
                    // Auto Coffee Status Card
                    if case .none = autoCoffeeStatus {
                        EmptyView()
                    } else {
                        AutoCoffeeStatusCard(status: autoCoffeeStatus)
                    }
                    
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
        .onReceive(NotificationCenter.default.publisher(for: .autoCoffeeScheduled)) { notification in
            if let scheduled = notification.object as? AutoCoffeeScheduled {
                autoCoffeeStatus = .scheduled(scheduled)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .executeAutoCoffee)) { _ in
            autoCoffeeStatus = .executing
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoCoffeeCompleted)) { notification in
            if let result = notification.object as? AutoCoffeeResult {
                autoCoffeeStatus = result.success ? .completed(result) : .failed(result)
                
                // Resetează statusul după 5 secunde
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    autoCoffeeStatus = .none
                }
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
                .foregroundColor(esp32Manager.isConnected ? Color.primaryGreen : Color.primaryRed)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(esp32Manager.isConnected ? "ESP32 Conectat" : "ESP32 Offline")
                    .font(.headline)
                    .foregroundColor(esp32Manager.isConnected ? Color.primaryGreen : Color.primaryRed)
                
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
                .foregroundColor(Color.primaryBlue)
            
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
                        .fill(Color.primaryBlue)
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
                LegendItem(color: Color.primaryBlue, label: "Profund", value: "\(Int(deepPercent))%")
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
                        .foregroundColor(Color.primaryGreen)
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
                .background(esp32Manager.isConnected ? Color.primaryBlue : Color.primaryOrange)
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
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.title)
                    .foregroundColor(Color.primaryBlue)
                
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
                    do {
                        let granted = try await healthKitManager.requestPermissions()
                        if granted {
                            // După autorizare, analizează datele de somn
                            try await healthKitManager.analyzeTodaysSleep()
                        }
                    } catch {
                        print("HealthKit error: \(error)")
                    }
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
                    color: .coffeeBrown
                ) {
                    await orderQuickCoffee(.latte)
                }
                
                QuickActionButton(
                    title: "Espresso",
                    icon: "☕️",
                    color: Color.primaryOrange
                ) {
                    await orderQuickCoffee(.espressoLung)
                }
                
                QuickActionButton(
                    title: "Shot",
                    icon: "⚡️",
                    color: Color.primaryRed
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
        case .success: return Color.primaryGreen
        case .error: return Color.primaryRed
        case .info: return Color.primaryBlue
        case .warning: return Color.primaryOrange
        }
    }
}

// MARK: - Awake Status Card

struct AwakeStatusCard: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: healthKitManager.currentAwakeStatus.icon)
                    .font(.title)
                    .foregroundColor(healthKitManager.currentAwakeStatus.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status Personal")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
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
                .padding(.horizontal, 8) 
            
            // Status indicator with animation
            HStack(spacing: 8) {
                Circle()
                    .fill(healthKitManager.currentAwakeStatus.color)
                    .frame(width: 12, height: 12)
                    .scaleEffect(healthKitManager.currentAwakeStatus == .awake ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: healthKitManager.currentAwakeStatus)
                
                Text(healthKitManager.currentAwakeStatus == .awake ? "Activ și gata de cafea" : "În repaus, detectez trezirea")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Auto Coffee Status Card

struct AutoCoffeeStatusCard: View {
    let status: AutoCoffeeStatus
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if case .scheduled(let scheduled) = status {
                    Text("\(Int(scheduled.timeRemaining))s")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(iconColor)
                } else if case .executing = status {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if case .scheduled(let scheduled) = status {
                // Progress bar pentru countdown
                ProgressView(value: 1.0 - (scheduled.timeRemaining / scheduled.delay))
                    .progressViewStyle(LinearProgressViewStyle(tint: iconColor))
                    .scaleEffect(y: 2.0)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch status {
        case .none:
            return "questionmark.circle"
        case .scheduled:
            return "clock.fill"
        case .executing:
            return "cup.and.saucer.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .none:
            return .gray
        case .scheduled:
            return .orange
        case .executing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var title: String {
        switch status {
        case .none:
            return "Status Necunoscut"
        case .scheduled(let scheduled):
            return "Cafea Programată"
        case .executing:
            return "Se Pregătește Cafea"
        case .completed(let result):
            return "Cafea Gata!"
        case .failed(let result):
            return "Eroare Comandă"
        }
    }
    
    private var subtitle: String {
        switch status {
        case .none:
            return ""
        case .scheduled(let scheduled):
            return "\(scheduled.recommendation.type.displayName) în \(Int(scheduled.timeRemaining)) secunde"
        case .executing:
            return "Se trimite comanda către ESP32..."
        case .completed(let result):
            return result.message
        case .failed(let result):
            return result.message
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HealthKitManager())
        .environmentObject(ESP32CommunicationManager())
}
