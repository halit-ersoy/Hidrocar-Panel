#!/usr/bin/env python3
from flask import Flask, Response, jsonify, abort
import cv2, sys, time, platform

app = Flask(__name__)

camera_index = int(sys.argv[1]) if len(sys.argv) > 1 else 0
port         = int(sys.argv[2]) if len(sys.argv) > 2 else 5000

WIDTH, HEIGHT, FPS = 1280, 720, 30

def open_camera(idx, open_timeout=8):
    # Platforma göre en iyi backend sırası
    if platform.system() == "Windows":
        backends = [cv2.CAP_DSHOW, cv2.CAP_MSMF, cv2.CAP_ANY]
    elif platform.system() == "Linux":
        backends = [cv2.CAP_V4L2, cv2.CAP_ANY]
    else:  # macOS vb.
        backends = [cv2.CAP_AVFOUNDATION, cv2.CAP_ANY]

    start = time.time()
    for be in backends:
        print(f"[INFO] Trying index={idx} backend={be}", flush=True)
        cap = cv2.VideoCapture(idx, be)
        if cap.isOpened():
            # Tercihen MJPG + çözünürlük + fps
            cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
            cap.set(cv2.CAP_PROP_FRAME_WIDTH,  WIDTH)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, HEIGHT)
            cap.set(cv2.CAP_PROP_FPS,          FPS)
            # sensör ısınsın
            for _ in range(5):
                cap.read()
            return cap
        cap.release()
        if time.time() - start > open_timeout:
            break
    return None

def gen_frames(cap):
    boundary = b'--frame'
    while True:
        ok, frame = cap.read()
        if not ok:
            print("[ERR] frame read failed; stopping.", flush=True)
            break
        ok, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        if not ok:
            continue
        yield (boundary + b'\r\n'
                          b'Content-Type: image/jpeg\r\n'
                          b'Content-Length: ' + str(len(buffer)).encode() + b'\r\n\r\n' +
               buffer.tobytes() + b'\r\n')
    cap.release()

@app.route('/health')
def health():
    return jsonify({"status": "ok", "index": camera_index, "port": port}), 200

@app.route('/video')
def video_feed():
    cap = open_camera(camera_index, open_timeout=8)
    if cap is None:
        print(f"[ERR] open timeout/busy for index={camera_index}", flush=True)
        return abort(503, "Camera open timeout or busy")
    return Response(gen_frames(cap),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    print(f"[BOOT] index={camera_index} port={port}", flush=True)
    # Flutter ile aynı makinede çalıştığın için localhost yeterli:
    app.run(host='0.0.0.0', port=port, threaded=True)
