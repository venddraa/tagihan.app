# Adapter Keychain iPhone

Adapter Dart menggunakan `flutter_secure_storage` 11.2.0. Store mengikuti OS asli:
Linux memakai `LinuxKeyringCredentialStore`, iOS memakai `IOSKeychainCredentialStore`.
Membuat adapter tidak membaca storage atau jaringan. Platform lain menolak operasi
credential ketika diminta, sementara CRUD lokal tetap dapat digunakan.

## Konfigurasi

- Namespace Keychain: `tagihan-vendra.sync.v1`.
- Key: array JSON `[service, device_id]`, dienkode base64url dengan prefix
  `sync.v1.`. Ini memisahkan service/perangkat tanpa collision delimiter.
  Encoding key bukan enkripsi; secret berada pada value Keychain.
- Setiap operasi memakai `unlocked_this_device` dan `synchronizable: false`.
  Credential hanya dapat diakses saat perangkat terbuka dan kelas akses ini
  tidak memigrasikan item ke perangkat berbeda.
  [Atribut akses Apple](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly).
- Tidak meminta biometrik/Secure Enclave. `groupId` tidak diisi: desain memakai
  private access group default app. Apple menjelaskan bahwa app selalu mempunyai
  group private melalui identifier hasil signing. Karena itu project tidak
  menambahkan group sharing custom.
  [Access group Apple](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps).

Signing dan perilaku plugin native tetap perlu diverifikasi di Mac. Panduan plugin
memuat konfigurasi sharing umum, tetapi app ini tidak memakai App Groups. Jika
Keychain gagal pada perangkat, periksa signed entitlements, Team, Bundle ID, dan
registrasi plugin. Jangan mengganti group/namespace secara acak untuk menutupi
error. [Dokumentasi plugin](https://pub.dev/packages/flutter_secure_storage).

## Durability dan kegagalan

Write diikuti read-back dengan nilai yang persis sama sebelum caller melanjutkan.
Untuk pairing, request ID dan token disimpan sebelum POST pertama. Write gagal
atau diakui tetapi tidak dapat dibaca kembali menghentikan pairing sebelum jaringan.

Item tidak ditemukan menghasilkan `null`. Item kosong, Keychain terkunci,
MissingPlugin, atau response tidak sesuai menghasilkan error sync yang aman.
Detail error native tidak diteruskan ke UI/log. Tiap operasi dibatasi 20 detik,
tanpa retry otomatis. Timeout tidak membatalkan operasi native dan bukan bukti
write belum commit; gunakan **Periksa sesi dan status** untuk membaca sesi yang
sama. Test mencakup response gagal setelah commit dan recovery request/token lama.

Ketika credential gagal dibaca, sync berhenti sebelum identitas hub atau push/pull
dipanggil. Profil, tagihan, outbox, binding, serta cursor dipertahankan. CRUD lokal
tetap tersedia. Tidak ada fallback plaintext, `deleteAll`, reset cursor, unpair,
atau migrasi credential Fedora pada checkpoint ini.

Restore database ke iPhone lain tidak membuat credential device-only ikut ada.
Profil hilang pada database yang sudah terikat memblokir sync; pemulihan lintas
perangkat memerlukan alur eksplisit yang belum dibuat. Uninstall app bukan
pengganti **Cabut akses** pada registry Fedora.

## Jaringan lokal iOS

`Runner/Info.plist` mempunyai `NSLocalNetworkUsageDescription` untuk akses ke
Fedora yang diizinkan. Deskripsi diperlukan juga untuk koneksi langsung ke
alamat lokal. iOS mengendalikan prompt dan izin jaringan lokal.
[Dokumentasi Apple](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription).

Tidak ada discovery Bonjour, exception HTTP global, atau permission kamera baru.
Sync tetap memakai HTTPS dengan pin sertifikat, dimulai saat user meminta pairing
atau sync. Jika Local Network ditolak, ubah izin app di Settings iOS lalu periksa
sesi kembali; penolakan tidak menghapus data lokal.

## Batas verifikasi dan langkah saat Mac tersedia

Test Fedora memakai MethodChannel mock dengan platform iOS yang disimulasikan.
Ini memeriksa opsi plugin, isolasi key, error, read-back, serta integrasi pairing
dan coordinator dengan SQLite. Ini bukan pengujian Apple Keychain, provisioning,
prompt Local Network, atau TLS native iPhone.

Pemeriksaan pada Flutter 3.47.8 / Dart 3.13.7: analyzer PASS, 195 test Flutter PASS
(mode `--experimental-faster-testing` di sesi agent), build Linux release PASS,
Go test/vet PASS, dan sintaks Info.plist PASS. Pengujian native iOS belum dijalankan.

Ikuti [setup iOS](ios-development.md), kemudian di Mac dari folder `app`:

```bash
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --debug
open ios/Runner.xcworkspace
```

Di Xcode pilih **Runner → TARGETS: Runner → Signing & Capabilities**, gunakan
Automatically manage signing dan Team milikmu, lalu pilih iPhone sebagai tujuan
Run. Pertahankan Team dan Bundle ID sesudah pairing. Jangan menambahkan group
sharing tanpa kebutuhan yang direview; konfigurasi ini memakai group default app.

Pada iPhone fisik, periksa:

1. CRUD dalam airplane mode dan setelah app dibuka ulang.
2. Tempel undangan dari listener IP LAN Fedora, tinjau identitas, kirim request,
   cocokkan request ID, lalu Izinkan di Fedora. `127.0.0.1` hanya cocok untuk
   review dua replica laptop, bukan undangan untuk iPhone.
3. Tutup/buka app dan restart iPhone: profil dapat dibaca setelah unlock dan
   sync memakai device ID/credential yang sama.
4. Uji read ketika protected data tidak tersedia lewat integration test native;
   mock Fedora belum membuktikan penolakan Keychain saat iPhone terkunci.
5. Tolak Local Network lalu coba sync: data/outbox tetap ada. Izinkan kembali dan
   lanjutkan sesi, termasuk approval yang durable sebelum Go restart.
6. Cabut akses dari Fedora: request berikutnya ditolak, sementara CRUD tetap bisa.

Catat versi iOS, perangkat, Xcode, dan hasil aktual tanpa token atau JSON profil.
Scanner kamera masih tahap berikutnya; hasil native di atas belum boleh ditandai
PASS berdasarkan pengujian Fedora.
