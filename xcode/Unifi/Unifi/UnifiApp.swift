import SwiftUI
import WebKit

@main
struct UnifiApp: App {
    @State private var showingAlert = false
    @State private var webView: WKWebView?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        webView = window.contentView?.subviews.compactMap { $0 as? WKWebView }.first
                    }
                }
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
                
                Button("Refresh") {
                    webView?.reload()
                }
                .keyboardShortcut("R", modifiers: [.command])
                
                Button("Reset to Default Page") {
                    if let webView = webView {
                        print("Resetting WebView")
                        webView.load(URLRequest(url: URL(string: "https://unifi.ui.com")!))
                    } else {
                        print("WebView not found!")
                    }
                }
                .keyboardShortcut("R", modifiers: [.command, .option])
            }

            CommandMenu("Debug") {
                Button("Force Redirect User") {
                    promptForURL()
                }
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

    func promptForURL() {
        let alert = NSAlert()
        alert.messageText = "Enter URL to Redirect"
        alert.alertStyle = .informational
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = inputTextField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let urlString = inputTextField.stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: urlString) {
                webView?.load(URLRequest(url: url))
            }
        }
    }
}
