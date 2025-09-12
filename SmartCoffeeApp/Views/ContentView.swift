import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var esp32Manager = ESP32CommunicationManager()
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "cup.and.saucer.fill")
                    Text("Coffee")
                }
            
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Dashboard")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .environmentObject(healthKitManager)
        .environmentObject(esp32Manager)
        .onAppear {
            setupApplication()
        }
    }
    
    private func setupApplication() {
        Task {
            await requestHealthKitPermissions()
            await discoverESP32()
        }
    }
    
    private func requestHealthKitPermissions() async {
        do {
            let granted = try await healthKitManager.requestPermissions()
            print("HealthKit permissions granted: \(granted)")
        } catch {
            print("HealthKit permission error: \(error)")
        }
    }
    
    private func discoverESP32() async {
        do {
            if let discoveredIP = try await esp32Manager.discoverESP32() {
                print("ESP32 discovered at: \(discoveredIP)")
            } else {
                print("ESP32 not found on network")
            }
        } catch {
            print("ESP32 discovery error: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
