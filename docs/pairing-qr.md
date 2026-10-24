# QR undangan pairing

QR undangan Fedora sudah diimplementasikan dengan `qr_flutter` 4.1.0 dan `qr`
3.0.2 pada lockfile. Scanner kamera belum dibuat. Adapter Keychain disiapkan dan
diuji dengan mock; widget/raster berjalan di Fedora, sementara native iPhone
belum diuji. Lihat [adapter Keychain](ios-keychain.md).

## Generator lokal

- Buka **Pengaturan → Perangkat terhubung → Perbarui → Hubungkan perangkat**,
  kemudian buka bagian **QR undangan**. QR tidak dibuat sebelum bagian itu dibuka.
- Isi QR adalah tepat `invitation.code` yang dipakai oleh **Salin undangan**.
  Tidak ada invitation/request ID baru, layanan QR online, atau request jaringan
  tambahan untuk merendernya.
- Warna QR selalu hitam di atas putih, termasuk ketika app memakai dark theme.
  Error correction memakai M; tidak ada logo/overlay atau dekorasi tambahan.
- Ukuran menyesuaikan lebar konten hingga 432 logical pixel. Modul dipilih dengan
  ukuran logical pixel bulat, dan margin putih empat modul pada semua sisi.
  Jika jendela terlalu sempit, perbesar jendela atau gunakan teks undangan.
- QR mengikuti lifecycle undangan: hilang saat expiry, pembatalan, atau aplikasi
  tidak aktif. Undangan baru memakai widget dengan identitas baru agar tidak
  menampilkan matrix undangan sebelumnya.
- Label pembaca layar menerangkan fungsi QR tanpa membacakan token rahasia.

Untuk review, QR hanya memuat undangan dummy atau undangan dari hub yang kamu
kelola. Jangan unggah QR atau teks undangan aktif ke situs decoder QR.
Scanner bawaan app iPhone belum tersedia; alur pairing yang sudah bisa dipakai
tetap melalui tempel teks dan tinjauan identitas.

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
ini relatif lama dan memakai generasi `qr` 3.x, sehingga kompatibilitas tetap
perlu diperiksa ulang saat SDK/dependency di-upgrade.

**Pilihan B — `pretty_qr_code`.** Juga mendukung Linux/iOS, dengan dekorasi,
tema, dan bentuk yang lebih luas. Kelebihannya fleksibel; kekurangannya API dan
fitur visual tambahan belum diperlukan untuk undangan personal sederhana.

Pilihan implementasi generator: A. Jangan menulis encoder QR sendiri. Pemilihan
scanner iOS dilakukan terpisah. QR harus berisi tepat
teks `tagihan-pairing-v1:…` yang sudah ada, dengan kontras tinggi, quiet zone
minimal empat modul, tanpa logo atau dekorasi. Tidak memakai layanan QR online.
Hasil scan harus masuk tahap tinjauan yang sama, tanpa mengirim request otomatis.

Rujukan: [qr_flutter](https://pub.dev/packages/qr_flutter),
[pretty_qr_code](https://pub.dev/packages/pretty_qr_code),
[qr 3.0.2](https://pub.dev/packages/qr/versions/3.0.2), dan
[quiet zone menurut DENSO WAVE](https://www.qrcode.com/en/howto/code.html).

## Bantuan menyiapkan cache dari terminal pengguna

Kedua paket sudah tersedia di cache Fedora dan dependency project telah
ditambahkan melalui resolver offline, dengan checksum pada lockfile. Jika
menyiapkan cache development pada environment lain, jalankan dari terminal:

```bash
cd ~/Workspace/Projects/tagihan.app/app
flutter pub cache add qr_flutter --version 4.1.0
flutter pub cache add qr --version 3.0.2
```

Perintah cache ini hanya mengunduh paket ke cache development. `qr` 3.0.2 cocok
untuk dependency `qr_flutter` 4.1.0; jangan menggantinya dengan major terbaru
tanpa memeriksa constraint.
Jangan commit dependency atau menandai checkpoint QR PASS sebelum analyzer,
pengujian widget/raster, dan build Linux selesai dengan SDK yang konsisten.

Jika SDK sudah ter-upgrade tetapi pengujian meminta artifact baru, jalankan
`flutter precache --linux`, lalu `flutter doctor -v` dari terminal pengguna yang
memiliki jaringan. Hindari mencampurkan toolchain baru dengan engine lama.

## Hasil pemeriksaan checkpoint

Pada Flutter 3.47.8 / Dart 3.13.7 di Fedora:

- Analyzer Flutter: PASS.
- Flutter test: 183 PASS, memakai mode `--experimental-faster-testing` di sesi
  agent. Termasuk pemeriksaan raster QR pada lebar 264/432/720 logical pixel
  dan device pixel ratio 1/1.5/2, payload matrix, kontras, serta quiet zone.
- Build Linux release: PASS.
- Go test dan vet: PASS; implementasi Go tidak berubah pada checkpoint QR.

Pengujian host juga membuka QR sebelum expiry, pembatalan, dan perpindahan
lifecycle untuk memastikan gambar dihapus bersama undangannya. Review manual
aplikasi desktop dan pemindaian kamera/perangkat fisik belum dicatat PASS.

Review manual alur saat ini: [dua replica Fedora](api/pairing-client-review.md).
Keychain, permission kamera/Local Network, TLS native, dan scan iPhone tetap
memerlukan persiapan tersendiri serta build/pengujian macOS/Xcode. Pengujian widget
Fedora tidak membuktikan keberhasilan fitur native iPhone.
