# Scanner QR iPhone

Halaman **Pindai QR undangan** memakai `mobile_scanner` 7.4.2 dan hanya tersedia
di app iPhone. Fedora tetap memakai **Salin undangan**. Scanner hanya menerima
barcode QR yang dapat diparse sebagai `tagihan-pairing-v1`; payload lain tidak
dibuka sebagai URL, tidak dicatat ke log, dan tidak ditampilkan kembali.

Setelah satu undangan valid terbaca, kamera dihentikan lebih dulu lalu app membuka
tinjauan offline. Alamat hub, Hub ID, fingerprint, dan masa berlaku masih harus
ditinjau. Keychain dan jaringan baru digunakan setelah user menekan **Kirim
permintaan pairing**. Beberapa undangan berbeda dalam satu frame ditolak untuk
menghindari pilihan diam-diam.

## Lifecycle dan privasi

- Controller memakai kamera belakang, hanya format QR, dan tidak meminta image
  frame dikembalikan ke Dart.
- App tidak meminta akses Photos atau microphone dan tidak memakai decoder online.
- `NSCameraUsageDescription` menjelaskan bahwa kamera dipakai untuk QR pairing.
- Ketika app tidak aktif, kamera dihentikan. Setelah kembali, kamera tidak mulai
  otomatis; tekan **Mulai kamera**. Ini juga berlaku setelah prompt izin kamera.
- Tombol kembali dan **Gunakan teks undangan** tetap tersedia. Start yang selesai
  terlambat setelah halaman ditutup akan langsung dihentikan sebelum controller
  dilepas.
- Detail error native tidak ditampilkan. Izin ditolak dapat diubah lewat
  **Settings iPhone → Privacy & Security → Camera → Tagihan Vendra**.

## Batas verifikasi

Test Fedora memakai platform kamera palsu untuk memeriksa payload asing/ganda,
izin ditolak, retry manual, background/resume, stop terlambat, tombol kembali,
dan integrasi tinjauan tanpa request jaringan. Ini tidak membuktikan AVFoundation,
prompt permission, signing, atau kamera iPhone fisik.

Saat Mac/Xcode tersedia, jalankan test Flutter lalu install ke iPhone. Buat
undangan Fedora dengan listener pada IP private LAN (bukan `127.0.0.1`), scan QR,
cocokkan identitas yang tampil, dan pastikan request baru muncul di Fedora hanya
setelah tombol kirim ditekan. Uji juga izin ditolak, background saat kamera aktif,
kembali dari halaman, QR asing, serta fallback tempel teks. Jangan merekam atau
membagikan QR undangan aktif dalam laporan.
