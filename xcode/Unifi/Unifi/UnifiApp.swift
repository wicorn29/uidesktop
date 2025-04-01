import SwiftUI
import WebKit

@main
struct UnifiApp: App {
    @State private var showingAlert = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text("Log Out"),
                        message: Text("This will log you out of your UI account and close this app. Are you sure?"),
                        primaryButton: .destructive(Text("Log Out")) {
                            clearCookies()
                        },
                        secondaryButton: .cancel()
                    )
                }
        }
        .commands {
            CommandMenu("Unifi") {
                Button("Log Out") {
                    showingAlert = true
                }
                .keyboardShortcut("K", modifiers: [.command, .option])
                
                // Commented out the Refresh button for now
                /*
                Button("Refresh") {
                    if let window = NSApplication.shared.windows.first,
                       let webView = window.contentView?.subviews.compactMap({ $0 as? WKWebView }).first {
                        webView.reload()
                    }
                }
                .keyboardShortcut("R", modifiers: [.command])
                */
            }
        }
    }
    
    @MainActor
    func clearCookies() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                dataStore.removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {
                    NSApp.terminate(nil)
                })
            }
        }
    }
}
