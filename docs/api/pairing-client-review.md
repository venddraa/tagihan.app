# Review penerima undangan pada Fedora

Gunakan dua replica lokal untuk menguji alur penerima sebelum tersedia toolchain
iOS. Ini bukan pengujian Keychain atau koneksi iPhone fisik. Tidak perlu memasang
dependency baru. Keyring login Fedora harus terbuka dan `secret-tool` tersedia.

1. Hentikan Go service lama dengan `Ctrl+C` di terminalnya. Jalankan satu instance
   yang sama, dengan lokasi database hub yang selama ini dipakai, lalu tambahkan
   listener pairing. Dari root repo:

   ```bash
   cd sync
   go run ./cmd/tagihan-sync --pairing-listen 127.0.0.1:8789
   ```

   Jika selama ini menggunakan flag database khusus, pertahankan flag tersebut.
   Jangan menjalankan dua service pada port yang sama. Alamat loopback ini
   khusus review dua replica di laptop, bukan alamat yang dapat diakses iPhone.

2. Buka app Fedora utama di terminal lain:

   ```bash
   cd ~/Workspace/Projects/tagihan.app/app
   flutter run -d linux
   ```

3. Di **Pengaturan**, klik **Sinkronkan sekarang** untuk memastikan data utama
   sudah masuk hub. Di bagian **Perangkat terhubung** klik **Perbarui**, lalu
   **Hubungkan perangkat** dan **Salin undangan**. Cocokkan request ID setelah
   client mengirim permintaan.

4. Jalankan replica client pada terminal ketiga, dengan database **terpisah**:

   ```bash
   cd ~/Workspace/Projects/tagihan.app/app
   flutter run -d linux \
     --dart-define=TAGIHAN_SYNC_ROLE=client \
     --dart-define=TAGIHAN_DATABASE_NAME=tagihan_vendra_client_review
   ```

   Selalu sertakan kedua flag ini untuk membuka kembali replica review.
   Jangan jalankan role client pada database utama yang sudah pernah sync.

5. Pada app client, buka **Pengaturan → Hubungkan ke Fedora**. Isi nama misalnya
   `Client review Fedora`, tempel teks undangan, lalu klik **Kirim permintaan
   pairing**. Status menjadi **Menunggu persetujuan Fedora**. Permintaan maupun
   credential sudah tersimpan sebelum jaringan dihubungi.

6. Kembali ke app utama, perbarui daftar, cocokkan nama serta **request ID** dengan
   client, klik **Izinkan**, dan konfirmasi. Pada client klik **Periksa sesi dan
   status** sampai tampil **Terhubung**. Tekan **Sinkronkan sekarang**. Tagihan dari
   hub seharusnya muncul di replica client.

7. Buat satu tagihan contoh di client. Sync client, kemudian sync app utama. Cek
   tagihan contoh muncul satu kali. Putuskan service dengan `Ctrl+C`: kedua app
   tetap dapat membaca dan mengubah data lokal; sync menampilkan hub tidak
   tersedia. Hidupkan kembali service memakai database dan listener yang sama,
   lalu ulangi sync.

8. Opsional: cabut akses client dari app utama. Sync client berikutnya harus
   ditolak; tagihan lokal tetap ada. Pairing ulang perangkat revoked, pindah hub,
   dan penghapusan profil paired belum didukung. Jangan menghapus database atau
   keyring untuk mencoba memperbaiki conflict.

Undangan berlaku singkat. Jika expired/ditolak, gunakan **Batalkan sesi pairing**
pada client saat hub dapat dihubungi, kemudian buat undangan baru di app utama.
Jika timeout, cukup klik **Periksa sesi dan status**, tanpa membuat identitas baru.
Jika approval sudah terjadi sebelum restart Go, pemeriksaan identitas akan
memulihkan pairing dari registry durable.

Pemeriksaan otomatis sebelum commit:

```bash
cd ~/Workspace/Projects/tagihan.app/app
flutter analyze
flutter test
flutter build linux --release
cd ../sync
go test ./...
go test -race ./...
go vet ./...
go build ./...
```

Pengujian LAN dan iPhone dilanjutkan setelah adapter Keychain, konfigurasi iOS,
serta akses macOS/Xcode siap. IP private hub harus dimasukkan secara eksplisit
ketika listener LAN diaktifkan; alamat tidak dicari atau diperbarui otomatis.
