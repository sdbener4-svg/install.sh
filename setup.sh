#!/bin/bash
# ========================================================
# Auto Installer Live Streaming Flask + FFmpeg di VPS
# ========================================================

APP_DIR="/root/live-stream"

echo ">>> Update & install dependensi..."
apt update && apt upgrade -y
apt install -y python3 python3-pip ffmpeg git curl nano

echo ">>> Buat folder project..."
mkdir -p $APP_DIR/templates
cd $APP_DIR

echo ">>> Install Flask..."
pip3 install flask gunicorn

echo ">>> Buat file app.py..."
cat > $APP_DIR/app.py <<'EOF'
from flask import Flask, render_template, request
import subprocess, threading, time
from datetime import datetime

app = Flask(__name__)
YOUTUBE_RTMP = "rtmp://a.rtmp.youtube.com/live2/"

def start_stream(video, stream_key, start_time=None, stop_time=None):
    if start_time:
        delay = (start_time - datetime.now()).total_seconds()
        if delay > 0: time.sleep(delay)

    command = [
        "ffmpeg", "-re", "-stream_loop", "-1", "-i", video,
        "-c:v", "libx264", "-preset", "veryfast", "-maxrate", "3000k",
        "-bufsize", "6000k", "-pix_fmt", "yuv420p",
        "-g", "50", "-c:a", "aac", "-b:a", "160k", "-ar", "44100",
        "-f", "flv", YOUTUBE_RTMP + stream_key
    ]
    process = subprocess.Popen(command)

    if stop_time:
        delay = (stop_time - datetime.now()).total_seconds()
        if delay > 0: time.sleep(delay)
        process.terminate()

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/start", methods=["POST"])
def start():
    judul = request.form["judul"]
    video = request.form["video"]
    stream_key = request.form["stream_key"]

    start_time = request.form.get("start_time")
    stop_time = request.form.get("stop_time")

    start_dt = datetime.fromisoformat(start_time) if start_time else None
    stop_dt = datetime.fromisoformat(stop_time) if stop_time else None

    threading.Thread(target=start_stream, args=(video, stream_key, start_dt, stop_dt)).start()
    return f"Live streaming '{judul}' dimulai!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
EOF

echo ">>> Buat file template index.html..."
cat > $APP_DIR/templates/index.html <<'EOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Buat Tugas Live Streaming</title>
    <style>
        body { font-family: Arial; background: #f4f4f4; }
        .container { background: #fff; padding: 20px; width: 400px; margin: auto; border-radius: 10px; margin-top: 50px; }
        input, select { width: 100%; padding: 10px; margin: 8px 0; border: 1px solid #ccc; border-radius: 5px; }
        button { width: 100%; padding: 12px; background: green; color: white; border: none; border-radius: 5px; font-size: 16px; }
        button:hover { background: darkgreen; cursor: pointer; }
        h2 { text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h2>Buat Tugas Live Streaming</h2>
        <form action="/start" method="post">
            <label>Judul Live:</label>
            <input type="text" name="judul" required>

            <label>Pilih Video:</label>
            <select name="video">
                <option value="test.mp4">test.mp4</option>
            </select>

            <label>Masukkan Kunci Aliran:</label>
            <input type="text" name="stream_key" required>

            <label>Jadwal Mulai (Opsional):</label>
            <input type="datetime-local" name="start_time">

            <label>Jadwal Berhenti (Opsional):</label>
            <input type="datetime-local" name="stop_time">

            <button type="submit">Mulai Live</button>
        </form>
    </div>
</body>
</html>
EOF

echo ">>> Buat video dummy 10 detik (test.mp4)..."
ffmpeg -f lavfi -i testsrc=duration=10:size=640x360:rate=30 -c:v libx264 test.mp4 -y

echo ">>> Buat service systemd..."
cat > /etc/systemd/system/live-stream.service <<EOF
[Unit]
Description=Live Stream Flask App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable live-stream
systemctl start live-stream

echo ">>> Instalasi selesai!"
echo "Akses aplikasi di: http://$(curl -s ifconfig.me):5000"
