#!/bin/bash
# ==========================================
# Auto Installer: YouTube Streaming Web Panel
# ==========================================

set -e

echo "🚀 Memulai instalasi panel streaming YouTube..."

# --- Update system
apt update -y && apt upgrade -y

# --- Install dependencies
apt install -y python3 python3-pip ffmpeg git ufw

# --- Install Python packages
pip3 install flask flask-socketio eventlet

# --- Buat folder project
mkdir -p /var/www/stream-panel/uploads
cd /var/www/stream-panel

# --- Buat app.py
cat > app.py <<'EOF'
from flask import Flask, render_template, request, redirect, url_for
from flask_socketio import SocketIO
import subprocess, os

app = Flask(__name__)
socketio = SocketIO(app)
UPLOAD_FOLDER = 'uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

STREAM_PROCESS = None
STREAM_KEY_FILE = '/var/www/stream-panel/stream_key.txt'

# --- halaman utama
@app.route('/')
def index():
    stream_key = ''
    if os.path.exists(STREAM_KEY_FILE):
        with open(STREAM_KEY_FILE, 'r') as f:
            stream_key = f.read().strip()
    videos = os.listdir(UPLOAD_FOLDER)
    return render_template('index.html', videos=videos, stream_key=stream_key)

# --- upload video
@app.route('/upload', methods=['POST'])
def upload_video():
    file = request.files['video']
    if file:
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], file.filename))
    return redirect(url_for('index'))

# --- simpan stream key
@app.route('/set_key', methods=['POST'])
def set_key():
    key = request.form['stream_key']
    with open(STREAM_KEY_FILE, 'w') as f:
        f.write(key)
    return redirect(url_for('index'))

# --- mulai streaming
@app.route('/start/<filename>')
def start_stream(filename):
    global STREAM_PROCESS
    if STREAM_PROCESS:
        return "Streaming sudah berjalan."

    with open(STREAM_KEY_FILE, 'r') as f:
        stream_key = f.read().strip()

    input_path = os.path.join(UPLOAD_FOLDER, filename)
    if not os.path.exists(input_path):
        return "Video tidak ditemukan."

    cmd = [
        'ffmpeg', '-re', '-stream_loop', '-1', '-i', input_path,
        '-vcodec', 'libx264', '-preset', 'veryfast', '-maxrate', '3000k', '-bufsize', '6000k',
        '-pix_fmt', 'yuv420p', '-g', '50', '-c:a', 'aac', '-b:a', '128k', '-ar', '44100',
        '-f', 'flv', f'rtmp://a.rtmp.youtube.com/live2/{stream_key}'
    ]

    STREAM_PROCESS = subprocess.Popen(cmd)
    return redirect(url_for('index'))

# --- hentikan streaming
@app.route('/stop')
def stop_stream():
    global STREAM_PROCESS
    if STREAM_PROCESS:
        STREAM_PROCESS.terminate()
        STREAM_PROCESS = None
    return redirect(url_for('index'))

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000)
EOF

# --- Buat template HTML
mkdir -p templates
cat > templates/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>YouTube Stream Panel</title>
    <style>
        body { font-family: sans-serif; max-width: 700px; margin: 40px auto; }
        input, button { padding: 8px; margin: 5px; width: 100%; }
        video { width: 100%; border-radius: 8px; margin-top: 10px; }
    </style>
</head>
<body>
    <h2>🎬 YouTube Live Stream Panel</h2>

    <form action="/set_key" method="POST">
        <input type="text" name="stream_key" placeholder="Masukkan Stream Key" value="{{ stream_key }}">
        <button type="submit">💾 Simpan Stream Key</button>
    </form>

    <form action="/upload" method="POST" enctype="multipart/form-data">
        <input type="file" name="video" required>
        <button type="submit">⬆️ Upload Video</button>
    </form>

    <h3>📂 Daftar Video</h3>
    <ul>
    {% for v in videos %}
        <li>{{v}} — <a href="/start/{{v}}">▶️ Start</a></li>
    {% endfor %}
    </ul>

    <a href="/stop"><button>⛔ Stop Streaming</button></a>
</body>
</html>
EOF

# --- Buat systemd service
cat > /etc/systemd/system/stream-panel.service <<'EOF'
[Unit]
Description=YouTube Streaming Control Panel
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/stream-panel
ExecStart=/usr/bin/python3 /var/www/stream-panel/app.py
Restart=always
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

# --- Enable service
systemctl daemon-reload
systemctl enable stream-panel
systemctl start stream-panel

# --- Buka port firewall
ufw allow 5000/tcp || true

echo ""
echo "✅ Instalasi selesai!"
echo "Akses web panel di: http://YOUR_SERVER_IP:5000"
echo "Gunakan untuk upload video & ganti stream key."
