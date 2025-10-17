# Dosya Adı: camera.py

import cv2
import sys
import numpy as np
import time

def main(camera_index=0):
    """
    Kameradan görüntüleri yakalar, JPEG'e dönüştürür ve stdout'a basar.
    Protokol:
    1. Görüntü verisinin boyutu (string olarak) + '\n' karakteri
    2. Görüntünün ham byte verisi
    """
    try:
        # Belirtilen indeksteki kamerayı aç
        cap = cv2.VideoCapture(camera_index)

        # İstenen çözünürlüğü ayarla
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

        if not cap.isOpened():
            # Hata mesajını stderr'e (standart hata) yazarak Flutter'ın yakalamasını sağla
            sys.stderr.write(f"Hata: Kamera indeksi {camera_index} açılamadı.\n")
            sys.stderr.flush()
            return

        while True:
            # Kameradan bir kare oku
            ret, frame = cap.read()
            if not ret:
                # Kare okunamadıysa, bir süre bekleyip tekrar dene veya döngüyü sonlandır
                sys.stderr.write("Hata: Kameradan kare okunamadı.\n")
                sys.stderr.flush()
                time.sleep(1)
                continue

            # ---- GÖRÜNTÜ İŞLEME KODLARINIZI BURAYA EKLEYEBİLİRSİNİZ ----
            # Örneğin: frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            # -------------------------------------------------------------

            # Kareyi JPEG formatında sıkıştır. Kaliteyi ayarlayarak performansı/görüntüyü dengeleyebilirsiniz.
            encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 85]
            result, encimg = cv2.imencode('.jpg', frame, encode_param)

            if not result:
                # Sıkıştırma başarısız olduysa sonraki kareye geç
                continue

            # Veriyi byte dizisine çevir
            byte_data = encimg.tobytes()
            data_length = len(byte_data)

            # Flutter tarafı kapandığında bu blok BrokenPipeError hatası verir.
            try:
                # 1. Adım: Verinin boyutunu ve ardından newline karakterini gönder.
                # sys.stdout.buffer, ham byte verisi yazmak için kullanılır.
                sys.stdout.buffer.write(str(data_length).encode('utf-8') + b'\n')

                # 2. Adım: Görüntü verisinin kendisini gönder.
                sys.stdout.buffer.write(byte_data)

                # stdout buffer'ını hemen gönder. Bu satır çok önemlidir!
                sys.stdout.flush()
            except BrokenPipeError:
                # Flutter uygulaması kapandı, bu normal bir durum. Temizce çıkış yap.
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
    # Argüman olarak kamera indeksi alınabilir, varsayılan 0'dır.
    # Flutter'dan argüman göndermek isterseniz bunu kullanabilirsiniz.
    camera_idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    main(camera_idx)