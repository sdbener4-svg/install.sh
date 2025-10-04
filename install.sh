#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3 python3-pip ffmpeg

# Install python libraries
pip3 install flask flask-wtf apscheduler

# Buat folder project
mkdir -p ~/yt-streaming/videos
cd ~/yt-streaming

# Buat app.py
cat > app.py << 'EOF'
from flask import Flask, render_template, request, redirect, url_for
import subprocess
import os
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime

app = Flask(__name__)
scheduler = BackgroundScheduler()
scheduler.start()

process = None  # simpan proses FFmpeg

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        judul = request.form["judul"]
        video = request.form["video"]
        stream_key = request.form["stream_key"]
        start_time = request.form.get("start_time")
        stop_time = request.form.get("stop_time")

        # Kalau tidak ada jadwal, langsung start
        if not start_time:
            start_stream(video, stream_key)

        # Jadwalkan mulai
        if start_time:
            start_dt = datetime.strptime(start_time, "%Y-%m-%dT%H:%M")
            scheduler.add_job(start_stream, "date", run_date=start_dt, args=[video, stream_key])

        # Jadwalkan berhenti
        if stop_time:
            stop_dt = datetime.strptime(stop_time, "%Y-%m-%dT%H:%M")
            scheduler.add_job(stop_stream, "date", run_date=stop_dt)

        return redirect(url_for("index"))

    return render_template("index.html")

def start_stream(video, stream_key):
    global process
    stop_stream()  # stop dulu kalau ada yg jalan

    youtube_url = f"rtmp://a.rtmp.youtube.com/live2/{stream_key}"

    command = [
        "ffmpeg",
        "-re", "-i", f"videos/{video}",
        "-c:v", "libx264", "-preset", "veryfast", "-maxrate", "3000k",
        "-bufsize", "6000k", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "128k",
        "-f", "flv", youtube_url
    ]
    process = subprocess.Popen(command)

def stop_stream():
    global process
    if process:
        process.terminate()
        process = None

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
EOF

# Buat folder templates
mkdir -p templates

# Buat index.html
cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Buat Tugas Live Streaming</title>
</head>
<body>
    <h2>Buat Tugas Live Streaming</h2>
    <form method="POST">
        <label>Judul Live:</label><br>
        <input type="text" name="judul" placeholder="Masukkan Judul Live"><br><br>

        <label>Pilih Video:</label><br>
        <select name="video">
            <option value="JIBRIL.mp4">JIBRIL.mp4</option>
            <option value="video2.mp4">video2.mp4</option>
        </select><br><br>

        <label>Masukkan Kunci Aliran:</label><br>
        <input type="text" name="stream_key" placeholder="Masukkan Kunci Streaming YouTube"><br><br>

        <label>Jadwal Mulai (Opsional):</label><br>
        <input type="datetime-local" name="start_time"><br><br>

        <label>Jadwal Berhenti (Opsional):</label><br>
        <input type="datetime-local" name="stop_time"><br><br>

        <button type="submit">Mulai Live</button>
    </form>
</body>
</html>
EOF

echo "==================================================="
echo "Setup selesai!"
echo "1. Upload video ke folder: ~/yt-streaming/videos/"
echo "2. Jalankan server dengan: cd ~/yt-streaming && python3 app.py"
echo "3. Akses di browser: http://IP-VPS:5000"
echo "==================================================="
