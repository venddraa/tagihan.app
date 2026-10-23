# Pengujian API lokal dengan autentikasi

Tahap 18B memakai dua listener loopback. SQLite hub tetap schema versi 2 dan
protocol version tetap 1. Seluruh contoh berikut untuk data dummy.

| Tujuan | Alamat | Credential |
| --- | --- | --- |
| Health | `http://127.0.0.1:8787/v1/health` | Tidak perlu |
| Push/pull | `http://127.0.0.1:8787/v1/sync/...` | Token perangkat |
| Bootstrap | `http://127.0.0.1:8788/v1/sync/bootstrap` | Token admin |
| Registry/revoke | `http://127.0.0.1:8788/v1/admin/devices` | Token admin |

## Menjalankan service dan aplikasi Fedora

1. Hentikan `go run` versi lama dengan Ctrl+C pada terminal yang menjalankannya.
   Jangan menjalankan dua service pada port yang sama.
2. Jalankan versi baru:

   ```bash
   cd ~/Workspace/Projects/tagihan.app/sync
   go run ./cmd/tagihan-sync
   ```

3. Service membuat `admin.token` di direktori data lokal
   `$XDG_DATA_HOME/tagihan-vendra/sync/`, atau
   `$HOME/.local/share/tagihan-vendra/sync/` jika `XDG_DATA_HOME` kosong.
   Tidak ada token yang dicetak ke log. Directory harus berizin 0700 dan file 0600.
4. Pada terminal berbeda jalankan aplikasi terbaru:

   ```bash
   cd ~/Workspace/Projects/tagihan.app/app
   flutter run -d linux
   ```

5. Buka **Pengaturan → Sinkronkan sekarang**. Aplikasi membaca credential admin,
   menyimpan token perangkat di keyring, mendaftarkan Fedora, lalu sync.
   Jika keyring meminta unlock, buka keyring login memakai dialog sistem.
   Pengujian keyring/dialog native harus dilakukan pada desktop Fedora asli.

Jika `secret-tool` tidak tersedia pada instalasi Fedora lain, tool berasal dari
paket `libsecret`. Project tidak memasangnya otomatis. Tidak ada fallback yang
menaruh token perangkat di SQLite atau file plaintext.

Jika memakai port atau path custom, sesuaikan flag Go `--listen`, `--admin-listen`,
dan `--admin-token-file`, serta Flutter `--dart-define=TAGIHAN_SYNC_URL=...`,
`--dart-define=TAGIHAN_SYNC_ADMIN_URL=...`, dan
`--dart-define=TAGIHAN_SYNC_ADMIN_TOKEN_FILE=...`. Semua listener tetap loopback.
Lokasi token admin default mengikuti direktori data default, bukan flag
`--database`; gunakan `--admin-token-file` jika ingin mengubah lokasinya.

## Menyiapkan Postman

1. Import ulang `docs/api/openapi.yaml` melalui **Import → Files**. Kontrak versi
   0.5.0 berisi security scheme dan listener admin terpisah.
2. Siapkan variabel alamat biasa: `baseUrl = http://127.0.0.1:8787` dan
   `adminUrl = http://127.0.0.1:8788`.
3. Buka **Postman Local Vault** dan simpan secret `tagihan-admin-token` dari file
   `admin.token`. Gunakan Local Vault di komputer ini, bukan shared vault.
   Untuk membaca sendiri token tersebut di terminal:

   ```bash
   cat "${XDG_DATA_HOME:-$HOME/.local/share}/tagihan-vendra/sync/admin.token"
   ```

   Jangan tempel nilai tersebut ke chat, screenshot, Git, atau variabel shared.
   Salin tokennya saja, tanpa teks prompt terminal.
4. Buat token perangkat dummy terpisah menggunakan sumber random kriptografis.
   Jika OpenSSL tersedia, command berikut menghasilkan token base64url 43 karakter:

   ```bash
   openssl rand -base64 32 | tr '+/' '-_' | cut -c1-43
   ```

   Simpan hasilnya sebagai secret Local Vault `tagihan-device-token`. Ini khusus
   perangkat dummy Postman, bukan credential Fedora yang ada di keyring.

Referensi Local Vault ditulis `{{vault:nama-secret}}`. Sesuaikan nama menu jika
versi Postman berbeda. Referensi resmi:
[penggunaan vault secrets](https://learning.postman.com/docs/use/postman-vault/use-vault-secrets).

## Registrasi perangkat dummy

Buat request **POST** ke `{{adminUrl}}/v1/admin/devices`.
Di tab **Authorization**, pilih **Bearer Token** dan isi
`{{vault:tagihan-admin-token}}` tanpa menambahkan kata `Bearer` lagi.
Di **Body → raw → JSON**, isi:

```json
{
  "protocol_version": 1,
  "device_id": "0199e7d0-0000-7000-8000-000000000090",
  "name": "Postman lokal",
  "credential": "{{vault:tagihan-device-token}}"
}
```

Request pertama menghasilkan 201. Retry dengan body sama menghasilkan 200 dan
device yang sama. Response tidak mengandung token ataupun hash credential.

## Memeriksa akses

- **GET** `{{baseUrl}}/v1/health`, Authorization **No Auth**: 200.
- **GET** `{{adminUrl}}/v1/admin/devices`, Bearer admin: 200, berisi metadata device.
- **GET** `{{baseUrl}}/v1/sync/pull?after=0&limit=100`, Bearer
  `{{vault:tagihan-device-token}}`: 200.
- Pull tanpa token atau memakai token admin: 401.
- Push memakai `device_id` yang berbeda dari ID perangkat dummy: 403.
- Bootstrap pada port 8787: 404. Bootstrap hanya ada pada port admin 8788.

## Mencabut perangkat dummy

Buat **POST** ke
`{{adminUrl}}/v1/admin/devices/0199e7d0-0000-7000-8000-000000000090/revoke`,
gunakan Bearer admin, dan kosongkan body. Hasilnya 200. Retry revoke tetap 200.

Ulangi request pull dengan token perangkat dummy: hasilnya sekarang 401.
Retry registrasi token lama menghasilkan 409; tidak mengaktifkan akses kembali.
Gunakan ID baru untuk perangkat dummy berikutnya. Jangan memakai ID perangkat
Fedora asli untuk pengujian revoke. Revoke tidak menghapus data lokal atau hub.

Rotasi/re-pair credential dan pairing iPhone belum tersedia pada tahap ini.
