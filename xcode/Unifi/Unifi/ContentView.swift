import SwiftUI
import WebKit
import Network

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var errorMessage: String?
    @Binding var isOffline: Bool

    func makeNSView(context: Context) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()
        let preferences = WKPreferences()

        // Enable WebRTC features
        preferences.javaScriptCanOpenWindowsAutomatically = true
        webViewConfig.allowsAirPlayForMediaPlayback = true
        webViewConfig.mediaTypesRequiringUserActionForPlayback = []

        webViewConfig.preferences = preferences

        // Enable WebRTC (Camera & Microphone)
        webViewConfig.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = context.coordinator
        webView.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var progressIndicator: NSProgressIndicator?

        init(_ parent: WebView) {
            self.parent = parent
            self.progressIndicator = NSProgressIndicator()
            self.progressIndicator?.style = .spinning
            self.progressIndicator?.isDisplayedWhenStopped = false
            self.progressIndicator?.startAnimation(nil)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.errorMessage = "Failed to load page: \(error.localizedDescription)"
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.errorMessage = "Failed to load page: \(error.localizedDescription)"
            }
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard keyPath == "estimatedProgress", let webView = object as? WKWebView else {
                return
            }
            DispatchQueue.main.async {
                if webView.estimatedProgress < 1.0 {
                    self.progressIndicator?.startAnimation(nil)
                } else {
                    self.progressIndicator?.stopAnimation(nil)
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var errorMessage: String? = nil
    @State private var isOffline: Bool = false
    @State private var updateMessage: String? = nil

    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red))
            } else if isOffline {
                VStack {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                        .padding(.bottom, 20)
                    Text("Mac is offline or unable to reach Unifi")
                        .font(.title)
                        .foregroundColor(.red)
                        .padding(.bottom, 20)
                }
                .padding()
            } else {
                WebView(url: URL(string: "https://unifi.ui.com")!, errorMessage: $errorMessage, isOffline: $isOffline)
                    .frame(minWidth: 1024, minHeight: 768) // Larger default window
            }
        }
        .onAppear {
            checkNetworkStatus()
            checkForUpdates()
        }
    }

    // Check network status
    func checkNetworkStatus() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")

        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .unsatisfied {
                    self.isOffline = true
                } else {
                    self.isOffline = false
                }
            }
        }

        monitor.start(queue: queue)
    }

    // Check if the app is out of date
    func checkForUpdates() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let url = URL(string: "https://api.github.com/repos/wicorn29/uidesktop/releases/latest")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to check for updates: \(error)")
                return
            }

            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let latestVersion = json["tag_name"] as? String {

                        DispatchQueue.main.async {
                            if currentVersion != latestVersion {
                                self.showUpdateAlert(version: latestVersion)
                            }
                        }
                    }
                } catch {
                    print("Failed to parse response: \(error)")
                }
            }
        }
        task.resume()
    }

    // Show the update alert with the new version and a "Go to Downloads" option
    func showUpdateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version (\(version)) is available. Please update the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        // Add the "Go to Downloads" button
        alert.addButton(withTitle: "Go to Downloads")
        
        // Show the alert and handle the button click
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            // Open the GitHub releases page if "Go to Downloads" is clicked
            if let url = URL(string: "https://github.com/wicorn29/uidesktop/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
