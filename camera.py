import cv2
import sys
import time

def main(camera_index=0):
    try:
        cap = cv2.VideoCapture(camera_index)

        # İstenen çözünürlüğü ayarla
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

        if not cap.isOpened():
            sys.stderr.write(f"Hata: Kamera indeksi {camera_index} açılamadı.\n")
            sys.stderr.flush()
            return

        while True:
            ret, frame = cap.read()
            if not ret:
                sys.stderr.write("Hata: Kameradan kare okunamadı.\n")
                sys.stderr.flush()
                time.sleep(1)
                continue

            encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 85]
            result, encimg = cv2.imencode('.jpg', frame, encode_param)

            if not result:
                continue

            byte_data = encimg.tobytes()
            data_length = len(byte_data)
            try:
                sys.stdout.buffer.write(str(data_length).encode('utf-8') + b'\n')
                sys.stdout.buffer.write(byte_data)
                sys.stdout.flush()
            except BrokenPipeError:
                sys.stderr.write("Bağlantı kapandı, Python betiği sonlandırılıyor.\n")
                sys.stderr.flush()
                break

    except Exception as e:
        sys.stderr.write(f"Beklenmedik bir hata oluştu: {e}\n")
        sys.stderr.flush()
    finally:
        if 'cap' in locals() and cap.isOpened():
            cap.release()

if __name__ == '__main__':
    camera_idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    main(camera_idx)