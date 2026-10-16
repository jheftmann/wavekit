import SwiftUI
import WebKit

/// A WKWebView-based login that loads surfline.com/login and intercepts
/// the auth token via a JavaScript fetch/XHR hook — no hardcoded client
/// credentials required.
struct SurflineWebLoginView: NSViewRepresentable {
    @ObservedObject var authManager: AuthManager
    var onDismiss: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // Inject intercept script before any page JS runs
        let script = WKUserScript(
            source: interceptScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)
        contentController.add(context.coordinator, name: "authToken")

        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Load the homepage — Surfline's /login path returns 404.
        // The user clicks "Log In" in the nav, or the page redirects there automatically.
        let url = URL(string: "https://www.surfline.com/")!
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(authManager: authManager, onDismiss: onDismiss)
    }

    // MARK: - JS intercept script

    /// Overrides fetch and XHR at document-start so we see the response
    /// from Surfline's POST to /trusted/token, then posts the token JSON
    /// back to Swift via webkit.messageHandlers.authToken.
    private var interceptScript: String {
        """
        (function() {
            // --- fetch intercept ---
            const _fetch = window.fetch;
            window.fetch = function(...args) {
                const reqUrl = typeof args[0] === 'string'
                    ? args[0]
                    : (args[0] && args[0].url ? args[0].url : '');
                return _fetch.apply(this, args).then(function(response) {
                    if (reqUrl.includes('/trusted/token')) {
                        response.clone().json().then(function(data) {
                            if (data && data.access_token) {
                                window.webkit.messageHandlers.authToken
                                    .postMessage(JSON.stringify(data));
                            }
                        }).catch(function(){});
                    }
                    return response;
                });
            };

            // --- XMLHttpRequest intercept ---
            const _open = XMLHttpRequest.prototype.open;
            const _send = XMLHttpRequest.prototype.send;

            XMLHttpRequest.prototype.open = function(method, url) {
                this._wkUrl = url;
                return _open.apply(this, arguments);
            };

            XMLHttpRequest.prototype.send = function() {
                var xhr = this;
                xhr.addEventListener('load', function() {
                    if (xhr._wkUrl && xhr._wkUrl.includes('/trusted/token')
                            && xhr.status === 200) {
                        try {
                            var data = JSON.parse(xhr.responseText);
                            if (data && data.access_token) {
                                window.webkit.messageHandlers.authToken
                                    .postMessage(xhr.responseText);
                            }
                        } catch(e) {}
                    }
                });
                return _send.apply(this, arguments);
            };
        })();
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let authManager: AuthManager
        let onDismiss: () -> Void
        private var tokenReceived = false

        init(authManager: AuthManager, onDismiss: @escaping () -> Void) {
            self.authManager = authManager
            self.onDismiss = onDismiss
        }

        // Called from JS when auth token is intercepted
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard !tokenReceived,
                  message.name == "authToken",
                  let body = message.body as? String,
                  let data = body.data(using: .utf8) else { return }

            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                tokenReceived = true

                Task { @MainActor in
                    self.authManager.loginWithWebToken(
                        accessToken: authResponse.accessToken,
                        refreshToken: authResponse.refreshToken,
                        expiresIn: authResponse.expiresIn
                    )
                    self.onDismiss()
                }
            } catch {
                // JSON didn't match expected shape — ignore and wait
            }
        }

        // Close window when user navigates away from login (e.g. already logged in)
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !tokenReceived,
                  let url = webView.url?.absoluteString else { return }

            // If the page landed on the home feed (not /login), the user was
            // already logged in — try extracting token from localStorage instead.
            if !url.contains("/login") && !url.contains("/register") {
                webView.evaluateJavaScript(localStorageScript) { [weak self] result, _ in
                    guard let self,
                          !self.tokenReceived,
                          let json = result as? String,
                          let data = json.data(using: .utf8),
                          let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data)
                    else { return }

                    self.tokenReceived = true
                    Task { @MainActor in
                        self.authManager.loginWithWebToken(
                            accessToken: authResponse.accessToken,
                            refreshToken: authResponse.refreshToken,
                            expiresIn: authResponse.expiresIn
                        )
                        self.onDismiss()
                    }
                }
            }
        }

        /// Try several localStorage keys that Surfline has used for storing
        /// the auth token, returning the first matching value as JSON.
        private var localStorageScript: String {
            """
            (function() {
                function extractToken(obj) {
                    if (!obj) return null;
                    if (obj.access_token) return JSON.stringify(obj);
                    if (obj.token && obj.token.access_token) return JSON.stringify(obj.token);
                    return null;
                }
                var known = [
                    'SL.Auth', 'SURFLINE_USER', 'sl_user', 'USER_ACCESS_TOKEN',
                    'auth_token', 'surfline_auth'
                ];
                for (var i = 0; i < known.length; i++) {
                    try {
                        var raw = localStorage.getItem(known[i]);
                        if (!raw) continue;
                        var result = extractToken(JSON.parse(raw));
                        if (result) return result;
                    } catch(e) {}
                }
                for (var j = 0; j < localStorage.length; j++) {
                    try {
                        var key = localStorage.key(j);
                        var raw = localStorage.getItem(key);
                        if (!raw || raw[0] !== '{') continue;
                        var result = extractToken(JSON.parse(raw));
                        if (result) return result;
                    } catch(e) {}
                }
                for (var k = 0; k < sessionStorage.length; k++) {
                    try {
                        var key = sessionStorage.key(k);
                        var raw = sessionStorage.getItem(key);
                        if (!raw || raw[0] !== '{') continue;
                        var result = extractToken(JSON.parse(raw));
                        if (result) return result;
                    } catch(e) {}
                }
                return null;
            })()
            """
        }
    }
}

