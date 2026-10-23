# Review hub pairing 18C.1

Checkpoint ini menyediakan sisi hub dan kontrol Fedora. Form penerima undangan,
paired profile, dan integrasi sync client menyusul pada 18C.2. iPhone belum dapat
dipasangkan melalui UI aplikasi pada checkpoint ini; QR/Keychain native tetap 18D.

## Review lokal tanpa membuka LAN

Hentikan service versi lama dengan Ctrl+C pada terminal service, lalu:

```bash
cd ~/Workspace/Projects/tagihan.app/sync
go run ./cmd/tagihan-sync --pairing-listen 127.0.0.1:8789
```

Listener yang berjalan:

- `http://127.0.0.1:8787`: sync lokal bercredential dan health.
- `http://127.0.0.1:8788`: kontrol admin bercredential.
- `https://127.0.0.1:8789`: pairing dan sync bercredential melalui TLS 1.3.

Identity default mengikuti path database: `<database>.tls-identity.json`, yaitu
`hub.sqlite.tls-identity.json` pada direktori data default hub.
File berisi private key dan harus berizin 0600 dalam direktori 0700. Jangan
menyalin file ini ke chat, Postman, atau Git. Sertifikat publik saja dapat dibaca
melalui `GET /v1/admin/pairing`, pada `info.certificate_pem`.

Di terminal lain:

```bash
cd ~/Workspace/Projects/tagihan.app/app
flutter analyze
flutter test
flutter run -d linux
```

1. Buka Pengaturan dan selesaikan **Sinkronkan sekarang** untuk menyiapkan data
   Fedora di hub sebelum perangkat baru mengirim perubahan.
2. Di **Perangkat terhubung**, tekan **Perbarui**. Hub HTTPS harus tampil aktif.
3. Tekan **Hubungkan perangkat**, lalu buka **Teks undangan**. Salin hanya jika
   diperlukan; teks tersebut memuat token rahasia sementara.
4. Tanpa calon perangkat, daftar request tetap kosong. **Batalkan undangan**
   mengakhiri undangan. Undangan baru juga menggantikan sesi yang lama.
5. Jika service dijalankan tanpa `--pairing-listen`, aplikasi menampilkan bahwa
   pairing jaringan belum aktif; fungsi lokal dan sync localhost tetap bekerja.

Undangan loopback pada review ini hanya dapat digunakan dari Fedora tersebut.
Jangan menganggapnya sebagai alamat yang dapat dihubungi iPhone.

## Kontrak API untuk pengujian dummy

Import `docs/api/openapi.yaml` versi 0.6.0 ke Postman. Credential admin tetap
disimpan di Local Vault seperti [panduan autentikasi lokal](local-auth.md).
Endpoint utama:

| Listener | Method dan path | Credential |
| --- | --- | --- |
| Admin | `GET /v1/admin/pairing` | Admin |
| Admin | `POST /v1/admin/pairing/invitations` | Admin |
| Admin | `POST /v1/admin/pairing/invitations/{invitation_id}/cancel` | Admin |
| Admin | `POST /v1/admin/pairing/requests/{request_id}/approve` | Admin |
| Admin | `POST /v1/admin/pairing/requests/{request_id}/reject` | Admin |
| HTTPS | `POST /v1/pairing/requests` | Token undangan |
| HTTPS | `GET /v1/pairing/requests/{request_id}` | Token perangkat pending |
| HTTPS | `GET /v1/pairing/identity` | Token perangkat approved |

Request pengajuan memakai JSON:

```json
{
  "protocol_version": 1,
  "invitation_id": "<id dari undangan>",
  "request_id": "0199e7d0-0000-7000-8000-000000000088",
  "device_id": "0199e7d0-0000-7000-8000-000000000090",
  "name": "Perangkat dummy",
  "credential": "<token random 32 byte baru, base64url tanpa padding>"
}
```

Token perangkat harus disimpan terlebih dahulu agar retry memakai credential,
request ID, dan body yang sama. Token undangan tidak boleh dijadikan token
permanen perangkat. Untuk HTTPS self-signed, client harus mempercayai sertifikat
hub yang diperoleh langsung dari Fedora atau memverifikasi fingerprint-nya.
Jangan menonaktifkan verifikasi TLS secara global. Transport Dart berpinned
sudah tersedia untuk integrasi client pada checkpoint berikutnya.

Setelah dummy mengajukan request, tekan **Perbarui** di Fedora, cocokkan request
ID, lalu pilih Izinkan/Tolak. Credential pending mendapat 401 pada push/pull.
Setelah Izinkan, credential dapat mengakses sync pada listener HTTPS.

Jika persetujuan terganggu setelah database commit, status `approving` meminta
retry Izinkan. Jangan menganggap request sudah ditolak; keputusan yang ambigu
tidak dapat dibatalkan atau diganti dengan undangan baru sebelum dikonfirmasi.
Request biasa berakhir lima menit setelah diterima; proses approval yang sudah
dimulai diselesaikan lewat retry. Device yang sudah approved tetap terdaftar
setelah restart, walau sesi sementara berakhir. Endpoint identity memverifikasi
credential approved untuk recovery dan menolak credential revoked.

## Saat integrasi client siap

Listener dapat dipilih pada IP LAN tertentu, misalnya
`--pairing-listen 192.168.1.10:8789`, sesuai alamat Fedora sendiri. Wildcard,
alamat publik, dan DNS name ditolak; tidak ada perubahan firewall otomatis.
Flag `--pairing-identity-file` tersedia untuk path identity khusus. Listener
HTTP/admin tidak boleh dipindah ke LAN. Jangan menghapus identity untuk mengganti
IP: identitas hub terpisah dari alamat. Mengganti sertifikat atau key memerlukan
verifikasi dan pairing ulang; rotasi otomatis belum diimplementasikan.
