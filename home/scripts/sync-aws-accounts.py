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
        """Handle GET request and capture cookies."""
        # Get cookies from request
        cookie_header = self.headers.get('Cookie', '')
        if cookie_header:
            CallbackHandler.cookies = cookie_header

        # Send success response
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()

        html = """
        <html>
        <head>
            <title>Authentication Success</title>
            <style>
                body {
                    font-family: system-ui, -apple-system, sans-serif;
                    max-width: 600px;
                    margin: 100px auto;
                    padding: 20px;
                    text-align: center;
                }
                h1 { color: #2ecc71; }
                .info {
                    background: #ecf0f1;
                    padding: 15px;
                    border-radius: 5px;
                    margin-top: 20px;
                }
            </style>
        </head>
        <body>
            <h1>✓ Authentication Successful!</h1>
            <p><strong>Your session cookies have been captured.</strong></p>
            <div class="info">
                <p>You can now close this window and return to your terminal.</p>
                <p>The script will automatically download the AWS accounts.</p>
            </div>
            <script>
                // Cookies are already captured by the server
                // No need for additional JavaScript actions
                setTimeout(() => {
                    try { window.close(); } catch(e) {}
                }, 2000);
            </script>
        </body>
        </html>
        """
        self.wfile.write(html.encode())

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
    print("   After login, navigate to the accounts page to capture your session.")
    print()

    # Start callback server
    server = start_callback_server()

    # Open browser
    callback_url = f"http://localhost:8765/callback"
    webbrowser.open(LOGIN_URL)

    # Wait for user input
    print("After you've logged in successfully:")
    print(f"  Visit: {callback_url}")
    print("  Or press Enter to manually provide cookies...")
    input()

    # Check if we got cookies
    if CallbackHandler.cookies:
        print("✓ Session captured!")
        # Save cookies
        COOKIE_FILE.write_text(CallbackHandler.cookies)
        server.shutdown()
        return True

    # Manual cookie input
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
