import http.server
import socketserver
import urllib.parse
import subprocess
import json
import re
import os

PORT = 9999
AUTH_KEY = "zivpn123" # Default key, sebaiknya diubah

def run_zivpn_cmd(args):
    # Menjalankan zivpn cli
    # Kita asumsikan zivpn.sh sudah mendukung output JSON/Clean via flag atau kita parsing manual
    # Untuk saat ini kita parsing manual output zivpn.sh standar
    
    cmd = ["/usr/local/bin/zivpn"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
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

