# Rancangan pairing perangkat V1

Status: **rancangan disetujui untuk implementasi bertahap**. Registry storage Go
pada tahap 18A dan autentikasi lokal pada 18B sudah tersedia. Pairing iPhone
dan TLS LAN belum diaktifkan; bagian-bagian berikut menjelaskan perilaku yang dituju.

## Tujuan dan batas tahap ini

Mengizinkan iPhone menghubungi sync hub Fedora melalui jaringan lokal dengan
persetujuan pemilik Fedora. Seluruh fungsi lokal tetap bekerja tanpa pairing.
Satu aplikasi menggunakan satu hub pada V1; penggabungan beberapa hub ditunda.

Implementasi saat ini tetap localhost. Belum ada endpoint pairing iPhone,
dependency Flutter baru, atau perubahan pengaturan firewall.

## Status implementasi 18A

- Schema SQLite hub naik dari versi 1 ke 2 dengan tabel `devices`.
- Registry menyimpan UUIDv7, nama, hash SHA-256 credential, waktu registrasi,
  dan waktu pencabutan. Token mentah tidak disimpan atau dikembalikan sebagai
  metadata perangkat.
- Credential memakai encoding base64url canonical tanpa padding dari 32 byte
  acak. Hash dihitung dari 32 byte hasil decoding, bukan teks encoding-nya.
- Operasi storage: register, list, authenticate, dan revoke. Registrasi dengan
  ID atau credential yang sudah dipakai ditolak, termasuk perangkat revoked.
- Revoke idempotent mempertahankan waktu pencabutan pertama dan bertahan setelah
  database dibuka ulang. Tidak ada API untuk mengaktifkan ulang atau mengganti
  credential secara diam-diam.
- Migration mempertahankan operation, snapshot, change log, dan protocol version.
  ID perangkat dalam operation lama tidak otomatis menjadi perangkat tepercaya.
- Registry menjadi dasar autentikasi endpoint sejak implementasi 18B berikut.

Setelah Go service direstart dengan kode baru, `GET /v1/health` melaporkan
`database_schema_version: 2`, sedangkan `protocol_version` tetap `1`.
Binary service lama dengan schema version 1 tidak dapat membuka database hub yang sudah dimigrasikan;
rollback binary memerlukan backup hub yang cocok, bukan penghapusan database.

## Status implementasi 18B

- Listener sync `127.0.0.1:8787` menyediakan health tanpa autentikasi dan push/pull
  dengan token perangkat. Body push wajib cocok dengan device_id milik token.
- Listener admin `127.0.0.1:8788` menyediakan bootstrap, registrasi, daftar, dan
  revoke perangkat dengan token admin terpisah. Rute admin tidak dipasang pada
  listener sync. Kedua alamat tetap diwajibkan loopback oleh command Go.
- Go membuat `admin.token` secara atomik di direktori hub, dengan permission
  direktori 0700 dan file 0600. Token yang sudah ada tidak diganti diam-diam.
  File rusak, symlink, atau permission tidak aman menyebabkan startup gagal.
- Registrasi identik aman diulang; retry berbeda, credential revoked, dan token
  perangkat yang sama dengan token admin ditolak.
- Fedora menyimpan token perangkat lewat `/usr/bin/secret-tool` ke Secret Service
  keyring. Tool tersebut sudah tersedia di environment Fedora project ini dari
  paket `libsecret`. Token dikirim lewat stdin, tidak lewat argumen proses.
- Flutter mempersiapkan akses hanya saat tombol sync ditekan. Token disimpan ke
  keyring sebelum registrasi sehingga timeout aman diulang. Pembacaan keyring
  gagal tidak dialihkan ke file biasa atau SQLite.
- Bootstrap dikirim ke listener admin; push/pull memakai credential perangkat.
  Redirect dan proxy dinonaktifkan pada transport lokal. Target non-loopback
  ditolak sebelum membaca atau mengirim credential, sampai transport pairing siap.
- Response 401/403 tampil sebagai kegagalan credential, bukan status hub offline.
  Outbox, cursor, serta snapshot bootstrap tidak ditandai selesai saat ditolak.

Belum ada instalasi plugin secure storage Flutter. Adapter Keychain iOS dan
dukungan re-pair/rotasi credential tetap tahap berikutnya. Jika credential Fedora
dicabut lewat admin, aplikasi tidak otomatis mendaftarkan token pengganti.
Permintaan yang masuk setelah revoke ditolak; request yang telah lolos autentikasi
sebelumnya dapat selesai. Revoke tidak membatalkan transaksi yang sedang berjalan.

Panduan menjalankan versi ini dan menguji API ada di
[pengujian API lokal](api/local-auth.md).

## Alur yang diusulkan

1. Fedora: buka **Pengaturan → Perangkat → Hubungkan perangkat**.
2. Hub membuat undangan yang berlaku lima menit. Fedora menampilkan QR dan teks
   undangan yang sama. Hanya ada satu undangan aktif dalam satu waktu.
3. iPhone: pilih **Hubungkan ke Fedora**, scan QR atau tempel teks undangan.
4. Aplikasi memverifikasi identitas TLS hub sebelum mengirim undangan atau token.
5. iPhone mengirim permintaan dan menampilkan **Menunggu izin di Fedora**.
6. Fedora menampilkan nama perangkat serta identitas permintaan dengan tombol
   **Izinkan** dan **Tolak**. Nama perangkat hanya label, bukan bukti identitas.
7. Setelah diizinkan, iPhone menampilkan **Terhubung**. Sync pertama tetap
   dimulai lewat tombol **Sinkronkan sekarang** yang sudah tersedia.

Undangan hanya menerima satu calon perangkat. Jika permintaan ditolak atau
dibatalkan, undangan tersebut berakhir dan pairing berikutnya memakai undangan
baru. Perangkat dengan token berstatus pending belum boleh push atau pull.

## Undangan dan identitas hub

Isi QR dan teks undangan membawa versi format, `hub_id`, alamat HTTPS, fingerprint
SHA-256 sertifikat hub, token undangan acak, dan waktu kedaluwarsa.
`hub_id` menggunakan UUID dan disimpan stabil oleh Go hub.

Token undangan berisi 32 byte dari sumber random kriptografis. Teks undangan
adalah representasi lengkap payload, sehingga bisa panjang. Kode enam digit
saja tidak membawa identitas TLS hub; dukungan kode pendek memerlukan desain
verifikasi tambahan dan ditunda. QR membantu menghindari pengetikan panjang.

Fingerprint dan token dipercaya karena dipindahkan langsung dari tampilan Fedora
yang dipercaya. Foto QR atau teks undangan diperlakukan sebagai rahasia sementara.
Undangan tidak berisi tagihan, credential admin, atau token permanen perangkat.

## HTTPS dan perubahan alamat

Usulan transport adalah HTTPS dengan sertifikat lokal dan certificate pinning.
Go menggunakan `crypto/tls` dan `crypto/x509`. Flutter memverifikasi fingerprint
sertifikat terhadap undangan, lalu terhadap pin yang tersimpan setelah pairing.
Verifikasi harus selesai sebelum header autentikasi atau data dikirim, pada
setiap koneksi termasuk koneksi baru setelah restart. Jangan memakai callback
yang menerima semua sertifikat atau mengikuti redirect ke host lain.

Sertifikat berbeda menghasilkan pesan untuk memverifikasi dan melakukan pairing
ulang. Pin tidak diperbarui diam-diam. Sertifikat kedaluwarsa juga ditolak;
pembaruan sertifikat pada V1 memerlukan pairing ulang. Private key hub disimpan
lokal dengan permission ketat dan tidak ikut portable export data tagihan.

Alamat IP adalah lokasi hub, bukan identitasnya. Jika IP Fedora berubah,
alamat bisa diperbarui dengan tetap memverifikasi pin dan `hub_id` yang lama.
Auto-discovery, Bonjour, akses internet, dan VPN ditunda.

## Credential perangkat dan retry

UUID `device_id` yang sudah ada tetap dipakai; UUID bukan credential.
Client membuat token perangkat acak 32 byte dan `request_id`, lalu menyimpannya
sebagai pairing pending sebelum mengirim permintaan. Pengiriman memakai HTTPS
yang sudah diverifikasi. Hub menyimpan hash SHA-256 token, bukan token mentah.

`request_id`, `device_id`, nama, dan token yang sama dapat dikirim ulang jika
response hilang. Hub mengembalikan permintaan yang sama; pemakaian `request_id`
yang sama dengan isi berbeda ditolak. Undangan yang sudah terpakai hanya dapat
diretry untuk permintaan aslinya, bukan untuk calon perangkat lain.

Client memeriksa status permintaan dengan token pending tersebut. Persetujuan
Fedora mengaktifkan hash credential dalam transaksi. Token sudah dimiliki client,
sehingga timeout setelah persetujuan tidak membutuhkan penerbitan token baru.
Jika request kedaluwarsa atau ditolak, token tersebut tidak pernah aktif.

State awal: `pending → approved | rejected | expired | cancelled`.
Hub memakai waktunya sendiri untuk expiry. Pending request kedaluwarsa lima menit
setelah dibuat, termasuk jika client tidak melakukan polling. Undangan dan
request pending berakhir jika Go service restart; credential perangkat yang
sudah approved tetap tersimpan di SQLite hub.

Setiap request sync memakai `Authorization: Bearer <device_token>`.
Hub memeriksa status credential dan mencocokkan `device_id` pada body push dengan
identitas yang terikat pada credential. Token pending, salah, dan revoked ditolak
sebelum memproses operation atau mengembalikan perubahan. Perbandingan hash
menggunakan operasi constant-time. Token tidak ditempatkan di query URL atau log.

## Kontrol Fedora dan revoke

Kontrol admin hanya tersedia melalui listener loopback terpisah, dengan token
admin lokal. Token admin dibuat oleh service, disimpan di file milik user dengan
permission `0600` dalam direktori `0700`, dan dibaca aplikasi Fedora user tersebut.
Loopback tanpa autentikasi tidak cukup untuk mengizinkan atau mencabut perangkat.
Proses lain dengan akses penuh ke akun OS yang sama berada dalam batas kepercayaan
yang sama; rancangan ini tidak mengisolasi akun OS yang sudah disusupi.

Rute admin tidak dipasang pada listener LAN. Bootstrap snapshot juga tetap
admin-only di loopback. Fedora mendapatkan credential sync sendiri melalui
kontrol lokal, lalu memakai alur push/pull yang sama dengan iPhone.

**Cabut akses** menulis `revoked_at` dan menginvalidasi token secara durable.
Request berikutnya ditolak; transaksi yang telah commit sebelum revoke tidak
dibatalkan. Data lokal iPhone, outbox, dan data hub tetap ada. Revoke tidak dapat
menghapus salinan yang sudah tersimpan di iPhone.

Pairing ulang dengan `device_id` yang sudah dikenal membutuhkan persetujuan
admin eksplisit untuk mengganti credential. Token lama tetap invalid dan tidak
boleh aktif kembali karena replay request pairing lama. Tidak ada penggantian
credential diam-diam ketika ID perangkat bertabrakan.

## Penyimpanan client dan dependency

Pada 18B, Fedora menggunakan Secret Service lewat `secret-tool` yang sudah ada,
sehingga tidak memerlukan plugin atau development header baru. Keychain pada iOS
direncanakan lewat `flutter_secure_storage`. Konfigurasi iOS harus device-only serta
tidak memakai sinkronisasi iCloud. Tidak perlu biometric prompt pada setiap sync.
Jika secure storage terkunci atau gagal, sync dihentikan dengan pesan yang jelas;
credential tidak dialihkan ke SQLite biasa. CRUD lokal tetap dapat digunakan.

`hub_id`, alamat, dan pin boleh disimpan sebagai konfigurasi biasa. Token perangkat
tidak masuk database finansial, backup/export tagihan, Git, log, atau koleksi
Postman yang dibagikan. Credential admin Fedora tetap terpisah dari token sync.

Dependency yang diusulkan untuk direview sebelum instalasi:

- Go: standard library untuk random, hash, TLS, dan HTTP; SQLite yang sudah ada.
- Flutter: `flutter_secure_storage` untuk token dan `crypto` untuk SHA-256 pin.
- Generator QR dan scanner kamera dipilih terpisah; alur tempel teks dibuat dulu
  supaya transport dan persetujuan dapat diuji tanpa menambah plugin kamera.

## Pembagian implementasi setelah desain disetujui

1. **18A — registry perangkat:** schema hub, hash credential, revoke, dan test
   storage. Belum mengubah kewajiban autentikasi endpoint yang sudah dipakai.
2. **18B — autentikasi lokal:** kontrol admin, pengamanan bootstrap/push/pull,
   serta credential Fedora dan integrasinya ke coordinator menggunakan secure
   storage. Postman diperbarui bersamaan. Listener tetap loopback.
3. **18C — pairing dan transport:** HTTPS, undangan, request, persetujuan, expiry,
   retry, form tempel undangan, serta daftar perangkat dengan Izinkan/Tolak/Cabut.
   Listener LAN hanya opt-in setelah seluruh pengamanan siap; rute admin tetap
   loopback.
4. **18D — QR dan pengujian perangkat:** pilih plugin, implementasi QR/scan,
   dan pengujian native iOS ketika toolchain Mac tersedia.

OpenAPI dan contoh Postman diperbarui bersama endpoint yang benar-benar sudah
diimplementasikan. Service harus memberi body size limit, timeout, dan rate limit
pada pairing; batas request diatur per alamat sumber dan secara global, bukan
berdasarkan header forwarding dari client. Tidak ada CORS wildcard untuk admin.

## Verifikasi yang diperlukan

- Sync tanpa credential, dengan credential perangkat lain, pending, atau revoked
  ditolak; retry operation yang valid tetap idempotent.
- Undangan expired, replay, calon kedua, dan perubahan payload retry ditolak.
- Persetujuan, penolakan, dan revoke aman terhadap request bersamaan dan restart.
- Response hilang setelah permintaan atau persetujuan dapat diretry.
- Sertifikat salah/kedaluwarsa, redirect, serta perubahan IP diuji sebelum ada
  credential atau data finansial yang terkirim.
- Keberadaan credential tidak membuat endpoint admin dapat diakses lewat LAN.
- Gagal membaca secure storage tidak merusak database atau outbox.
- Fedora dan iPhone tetap bisa CRUD offline setelah akses dicabut.

Pengujian Go, database, dan widget dapat dilakukan di Fedora. Izin Local Network,
Keychain, kamera, TLS native, signing, dan sync pada iPhone fisik memerlukan build
iOS dengan macOS/Xcode. Hasil pengujian Linux tidak membuktikan bagian native iOS.

## Rujukan

- [Go crypto/rand](https://pkg.go.dev/crypto/rand) dan
  [Dart Random.secure](https://api.dart.dev/dart-math/Random/Random.secure.html).
- [Dart SecureSocket.connect](https://api.dart.dev/dart-io/SecureSocket/connect.html)
  dan [HttpClient.connectionFactory](https://api.dart.dev/dart-io/HttpClient/connectionFactory.html).
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) dan
  [crypto](https://pub.dev/packages/crypto).
- [Apple Local Network usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription).
- [Apple device-only Keychain accessibility](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly).
