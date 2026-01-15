#!/usr/bin/env python3
"""
Sync AWS managed service accounts from authenticated website.
Opens browser for login, then downloads JSON with session cookies.
"""

import json
import os
import sys
import webbrowser
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading

# Configuration
ACCOUNTS_URL = "https://docs-mcs.technative.eu/managed_service_accounts.json"
LOGIN_URL = "https://docs-mcs.technative.eu/"  # Adjust if different
AWS_DIR = Path.home() / ".aws"
JSON_FILE = AWS_DIR / "managed_service_accounts.json"
COOKIE_FILE = AWS_DIR / ".auth_cookies"

class CallbackHandler(BaseHTTPRequestHandler):
    """Simple HTTP server to capture browser callback with cookies."""

    cookies = None

    def do_GET(self):
        """Handle GET request and show instructions page."""
        # Send instructions page
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()

        html = """
        <html>
        <head>
            <meta charset="UTF-8">
            <title>AWS Account Sync - Cookie Capture</title>
            <style>
                body {
                    font-family: system-ui, -apple-system, sans-serif;
                    max-width: 800px;
                    margin: 50px auto;
                    padding: 20px;
                    background: #f5f5f5;
                }
                .container {
                    background: white;
                    padding: 30px;
                    border-radius: 8px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                h1 { color: #2c3e50; margin-top: 0; }
                .step {
                    background: #ecf0f1;
                    padding: 15px;
                    margin: 15px 0;
                    border-radius: 5px;
                    border-left: 4px solid #3498db;
                }
                .bookmarklet {
                    display: inline-block;
                    background: #3498db;
                    color: white;
                    padding: 12px 24px;
                    text-decoration: none;
                    border-radius: 5px;
                    font-weight: bold;
                    margin: 10px 0;
                    cursor: move;
                }
                .bookmarklet:hover {
                    background: #2980b9;
                }
                code {
                    background: #34495e;
                    color: #ecf0f1;
                    padding: 2px 6px;
                    border-radius: 3px;
                    font-size: 0.9em;
                }
                .success {
                    display: none;
                    background: #2ecc71;
                    color: white;
                    padding: 15px;
                    border-radius: 5px;
                    margin-top: 20px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🔐 AWS Account Cookie Capture</h1>

                <div class="step">
                    <strong>Step 1:</strong> Drag this button to your bookmarks bar:
                    <br><br>
                    <a href="javascript:(function(){fetch('http://localhost:8765/cookies',{method:'POST',headers:{'Content-Type':'text/plain'},body:document.cookie}).then(()=>{document.body.innerHTML='<div style=\\"font-family:sans-serif;text-align:center;margin-top:100px;\\"><h1 style=\\"color:green;\\">✓ Cookies Sent!</h1><p>Return to terminal - sync will continue automatically</p></div>';}).catch(e=>alert('Error: '+e))})();"
                       class="bookmarklet">📤 Send Cookies to Sync</a>
                </div>

                <div class="step">
                    <strong>Step 2:</strong> Go to
                    <code>https://docs-mcs.technative.eu/</code> and log in if needed
                </div>

                <div class="step">
                    <strong>Step 3:</strong> On that page, click the bookmarklet you just saved
                </div>

                <div class="step">
                    <strong>Alternative:</strong> If bookmarklets don't work, open DevTools (F12),
                    go to Console tab, and paste:
                    <br><br>
                    <code style="display:block;padding:10px;word-break:break-all;">
                    fetch('http://localhost:8765/cookies',{method:'POST',headers:{'Content-Type':'text/plain'},body:document.cookie})
                    </code>
                </div>

                <div id="success" class="success">
                    ✓ Cookies received! You can close this window.
                </div>
            </div>
        </body>
        </html>
        """
        self.wfile.write(html.encode())

    def do_POST(self):
        """Handle POST request with cookies from JavaScript."""
        if self.path == '/cookies':
            # Read the cookie data from POST body
            content_length = int(self.headers.get('Content-Length', 0))
            cookie_data = self.rfile.read(content_length).decode('utf-8')

            if cookie_data:
                CallbackHandler.cookies = cookie_data
                print(f"\n✓ Received {len(cookie_data)} bytes of cookie data")

            # Send CORS headers to allow cross-origin request
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        """Handle OPTIONS request for CORS preflight."""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def log_message(self, format, *args):
        """Suppress HTTP server logs."""
        pass

def start_callback_server():
    """Start local HTTP server to receive browser callback."""
    server = HTTPServer(('localhost', 8765), CallbackHandler)
    thread = threading.Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()
    return server

def interactive_login():
    """
    Open browser for user to login, capture session.
    Returns True if successful.
    """
    print("🔐 Opening browser for authentication...")
    print(f"   Please login at: {LOGIN_URL}")
    print("   After login, visit the callback URL to complete authentication.")
    print()

    # Start callback server
    server = start_callback_server()

    # Open browser to callback page (with instructions)
    callback_url = f"http://localhost:8765/callback"
    webbrowser.open(callback_url)

    # Poll for cookies with timeout
    print("Instructions opened in browser.")
    print()
    print("⏳ Waiting for authentication (timeout: 5 minutes)...")
    print("   Press Ctrl+C to cancel and enter cookies manually")
    print()

    import time
    timeout = 300  # 5 minutes
    poll_interval = 0.5  # Check every 0.5 seconds
    elapsed = 0

    try:
        while elapsed < timeout:
            if CallbackHandler.cookies:
                print("\n✓ Session captured!")
                # Save cookies
                COOKIE_FILE.write_text(CallbackHandler.cookies)
                server.shutdown()
                return True

            time.sleep(poll_interval)
            elapsed += poll_interval

            # Print progress every 30 seconds
            if int(elapsed) % 30 == 0 and elapsed > 0:
                remaining = int(timeout - elapsed)
                print(f"   Still waiting... ({remaining}s remaining)")

    except KeyboardInterrupt:
        print("\n\n⚠️  Automatic capture cancelled")

    # Timeout or cancelled - try manual cookie input
    if not CallbackHandler.cookies:
        print("\nNo cookies captured automatically.")
        print("Please copy your session cookies from browser DevTools:")
        print("  1. Open DevTools (F12)")
        print(f"  2. Go to: {ACCOUNTS_URL}")
        print("  3. Network tab -> find request -> Copy 'Cookie' header")
        print()
        cookies = input("Paste cookies here: ").strip()

        if cookies:
            COOKIE_FILE.write_text(cookies)
            server.shutdown()
            return True

    server.shutdown()
    return False

def download_accounts():
    """Download accounts JSON using saved session cookies."""

    # Check for saved cookies
    if not COOKIE_FILE.exists():
        print("❌ No authentication session found.")
        print("   Run with --login to authenticate first.")
        return False

    cookie_string = COOKIE_FILE.read_text(encoding='utf-8').strip()

    # Parse cookie string into dict
    cookies = {}
    for item in cookie_string.split(';'):
        item = item.strip()
        if '=' in item:
            key, value = item.split('=', 1)
            cookies[key.strip()] = value.strip()

    # Try to download JSON
    try:
        import urllib.request
        from urllib.parse import urlencode

        # Create cookie header - only use ASCII-safe cookies
        safe_cookies = {}
        for key, value in cookies.items():
            try:
                # Test if cookie is ASCII-safe
                key.encode('ascii')
                value.encode('ascii')
                safe_cookies[key] = value
            except UnicodeEncodeError:
                print(f"⚠️  Skipping non-ASCII cookie: {key[:20]}...")
                continue

        cookie_header = '; '.join(f'{k}={v}' for k, v in safe_cookies.items())

        req = urllib.request.Request(ACCOUNTS_URL)
        req.add_header('Cookie', cookie_header)
        req.add_header('User-Agent', 'Mozilla/5.0')

        print(f"📥 Downloading from {ACCOUNTS_URL}...")
        print(f"   Using {len(safe_cookies)} cookies...")

        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))

        # Validate JSON structure
        if not isinstance(data, list):
            print("❌ Invalid JSON structure (expected list)")
            return False

        # Save JSON
        AWS_DIR.mkdir(exist_ok=True)
        JSON_FILE.write_text(json.dumps(data, indent=2))

        print(f"✓ Downloaded {len(data)} accounts")
        print(f"✓ Saved to {JSON_FILE}")
        return True

    except urllib.error.HTTPError as e:
        if e.code == 401 or e.code == 403:
            print("❌ Authentication expired. Please run with --login")
            COOKIE_FILE.unlink(missing_ok=True)
        else:
            print(f"❌ HTTP Error {e.code}: {e.reason}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main entry point."""

    if len(sys.argv) > 1 and sys.argv[1] == '--login':
        # Interactive login
        if interactive_login():
            print("\n✓ Authentication successful!")
            print("  Now downloading accounts...")
            if download_accounts():
                print("\n✓ All done! Run 'systemctl --user start aws-config-generate' to update config.")
        else:
            print("\n❌ Authentication failed")
            sys.exit(1)
    else:
        # Just download (use existing session)
        if not download_accounts():
            print("\nTip: Run with --login to authenticate first")
            sys.exit(1)

if __name__ == '__main__':
    main()
