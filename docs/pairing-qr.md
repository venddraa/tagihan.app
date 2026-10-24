# Persiapan QR pairing

Checkpoint persiapan menambahkan tinjauan undangan dan pengaturan waktu tampil
tanpa dependency baru. QR, scanner kamera, dan adapter Keychain belum dibuat.

## Alur yang sudah siap

- Client meninjau alamat hub, Hub ID, fingerprint SHA-256, dan expiry sebelum
  tombol kirim aktif. Preview hanya mem-parsing teks lokal; belum ada koneksi
  jaringan atau pembacaan keyring. Mengubah teks membatalkan preview.
- Preview tidak menampilkan token undangan sebagai field tersendiri. Jam lokal
  hanya memberi informasi expiry; pemeriksaan akhir tetap dilakukan Go hub.
- Fedora menyembunyikan token ketika deadline tampilan habis (maksimal lima
  menit) atau aplikasi tidak aktif. Timer dibatalkan saat widget dilepas.
- Response create yang datang setelah aplikasi sempat tidak aktif tidak
  membuka kembali token. Tidak ada polling jaringan pada expiry atau resume.
- Input undangan client dibersihkan saat aplikasi tidak aktif. Sesi pending
  yang telah tersimpan di keyring tetap dipertahankan untuk recovery.

Menyembunyikan token tidak mencabut undangan di hub dan tidak membersihkan
clipboard OS. Undangan baru menggantikan undangan lama; pembatalan tetap harus
dikonfirmasi melalui endpoint yang sudah ada.

## Pilihan dependency generator

**Pilihan A — `qr_flutter` 4.1.0.** Mendukung renderer widget offline di Linux
dan iOS. API cukup untuk QR hitam-putih sederhana. Kekurangannya, rilis stabil
ini relatif lama dan memakai generasi `qr` 3.x, sehingga kompatibilitas harus
dibuktikan dengan analyzer, test, dan build Flutter project saat integrasi.

**Pilihan B — `pretty_qr_code`.** Juga mendukung Linux/iOS, dengan dekorasi,
tema, dan bentuk yang lebih luas. Kelebihannya fleksibel; kekurangannya API dan
fitur visual tambahan belum diperlukan untuk undangan personal sederhana.

Rekomendasi awal: A. Jangan menulis encoder QR sendiri. Tambahkan hanya generator
terlebih dahulu; pemilihan scanner iOS dilakukan terpisah. QR harus berisi tepat
teks `tagihan-pairing-v1:…` yang sudah ada, dengan kontras tinggi, quiet zone
minimal empat modul, tanpa logo atau dekorasi. Tidak memakai layanan QR online.
Hasil scan harus masuk tahap tinjauan yang sama, tanpa mengirim request otomatis.

Rujukan: [qr_flutter](https://pub.dev/packages/qr_flutter),
[pretty_qr_code](https://pub.dev/packages/pretty_qr_code),
[qr 3.0.2](https://pub.dev/packages/qr/versions/3.0.2), dan
[quiet zone menurut DENSO WAVE](https://www.qrcode.com/en/howto/code.html).

## Bantuan menyiapkan cache dari terminal pengguna

Terminal agent belum dapat me-resolve `pub.dev`, dan kedua paket belum tersedia
di cache. Dari terminal Fedora yang biasa dipakai development, jalankan:

```bash
cd ~/Workspace/Projects/tagihan.app/app
flutter pub cache add qr_flutter --version 4.1.0
flutter pub cache add qr --version 3.0.2
```

Perintah ini hanya mengunduh paket ke cache development. `pubspec.yaml` dan
`pubspec.lock` belum diubah. `qr` 3.0.2 disiapkan untuk dependency `qr_flutter`
4.1.0; jangan menggantinya dengan major terbaru tanpa memeriksa constraint.
Setelah hasilnya tersedia, integrasi generator dapat dilanjutkan dengan resolver
dependency dan pemeriksaan penuh. Jangan commit dependency atau menandai QR
PASS sebelum integrasinya selesai diuji.

Review manual alur saat ini: [dua replica Fedora](api/pairing-client-review.md).
Keychain, permission kamera/Local Network, TLS native, dan scan iPhone tetap
memerlukan persiapan tersendiri serta build/pengujian macOS/Xcode. Pengujian widget
Fedora tidak membuktikan keberhasilan fitur native iPhone.
