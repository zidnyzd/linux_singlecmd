import http.server
import socketserver
import urllib.parse
import subprocess
import json
import re
import os
import socket
from datetime import datetime

PORT = 9999
AUTH_KEY = "zivpn123" # Default key, sebaiknya diubah

def run_zivpn_cmd(args):
    # Menjalankan zivpn cli dengan API mode
    cmd = ["/usr/local/bin/zivpn"] + args
    try:
        env = os.environ.copy()
        env["ZIVPN_API_MODE"] = "1"
        result = subprocess.run(cmd, capture_output=True, text=True, env=env)
        return result.stdout
    except Exception as e:
        return str(e)

def parse_zivpn_output(output):
    # Parsing output zivpn yang "cantik" menjadi data terstruktur
    # Contoh output:
    # Domain : example.com
    # Username : user
    # Password : user
    # Expires On : 26-11-2025 14:30
    
    data = {}
    
    # Regex patterns
    patterns = {
        "domain": r"Domain\s*:\s*(.+)", # Mengambil teks setelah "Domain :" tapi mengabaikan kode warna ANSI
        "username": r"Username\s*:\s*(.+)",
        "password": r"Password\s*:\s*(.+)",
        "expired": r"Expires (?:On|At)\s*:\s*(.+)",
        "port": r"Port UDP\s*:\s*(\d+)"
    }
    
    # Bersihkan kode warna ANSI
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)
    
    for key, pattern in patterns.items():
        match = re.search(pattern, clean_output)
        if match:
            data[key] = match.group(1).strip()
    
    # Fallback: Parse interactive output format (e.g., "User jjj renewed until Mon Dec  1 11:38:34 AM WIB 2025!")
    if not data.get("username"):
        # Try to extract from "User X renewed until DATE"
        renew_match = re.search(r'User\s+(\w+)\s+renewed\s+until\s+(.+)!', clean_output)
        if renew_match:
            data["username"] = renew_match.group(1).strip()
            # Try to parse the date and convert to DD-MM-YYYY HH:MM format
            date_str = renew_match.group(2).strip()
            try:
                # Try common date formats
                for fmt in ["%a %b %d %I:%M:%S %p %Z %Y", "%a %b  %d %I:%M:%S %p %Z %Y", "%a %b %d %H:%M:%S %Z %Y"]:
                    try:
                        dt = datetime.strptime(date_str, fmt)
                        data["expired"] = dt.strftime("%d-%m-%Y %H:%M")
                        break
                    except:
                        continue
                if "expired" not in data:
                    data["expired"] = date_str  # Fallback: use original string
            except:
                data["expired"] = date_str  # Fallback: use original string
            
            # Get domain from file if not in output
            if not data.get("domain"):
                try:
                    if os.path.exists("/etc/zivpn/domain"):
                        with open("/etc/zivpn/domain", "r") as f:
                            data["domain"] = f.read().strip()
                    else:
                        # Fallback to IP
                        data["domain"] = socket.gethostbyname(socket.gethostname())
                except:
                    data["domain"] = "unknown"
            
    return data

class MyRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed_path.query)
        
        # Simple Auth
        auth = params.get("auth", [""])[0]
        if os.path.exists("/etc/zivpn/api_key"):
            with open("/etc/zivpn/api_key", "r") as f:
                real_key = f.read().strip()
        else:
            real_key = AUTH_KEY
            
        if auth != real_key:
            self.send_response(401)
            self.end_headers()
            self.wfile.write(json.dumps({"status": "error", "message": "Unauthorized"}).encode())
            return

        path = parsed_path.path
        response = {"status": "error", "message": "Invalid endpoint"}
        
        try:
            if path == "/add":
                user = params.get("user", [""])[0]
                password = params.get("password", [user])[0]
                days = params.get("days", ["30"])[0]
                if user:
                    # Gunakan mode quiet/api jika nanti kita implementasikan, 
                    # atau parsing output standar
                    raw = run_zivpn_cmd(["add", user, password, days])
                    data = parse_zivpn_output(raw)
                    if data.get("username"):
                        response = {"status": "success", "data": data}
                    else:
                        response = {"status": "error", "message": "Failed to create user", "raw": raw}
                else:
                    response["message"] = "Missing user parameter"

            elif path == "/trial":
                user = params.get("user", [""])[0]
                mins = params.get("mins", ["30"])[0]
                if user:
                    raw = run_zivpn_cmd(["trial", user, mins])
                    data = parse_zivpn_output(raw)
                    if data.get("username"):
                        response = {"status": "success", "data": data}
                    else:
                        response = {"status": "error", "message": "Failed to create trial", "raw": raw}
                else:
                    response["message"] = "Missing user parameter"
            
            elif path == "/del":
                user = params.get("user", [""])[0]
                if user:
                    # Perlu bypass konfirmasi (y/n) di script zivpn
                    # Kita perlu update zivpn.sh agar support 'force delete'
                    # Untuk sekarang kita coba pipe 'y'
                    # Tapi subprocess.run sulit pipe stdin langsung tanpa input=...
                    
                    # Workaround: panggil fungsi del_user langsung via sed/modifikasi zivpn.sh
                    # Atau lebih baik: update zivpn.sh agar ada flag --quiet atau force
                    
                    # Asumsi zivpn.sh kita update nanti untuk support 'del_api'
                    raw = run_zivpn_cmd(["del_api", user]) 
                    if "deleted" in raw or "not found" in raw:
                         response = {"status": "success", "message": f"User {user} processed"}
                    else:
                         response = {"status": "error", "raw": raw}
                else:
                    response["message"] = "Missing user parameter"

            elif path == "/renew":
                user = params.get("user", [""])[0]
                days = params.get("days", ["30"])[0]
                if user:
                    raw = run_zivpn_cmd(["renew", user, days])
                    data = parse_zivpn_output(raw)
                    if data.get("username"):
                        response = {"status": "success", "data": data}
                    else:
                        response = {"status": "error", "message": "Failed to renew", "raw": raw}
                else:
                    response["message"] = "Missing user parameter"
                    
        except Exception as e:
            response = {"status": "error", "message": str(e)}

        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

if __name__ == "__main__":
    # Set working dir to /tmp to avoid exposing root files if SimpleHTTP vulnerability exists
    # Though we override do_GET, safer is better.
    os.chdir("/tmp") 
    
    with socketserver.TCPServer(("", PORT), MyRequestHandler) as httpd:
        print(f"ZIVPN API serving at port {PORT}")
        httpd.serve_forever()

