import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var esp32Manager: ESP32CommunicationManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationView {
            Form {
                // Coffee Preferences Section
                Section("Preferințe Cafea") {
                    CoffeePreferencesSection(preferences: $viewModel.coffeePreferences)
                }
                
                // Auto Mode Section
                Section("Mod Automat") {
                    AutoModeSection(settings: $viewModel.autoSettings)
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
                        onScanNetwork: {
                            Task {
                                await viewModel.scanForESP32()
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
                    NotificationSettings(settings: $viewModel.notificationSettings)
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
    }
}

// MARK: - Coffee Preferences Section

struct CoffeePreferencesSection: View {
    @Binding var preferences: UserCoffeePreferences
    
    var body: some View {
        Group {
            // Preferred Coffee Type
            HStack {
                Text("Tip Preferat")
                Spacer()
                Picker("Tip Cafea", selection: $preferences.preferredType) {
                    Text("Automată").tag(nil as CoffeeType?)
                    ForEach(CoffeeType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type as CoffeeType?)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Coffee Strength
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Intensitate Preferată")
                    Spacer()
                    Text("\(Int(preferences.preferredStrength * 100))%")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $preferences.preferredStrength, in: 0.1...1.0, step: 0.1) {
                    Text("Intensitate")
                } minimumValueLabel: {
                    Text("10%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(.brown)
            }
            
            // Daily Caffeine Limit
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Limită Zilnică Cafeină")
                    Spacer()
                    Text("\(Int(preferences.maxCaffeinePerDay)) mg")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $preferences.maxCaffeinePerDay, in: 100...600, step: 50) {
                    Text("Cafeină")
                } minimumValueLabel: {
                    Text("100mg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("600mg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accentColor(.orange)
                
                Text("Recomandat: maxim 400mg pe zi")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Auto Mode Section

struct AutoModeSection: View {
    @Binding var settings: AutoModeSettings
    
    var body: some View {
        Group {
            // Enable Auto Mode
            Toggle("Activează Modul Automat", isOn: $settings.autoModeEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .green))
            
            if settings.autoModeEnabled {
                // Require Confirmation
                Toggle("Necesită Confirmare", isOn: $settings.requireConfirmation)
                
                // Auto Only Weekdays
                Toggle("Doar în Zilele de Lucru", isOn: $settings.autoOnlyOnWeekdays)
                
                // Countdown Duration
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Durată Countdown")
                        Spacer()
                        Text("\(Int(settings.countdownDuration))s")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.countdownDuration, in: 10...60, step: 5) {
                        Text("Countdown")
                    } minimumValueLabel: {
                        Text("10s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("60s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accentColor(.blue)
                }
                
                // Wake Detection Sensitivity
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sensibilitate Detectare")
                        Spacer()
                        Text("\(Int(settings.wakeDetectionSensitivity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.wakeDetectionSensitivity, in: 0.3...1.0, step: 0.1) {
                        Text("Sensibilitate")
                    } minimumValueLabel: {
                        Text("Scăzută")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("Ridicată")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accentColor(.purple)
                    
                    Text("Sensibilitate ridicată = detectare mai rapidă, dar posibile alarme false")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Preferred Wake Time
                DatePicker("Ora Preferată de Trezire", 
                          selection: $settings.preferredWakeTime, 
                          displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
            }
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
                        .fill(esp32Manager.isConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    
                    Text(esp32Manager.isConnected ? "Conectat" : "Deconectat")
                        .foregroundColor(esp32Manager.isConnected ? .green : .red)
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
                
                if let status = esp32Manager.esp32Status {
                    HStack {
                        Text("Uptime ESP32")
                        Spacer()
                        Text(formatUptime(status.uptimeSeconds))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Semnal WiFi")
                        Spacer()
                        Text("\(status.wifiStrength) dBm (\(status.signalQuality.displayName))")
                            .foregroundColor(Color(status.signalQuality.color))
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
                
                if esp32Manager.isConnected {
                    Button("Test Conexiune") {
                        Task {
                            try? await esp32Manager.testConnection()
                        }
                    }
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
                        .fill(healthKitManager.isAuthorized ? .green : .red)
                        .frame(width: 10, height: 10)
                    
                    Text(healthKitManager.isAuthorized ? "Autorizat" : "Neautorizat")
                        .foregroundColor(healthKitManager.isAuthorized ? .green : .red)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            if !healthKitManager.isAuthorized {
                Button("Activează Accesul HealthKit") {
                    Task {
                        try? await healthKitManager.requestPermissions()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Wake Detection Status
            HStack {
                Text("Monitorizare Trezire")
                Spacer()
                
                Text(healthKitManager.isMonitoringWake ? "Activă" : "Inactivă")
                    .foregroundColor(healthKitManager.isMonitoringWake ? .green : .secondary)
            }
            
            if healthKitManager.isAuthorized {
                if healthKitManager.isMonitoringWake {
                    Button("Oprește Monitorizarea") {
                        healthKitManager.stopWakeDetection()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Pornește Monitorizarea") {
                        healthKitManager.startWakeDetection()
                    }
                    .foregroundColor(.green)
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

struct NotificationSettings: View {
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
            
            Button("Resetare Setări") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            
            Button("Resetare Date") {
                // Reset all data
            }
            .foregroundColor(.red)
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
}

// MARK: - Supporting Views

struct ManualIPConfigurationView: View {
    @Binding var ipAddress: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Adresă IP ESP32") {
                    TextField("192.168.1.100", text: $ipAddress)
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
    let onScanNetwork: () -> Void
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
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                TextField("http://192.168.1.100", text: $tempURL)
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
                                .foregroundColor(.red)
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
                    
                    Button(action: onScanNetwork) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Scanează Rețeaua")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(testInProgress)
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
            .foregroundColor(.red)
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
                .foregroundColor(result.success ? .green : .red)
            
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
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
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
                .accentColor(.orange)
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

#Preview {
    SettingsView()
        .environmentObject(ESP32CommunicationManager())
        .environmentObject(HealthKitManager())
}
