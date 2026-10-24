# Pengembangan iPhone

Target aplikasi tetap Flutter iOS. Development shared code dilakukan di Fedora;
build dan pengujian native iOS memerlukan Mac dengan Xcode.

Adapter credential Keychain dan deskripsi izin Local Network sudah disiapkan.
Pemilihan platform, kebijakan device-only, batas mock Fedora, dan checklist
pengujian native dijelaskan di [adapter Keychain](ios-keychain.md).

## Status Milestone 10

- Target `app/ios` sudah tersedia; display name `Tagihan Vendra`.
- Bundle identifier saat ini `app.tagihan.vendra`.
- Minimum deployment target pada project: iOS 15.0.
- Signing team belum diisi. Konfigurasi signing dilakukan di Mac pemilik akun.
- Domain, perhitungan, UI, dan schema Drift dipakai bersama Linux/iOS.
- Database dibuka lewat `drift_flutter`, di direktori application support dari
  `path_provider`. Path tidak di-hardcode ke home Fedora dan tidak dibagikan
  antarperangkat.
- Form, daftar, dan detail disesuaikan untuk layar kecil, safe area, serta keyboard.
- Widget test memakai ukuran ponsel dan `TargetPlatform.iOS` di host. Ini bukan
  iOS Simulator dan tidak menguji plugin atau binary SQLite iOS.
- Schema, constraint, migration, dan business logic database diuji otomatis.
- Persistence berbasis file juga diuji dengan menutup lalu membuka ulang SQLite;
  tagihan, pembayaran, dan perubahan jatuh tempo harus tetap tersimpan.
- Seluruh pengujian tersebut berjalan di Fedora dengan SQLite native. Build
  Simulator, signing, plugin `path_provider`, dan persistence pada iPhone asli
  belum dapat diverifikasi tanpa Mac/Xcode. Hasil Fedora tidak boleh dicatat
  sebagai hasil pengujian native iPhone.

## Yang dapat dilakukan di Fedora

Dari folder `app`:

```bash
flutter analyze
flutter test
flutter run -d linux
```

Mengecilkan jendela Linux membantu memeriksa layout, tetapi keyboard, safe area,
dan lifecycle iPhone tetap harus diperiksa di Simulator/perangkat asli.
Tidak perlu memasang Android SDK untuk target ini.

## Saat Mac tersedia

1. Install Xcode lewat App Store. Buka Xcode dan selesaikan instalasi komponen
   serta persetujuan lisensi. Di **Xcode → Settings → Components**, pastikan
   runtime iOS Simulator tersedia (nama menu dapat berbeda menurut versi Xcode).
2. Siapkan Flutter stable 3.47.8 / Dart 3.13.7 agar sesuai SDK yang terakhir
   diverifikasi di Fedora. Ini tidak berarti build iOS sudah diuji. Jalankan
   `flutter doctor -v` di Mac dan selesaikan temuan iOS toolchain sesuai
   [panduan resmi Flutter](https://docs.flutter.dev/platform-integration/ios/setup).
   Siapkan CocoaPods jika diminta toolchain/dependency; jangan menjalankan langkah
   instalasi Apple toolchain di Fedora.
3. Buka checkout repository yang sudah berisi commit terbaru. Dari folder `app`:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter build ios --simulator --debug
   ```

4. Di Xcode, pilih **Xcode → Open Developer Tool → Simulator** (atau Device Hub
   pada versi yang menggunakan nama itu). Pilih perangkat iPhone. Dari terminal:

   ```bash
   flutter devices
   flutter run -d <id-simulator-dari-flutter-devices>
   ```

5. Uji alur lokal di bawah. Build Simulator tidak memerlukan signing perangkat
   fisik; keberhasilannya tidak menggantikan tes iPhone asli.

## Menjalankan di iPhone fisik

1. Sambungkan iPhone ke Mac. Unlock iPhone, tekan **Trust/Percayai** ketika
   muncul pertanyaan untuk mempercayai komputer.
2. Di Mac, buka `app/ios/Runner.xcworkspace` dengan Xcode. Pilih project
   **Runner → TARGETS: Runner → Signing & Capabilities**.
3. Aktifkan **Automatically manage signing**. Pilih **Team** akun Apple kamu.
   Bila belum ada akun, buka **Xcode → Settings → Accounts** dan tambahkan akun
   sendiri. Jangan memasukkan credential atau signing key ke Git.
4. Jika bundle identifier ditolak karena sudah digunakan, tentukan identifier
   unik milikmu di Xcode dan review perubahan project sebelum commit.
5. Pilih iPhone sebagai run destination, lalu tekan tombol **Run (▶)**.
6. Jika diminta, di iPhone buka **Settings → Privacy & Security → Developer
   Mode**, aktifkan, restart, lalu konfirmasi. Jika certificate belum dipercaya,
   ikuti instruksi di **Settings → General → VPN & Device Management**.
7. Setelah perangkat terkonfigurasi, jalankan dari folder `app`:

   ```bash
   flutter devices
   flutter run -d <id-iphone>
   ```

Pengujian personal dapat memakai akun Apple personal sesuai batasannya.
Distribusi App Store/TestFlight memiliki persyaratan Apple Developer tersendiri;
belum menjadi scope milestone ini. Detail resmi:
[setup iOS](https://docs.flutter.dev/platform-integration/ios/setup) dan
[build/release iOS](https://docs.flutter.dev/deployment/ios).

## Checklist pengujian native berikutnya

- Buka Ringkasan, Tagihan, Pembayaran, dan Pengaturan; periksa portrait/landscape,
  notch/home indicator, ukuran teks besar, serta keyboard angka.
- Tambah dan edit tagihan; buka date picker dan detail dengan catatan panjang.
- Catat pembayaran; periksa jatuh tempo berikutnya dan riwayat pembayaran.
- Tutup/buka aplikasi dan restart iPhone: data tetap tersimpan.
- Aktifkan airplane mode: seluruh alur lokal di atas tetap berfungsi.
- Archive tagihan: riwayat pembayaran tetap terbaca.

Catat versi iOS, perangkat, versi Xcode, command, dan hasil aktual. Jangan menandai
build, persistence, atau offline iPhone PASS sebelum benar-benar diuji.
