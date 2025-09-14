import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationView {
            Form {
                // Awake Status Section
                Section("Status Personal") {
                    AwakeStatusSection(status: $viewModel.awakeStatus)
                }
                
                // ESP32 Connection Section
                Section("Conexiune ESP32") {
                    ESP32ConnectionAdvancedSection(
                        settings: $viewModel.esp32Settings,
                        validationErrors: viewModel.validationErrors,
                        testInProgress: viewModel.connectionTestInProgress,
                        testResult: viewModel.connectionTestResult,
                        onTestConnection: {
                            Task {
                                await viewModel.testESP32Connection()
                            }
                        },
                        onReset: {
                            viewModel.resetESP32Settings()
                        }
                    )
                }
                
                // HealthKit Section
                Section("HealthKit") {
                    HealthKitSection()
                }
                
                // Notifications Section
                Section("Notificări") {
                    NotificationSettingsView(settings: $viewModel.notificationSettings)
                }
                
                // About & Support Section
                Section("Aplicația") {
                    AboutSection()
                }
                
                // Advanced Settings
                Section("Setări Avansate") {
                    AdvancedSettingsSection()
                }
            }
            .navigationTitle("⚙️ Setări")
            .refreshable {
                await viewModel.refreshSettings()
            }
        }
        .task {
            await viewModel.loadSettings()
        }
        .onAppear {
            // Configurează sincronizarea cu HealthKitManager
            viewModel.setupHealthKitManagerSync(healthKitManager)
        }
    }
}



// MARK: - ESP32 Connection Section

struct ESP32ConnectionSection: View {
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    @State private var showingManualIP = false
    @State private var manualIP = ""
    
    var body: some View {
        Group {
            // Connection Status
            HStack {
                Text("Status Conexiune")
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(esp32Manager.isConnected ? Color.primaryGreen : Color.primaryRed)
                        .frame(width: 10, height: 10)
                    
                    Text(esp32Manager.isConnected ? "Conectat" : "Deconectat")
                        .foregroundColor(esp32Manager.isConnected ? Color.primaryGreen : Color.primaryRed)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            if esp32Manager.isConnected {
                // Connection Details
                HStack {
                    Text("Timp Răspuns")
                    Spacer()
                    Text("\(String(format: "%.2f", esp32Manager.lastResponseTime))s")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Răspuns Mediu")
                    Spacer()
                    Text("\(String(format: "%.2f", esp32Manager.averageResponseTime))s")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Status Conexiune")
                    Spacer()
                    Text(esp32Manager.isConnected ? "Conectat" : "Deconectat")
                        .foregroundColor(esp32Manager.isConnected ? Color.primaryGreen : Color.primaryRed)
                }
                
                if esp32Manager.isConnected {
                    HStack {
                        Text("Semnal WiFi")
                        Spacer()
                        Text("-45 dBm (Bun)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Connection Actions
            Group {
                if esp32Manager.discoveryInProgress {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Căutare ESP32...")
                    }
                } else {
                    Button("Caută ESP32 Automat") {
                        Task {
                            try? await esp32Manager.discoverESP32()
                        }
                    }
                    .disabled(esp32Manager.isConnected)
                }
                
                Button("Configurare Manuală IP") {
                    showingManualIP = true
                }
                
            }
        }
        .sheet(isPresented: $showingManualIP) {
            ManualIPConfigurationView(ipAddress: $manualIP)
        }
    }
    
    private func formatUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - HealthKit Section

struct HealthKitSection: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        Group {
            // Authorization Status
            HStack {
                Text("Status Autorizare")
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(healthKitManager.isAuthorized ? Color.primaryGreen : Color.primaryRed)
                        .frame(width: 10, height: 10)
                    
                    Text(healthKitManager.isAuthorized ? "Autorizat" : "Neautorizat")
                        .foregroundColor(healthKitManager.isAuthorized ? Color.primaryGreen : Color.primaryRed)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            if !healthKitManager.isAuthorized {
                Button("Activează Accesul HealthKit") {
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
            
            // Wake Detection Status
            HStack {
                Text("Monitorizare Trezire")
                Spacer()
                
                Text(healthKitManager.isMonitoringWake ? "Activă" : "Inactivă")
                    .foregroundColor(healthKitManager.isMonitoringWake ? Color.primaryGreen : .secondary)
            }
            
            if healthKitManager.isAuthorized {
                // Sincronizare manuală date
                Button("Sincronizează Datele") {
                    Task {
                        do {
                            try await healthKitManager.analyzeTodaysSleep()
                        } catch {
                            print("Sync error: \(error)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                
                // Monitorizare trezire
                if healthKitManager.isMonitoringWake {
                    Button("Oprește Monitorizarea") {
                        healthKitManager.stopWakeDetection()
                    }
                    .foregroundColor(Color.primaryRed)
                } else {
                    Button("Pornește Monitorizarea") {
                        healthKitManager.startWakeDetection()
                    }
                    .foregroundColor(Color.primaryGreen)
                }
            }
            
            // Data Privacy Info
            NavigationLink("Informații Confidențialitate") {
                HealthDataPrivacyView()
            }
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @Binding var settings: NotificationSettings
    
    var body: some View {
        Group {
            Toggle("Notificări Push", isOn: $settings.pushNotificationsEnabled)
            
            if settings.pushNotificationsEnabled {
                Toggle("Confirmări Comenzi", isOn: $settings.coffeeConfirmationEnabled)
                Toggle("Alerte Conectivitate", isOn: $settings.connectivityAlertsEnabled)
                Toggle("Rezumate Zilnice", isOn: $settings.dailySummaryEnabled)
                Toggle("Alerte Cafeină", isOn: $settings.caffeineAlertsEnabled)
            }
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    var body: some View {
        Group {
            HStack {
                Text("Versiune App")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            NavigationLink("Ghid de Utilizare") {
                UserGuideView()
            }
            
            NavigationLink("Întrebări Frecvente") {
                FAQView()
            }
            
            NavigationLink("Contact Support") {
                SupportView()
            }
            
            NavigationLink("Termeni și Condiții") {
                TermsView()
            }
            
            NavigationLink("Politica de Confidențialitate") {
                PrivacyPolicyView()
            }
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsSection: View {
    @State private var showingResetAlert = false
    @State private var showingDiagnostics = false
    @State private var showingCleanupAlert = false
    @State private var cleanupInProgress = false
    @State private var cleanupResult: String?
    
    var body: some View {
        Group {
            Button("Diagnostice Sistem") {
                showingDiagnostics = true
            }
            
            NavigationLink("Exportare Date") {
                DataExportView()
            }
            
            NavigationLink("Istoric Comenzi") {
                CommandHistoryView()
            }
            
            Button(action: {
                showingCleanupAlert = true
            }) {
                HStack {
                    if cleanupInProgress {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Curățare în curs...")
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "trash.circle")
                        Text("Curățare Date Vechi")
                    }
                }
            }
            .disabled(cleanupInProgress)
            .foregroundColor(Color.primaryOrange)
            
            if let result = cleanupResult {
                Text(result)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Resetare Setări") {
                showingResetAlert = true
            }
                                .foregroundColor(Color.primaryRed)
            
            Button("Resetare Date") {
                // Reset all data
            }
                                .foregroundColor(Color.primaryRed)
        }
        .alert("Curățare Date Vechi", isPresented: $showingCleanupAlert) {
            Button("Anulare", role: .cancel) { }
            Button("Curățare", role: .destructive) {
                performCleanup()
            }
        } message: {
            Text("Această acțiune va șterge:\n• Date performance ESP32 > 30 zile\n• Comenzi de cafea > 6 luni\n\nAceastă acțiune nu poate fi anulată.")
        }
        .alert("Resetare Setări", isPresented: $showingResetAlert) {
            Button("Anulare", role: .cancel) { }
            Button("Resetare", role: .destructive) {
                // Perform reset
            }
        } message: {
            Text("Această acțiune va reseta toate setările la valorile implicite. Această acțiune nu poate fi anulată.")
        }
        .sheet(isPresented: $showingDiagnostics) {
            SystemDiagnosticsView()
        }
    }
    
    private func performCleanup() {
        cleanupInProgress = true
        cleanupResult = nil
        
        Task {
            let result = await PersistenceController.shared.performManualCleanup()
            
            await MainActor.run {
                cleanupInProgress = false
                cleanupResult = "Șterse: \(result.performanceRecords) înregistrări performance, \(result.coffeeOrders) comenzi cafea"
                
                // Clear result after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    cleanupResult = nil
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ManualIPConfigurationView: View {
    @Binding var ipAddress: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Adresă IP ESP32") {
                    TextField("192.168.81.60", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                    
                    Text("Introduceți adresa IP a controllerului ESP32 din rețeaua locală")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("IP Manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anulare") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conectare") {
                        // Connect to manual IP
                        dismiss()
                    }
                    .disabled(ipAddress.isEmpty)
                }
            }
        }
    }
}

// MARK: - Placeholder Detail Views

struct HealthDataPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Confidențialitatea Datelor de Sănătate")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Smart Coffee folosește datele din HealthKit doar pentru a determina calitatea somnului și a recomanda cafeaua potrivită.")
                
                Text("Datele procesate:")
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Durata și calitatea somnului")
                    Text("• Ritmul cardiac în timpul somnului")
                    Text("• Fazele de somn (profund, REM)")
                    Text("• Momentul trezirii")
                }
                
                Text("Toate datele rămân pe dispozitivul tău și nu sunt transmise către servere externe.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Confidențialitate")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SystemDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Sistem") {
                    DiagnosticRow(title: "Versiune iOS", value: UIDevice.current.systemVersion)
                    DiagnosticRow(title: "Model Device", value: UIDevice.current.model)
                    DiagnosticRow(title: "Memorie Disponibilă", value: "Calculez...")
                }
                
                Section("HealthKit") {
                    DiagnosticRow(title: "Status Autorizare", value: "Autorizat")
                    DiagnosticRow(title: "Ultima Sincronizare", value: "acum 2 minute")
                }
                
                Section("ESP32") {
                    DiagnosticRow(title: "Status Conexiune", value: "Conectat")
                    DiagnosticRow(title: "Timp Răspuns", value: "1.2s")
                    DiagnosticRow(title: "Ultima Comandă", value: "acum 1 oră")
                }
            }
            .navigationTitle("Diagnostice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Închide") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DiagnosticRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// Placeholder views pentru alte secțiuni
struct UserGuideView: View {
    var body: some View {
        Text("Ghid de Utilizare")
            .navigationTitle("Ghid")
    }
}

struct FAQView: View {
    var body: some View {
        Text("Întrebări Frecvente")
            .navigationTitle("FAQ")
    }
}

struct SupportView: View {
    var body: some View {
        Text("Contact Support")
            .navigationTitle("Support")
    }
}

struct TermsView: View {
    var body: some View {
        Text("Termeni și Condiții")
            .navigationTitle("Termeni")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        Text("Politica de Confidențialitate")
            .navigationTitle("Confidențialitate")
    }
}

struct DataExportView: View {
    var body: some View {
        Text("Exportare Date")
            .navigationTitle("Export")
    }
}

struct CommandHistoryView: View {
    var body: some View {
        Text("Istoric Comenzi")
            .navigationTitle("Istoric")
    }
}

// MARK: - ESP32 Advanced Connection Section

struct ESP32ConnectionAdvancedSection: View {
    @Binding var settings: ESP32ConnectionSettings
    let validationErrors: [String]
    let testInProgress: Bool
    let testResult: ConnectionTestResult?
    let onTestConnection: () -> Void
    let onReset: () -> Void
    
    @State private var showingAdvancedSettings = false
    @State private var showingResetAlert = false
    @State private var tempURL = ""
    @State private var tempPort = "80"
    
    var body: some View {
        Group {
            // URL Configuration
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Adresă ESP32")
                        .fontWeight(.medium)
                    Spacer()
                    if !validationErrors.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.primaryOrange)
                            .font(.caption)
                    }
                }
                
                TextField("http://192.168.81.60", text: $tempURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .onAppear {
                        tempURL = settings.baseURL
                    }
                    .onChange(of: tempURL) { newValue in
                        settings.baseURL = newValue
                    }
                
                if !validationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(validationErrors, id: \.self) { error in
                            Text("• \(error)")
                                .font(.caption)
                                .foregroundColor(Color.primaryRed)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            // Port Configuration
            HStack {
                Text("Port")
                Spacer()
                TextField("80", text: $tempPort)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                    .onAppear {
                        tempPort = String(settings.port)
                    }
                    .onChange(of: tempPort) { newValue in
                        if let port = Int(newValue), port > 0 && port <= 65535 {
                            settings.port = port
                        }
                    }
            }
            
            // Connection Test Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Test Conexiune")
                        .fontWeight(.medium)
                    Spacer()
                    
                    if testInProgress {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                // Test Result Display
                if let result = testResult {
                    ConnectionTestResultView(result: result)
                }
                
                // Test Action Buttons
                HStack(spacing: 12) {
                    Button(action: onTestConnection) {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Test Conexiune")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(testInProgress || validationErrors.count > 0)
                }
            }
            
            // Advanced Settings Toggle
            DisclosureGroup("Setări Avansate", isExpanded: $showingAdvancedSettings) {
                AdvancedESP32Settings(settings: $settings)
            }
            
            // Reset Settings
            Button("Resetare Setări ESP32") {
                showingResetAlert = true
            }
                                .foregroundColor(Color.primaryRed)
            .alert("Resetare Setări ESP32", isPresented: $showingResetAlert) {
                Button("Anulare", role: .cancel) { }
                Button("Resetare", role: .destructive) {
                    onReset()
                }
            } message: {
                Text("Această acțiune va reseta toate setările ESP32 la valorile implicite.")
            }
        }
    }
}

// MARK: - Connection Test Result View

struct ConnectionTestResultView: View {
    let result: ConnectionTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.statusDescription)
                    .fontWeight(.medium)
                Spacer()
                Text(result.responseTimeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.message)
                .font(.caption)
                .foregroundColor(result.success ? Color.primaryGreen : Color.primaryRed)
            
            if let statusCode = result.statusCode {
                Text("HTTP Status: \(statusCode)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let deviceInfo = result.deviceInfo {
                DisclosureGroup("Informații Device") {
                    VStack(alignment: .leading, spacing: 4) {
                        if let deviceId = deviceInfo["device_id"] as? String {
                            Text("ID Device: \(deviceId)")
                                .font(.caption2)
                        }
                        if let localIP = deviceInfo["local_ip"] as? String {
                            Text("IP Local: \(localIP)")
                                .font(.caption2)
                        }
                        if let signalStrength = deviceInfo["signal_strength"] as? Int {
                            Text("Semnal WiFi: \(signalStrength) dBm")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(result.success ? Color.primaryGreen.opacity(0.1) : Color.primaryRed.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.success ? Color.primaryGreen.opacity(0.3) : Color.primaryRed.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Advanced ESP32 Settings

struct AdvancedESP32Settings: View {
    @Binding var settings: ESP32ConnectionSettings
    
    var body: some View {
        Group {
            // HTTPS Toggle
            Toggle("Folosește HTTPS", isOn: $settings.useHTTPS)
            
            // Auto Discovery Toggle
            Toggle("Descoperire Automată", isOn: $settings.discoveryEnabled)
            
            // Connection Timeout
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Timeout Conexiune")
                    Spacer()
                    Text("\(Int(settings.connectionTimeout))s")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settings.connectionTimeout, in: 1...30, step: 1) {
                    Text("Timeout")
                } minimumValueLabel: {
                    Text("1s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("30s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(.blue)
            }
            
            // Command Timeout
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Timeout Comenzi")
                    Spacer()
                    Text("\(Int(settings.commandTimeout))s")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settings.commandTimeout, in: 1...60, step: 1) {
                    Text("Timeout")
                } minimumValueLabel: {
                    Text("1s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("60s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(Color.primaryOrange)
            }
            
            // Retry Attempts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Încercări Reîncercare")
                    Spacer()
                    Text("\(settings.retryAttempts)")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: .init(
                    get: { Double(settings.retryAttempts) },
                    set: { settings.retryAttempts = Int($0) }
                ), in: 0...10, step: 1) {
                    Text("Încercări")
                } minimumValueLabel: {
                    Text("0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(.purple)
            }
            
            // Last Successful Connection
            if let lastConnection = settings.lastSuccessfulConnection {
                HStack {
                    Text("Ultima Conexiune")
                    Spacer()
                    Text(formatDate(lastConnection))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Last Known IP
            if let lastIP = settings.lastKnownIP {
                HStack {
                    Text("Ultimul IP Cunoscut")
                    Spacer()
                    Text(lastIP)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Awake Status Section

struct AwakeStatusSection: View {
    @Binding var status: AwakeStatus
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            // Current Status Display
            HStack {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundColor(status.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status Actual")
                        .font(.headline)
                    
                    Text(status.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(status.color)
                    
                    Text(status.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(status.emoji)
                    .font(.title)
            }
            .padding()
            .background(status.color.opacity(0.1))
            .cornerRadius(12)
            
            // Status Picker
            Picker("Status Personal", selection: $status) {
                ForEach(AwakeStatus.allCases, id: \.self) { awakeStatus in
                    HStack {
                        Image(systemName: awakeStatus.icon)
                        Text(awakeStatus.displayName)
                        Text(awakeStatus.emoji)
                    }
                    .tag(awakeStatus)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: status) { newStatus in
                settingsViewModel.updateAwakeStatus(newStatus)
            }
            
            // Auto Detection Status
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color.primaryRed)
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
                        .foregroundColor(Color.primaryGreen)
                        .font(.title3)
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(Color.primaryBlue)
                        .font(.caption)
                    
                    Text("Verifică la fiecare 1 minut")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.primaryGreen.opacity(0.1))
            .cornerRadius(12)
            
            // Status Info
            VStack(alignment: .leading, spacing: 8) {
                Text("Informații")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if status == .awake {
                    Text("• Aplicația va recomanda cafea pe baza datelor de somn")
                    Text("• Comenzile automate sunt active")
                    Text("• Poți comanda manual cafea oricând")
                } else {
                    Text("• Aplicația va detecta automat trezirea")
                    Text("• Comenzile automate sunt suspendate")
                    Text("• Vei primi notificări când te trezești")
                }
                
                Text("• Statusul se actualizează automat pe baza datelor HealthKit")
                Text("• Monitorizarea este permanent activă")
                Text("• Nu poți dezactiva detectarea automată")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ESP32CommunicationManager())
        .environmentObject(HealthKitManager())
}
