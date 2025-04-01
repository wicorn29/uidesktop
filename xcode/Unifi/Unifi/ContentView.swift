import SwiftUI
import WebKit
import Network

struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var errorMessage: String?
    @Binding var isOffline: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
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

    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                // Show an error message if there's an issue loading the web view
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
                    
                    Button(action: {}) {
                        Text("Mac will automatically dismiss this error when you connect to the internet")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding()
                    }
                    .disabled(true) // Grey out the button
                }
                .padding()
            } else {
                WebView(url: URL(string: "https://unifi.ui.com")!, errorMessage: $errorMessage, isOffline: $isOffline)
                    .frame(minWidth: 1024, minHeight: 768) // Larger default window
            }
        }
        .onAppear {
            checkNetworkStatus()
        }
    }
    
    // Check network status to determine if device is offline
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
}
