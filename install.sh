#!/bin/bash
# Auto installer untuk Web Streaming YouTube di VPS

echo "=== Update & install dependencies ==="
apt update -y
apt upgrade -y
apt install -y python3 python3-pip ffmpeg

echo "=== Install Python modules ==="
pip3 install flask apscheduler

echo "=== Buat folder project ==="
mkdir -p /opt/webstream
cd /opt/webstream

# Buat file app.py (backend Flask)
cat > app.py << 'EOF'
from flask import Flask, render_template, request, redirect
import subprocess, os
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime

app = Flask(__name__)
scheduler = BackgroundScheduler()
scheduler.start()

process = None

def start_stream(video, stream_key):
    global process
    stop_stream()
    rtmp_url = f"rtmp://a.rtmp.youtube.com/live2/{stream_key}"
    cmd = [
        "ffmpeg", "-re", "-i", f"videos/{video}",
        "-c:v", "libx264", "-preset", "veryfast", "-maxrate", "3000k",
        "-bufsize", "6000k", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "160k",
        "-f", "flv", rtmp_url
    ]
    process = subprocess.Popen(cmd)

def stop_stream():
    global process
    if process:
        process.terminate()
        process = None

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        title = request.form["title"]
        video = request.form["video"]
        stream_key = request.form["stream_key"]
        start_time = request.form.get("start_time")
        stop_time = request.form.get("stop_time")

        if start_time:
            st = datetime.strptime(start_time, "%Y-%m-%dT%H:%M")
            scheduler.add_job(start_stream, 'date', run_date=st, args=[video, stream_key])

        if stop_time:
            et = datetime.strptime(stop_time, "%Y-%m-%dT%H:%M")
            scheduler.add_job(stop_stream, 'date', run_date=et)

        if not start_time:
            start_stream(video, stream_key)

        return redirect("/")
    return render_template("index.html", videos=os.listdir("videos"))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

# Buat folder template
mkdir -p templates
cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Buat Tugas Live Streaming</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
</head>
<body class="bg-light">
<div class="container mt-5">
  <h2 class="mb-4">Buat Tugas Live Streaming</h2>
  <form method="POST">
    <div class="mb-3">
      <label class="form-label">Judul Live:</label>
      <input type="text" class="form-control" name="title" placeholder="Masukkan Judul Live">
    </div>
    <div class="mb-3">
      <label class="form-label">Pilih Video:</label>
      <select class="form-select" name="video">
        {% for v in videos %}
        <option>{{ v }}</option>
        {% endfor %}
      </select>
    </div>
    <div class="mb-3">
      <label class="form-label">Masukkan Kunci Aliran:</label>
      <input type="text" class="form-control" name="stream_key" placeholder="Masukkan Kunci Streaming YouTube">
    </div>
    <div class="mb-3">
      <label class="form-label">Jadwal Mulai (Opsional):</label>
      <input type="datetime-local" class="form-control" name="start_time">
    </div>
    <div class="mb-3">
      <label class="form-label">Jadwal Berhenti (Opsional):</label>
      <input type="datetime-local" class="form-control" name="stop_time">
    </div>
    <button type="submit" class="btn btn-success">Mulai Live</button>
  </form>
</div>
</body>
</html>
EOF

# Buat folder videos untuk menyimpan file video
mkdir -p videos

echo "=== Instalasi selesai ==="
echo "Jalankan dengan: cd /opt/webstream && python3 app.py"
