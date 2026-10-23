# Draft protocol sinkronisasi V1

Status: **acuan desain V1 dengan implementasi bertahap**. Fondasi Go hub,
bootstrap, outbox, push/pull, idempotency, deteksi conflict, dan resolusi conflict
sudah tersedia. Registry perangkat Go tersedia pada schema hub versi 2, dan
autentikasi endpoint lokal tersedia pada tahap 18B. Tahap 18C.1 menyediakan hub
HTTPS pairing opt-in dan kontrol Fedora; tahap 18C.2 menyediakan penerima undangan,
secure profile, recovery, serta sync HTTPS berpinned dengan binding cursor.
Adapter Keychain dan pairing iPhone end-to-end belum tersedia.
Bagian delete/tombstone memuat rencana yang belum seluruhnya
diimplementasikan.
Rancangan dan progres pairing ada di [pairing perangkat](device-pairing.md).

## Tujuan

Sinkronisasi mempertemukan perubahan dari database lokal Fedora dan iPhone.
Kedua aplikasi tetap dapat dipakai penuh ketika Go service mati atau jaringan
tidak tersedia. Waktu perangkat tidak dipakai untuk menentukan pemenang konflik.

## Pilihan arsitektur hub

### Pilihan A — hub SQLite terpisah

```text
Flutter Fedora ── SQLite replica ──┐
                                  ├── REST/JSON ── Go sync hub ── hub SQLite
Flutter iPhone ── SQLite replica ──┘
```

Go hub menggunakan SQLite kecil tersendiri untuk operation log, idempotency,
urutan perubahan, dan versi entity terakhir. Hub tidak membuka file SQLite milik
Flutter secara langsung. Flutter Fedora juga diperlakukan sebagai sync client,
sama seperti iPhone.

Kelebihan:

- database Flutter tidak perlu dibuka dan dimigrasikan oleh dua codebase;
- algoritma push/pull Fedora dan iPhone tetap simetris;
- lifecycle Go tidak memengaruhi penggunaan aplikasi lokal;
- hub dapat dibangun ulang dari replica melalui proses recovery yang nanti
  dirancang bersama backup, tanpa menjadikannya satu-satunya tempat data hidup.

Kekurangan:

- ada satu file SQLite tambahan di Fedora;
- perubahan Fedora baru tersedia ke perangkat lain setelah Flutter Fedora
  melakukan push ke hub.

### Pilihan B — Go membuka database Flutter Fedora

Kelebihan:

- hanya ada satu file SQLite di Fedora;
- perubahan Fedora langsung terlihat oleh Go.

Kekurangan:

- schema dan migration yang sama harus dipahami oleh Dart dan Go;
- mutation Fedora sudah terjadi sebelum Go memvalidasi operation sehingga alur
  Fedora dan iPhone menjadi tidak simetris;
- lifecycle, locking, dan perubahan schema lebih erat mengikat kedua aplikasi;
- kesalahan service berisiko menyentuh database utama aplikasi.

### Rekomendasi

Pilih **A**. Tambahan satu database kecil lebih mudah dirawat daripada membuat
dua codebase memiliki dan memigrasikan database aplikasi yang sama.

Hub tetap menjadi coordinator untuk urutan perubahan dan versi yang sudah
diterima. Ini berbeda dari source of truth aplikasi: saat hub tidak tersedia,
data lokal tetap dapat dibaca dan diubah.

## Identitas dan versi

- `entity_id`, `operation_id`, dan `device_id` menggunakan UUIDv7.
- Create memakai `base_version: 0` dan menghasilkan entity version `1`.
- Update atau delete membawa versi terakhir yang sudah diterima dari hub sebagai
  `base_version`.
- Operasi diterima hanya jika `base_version` sama dengan versi entity di hub;
  hasilnya memakai `version = base_version + 1`.
- `created_at` disimpan untuk audit dan tampilan, bukan untuk menentukan urutan
  atau memenangkan conflict.
- Hub memberi setiap perubahan yang diterima sebuah `server_sequence` integer
  yang selalu naik. Cursor pull memakai sequence ini, bukan timestamp.

UUIDv7 tetap cocok karena dapat dibuat offline tanpa registrasi pusat dan sudah
distandardisasi dalam [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562.html).

## Bentuk operation

Setiap mutation lokal menulis perubahan entity dan outbox dalam satu transaksi
SQLite. Bentuk konseptualnya:

```text
protocol_version
operation_id
device_id
entity_type
entity_id
operation_type
base_version
payload
created_at
```

Operation awal yang diperlukan:

- `bill.create`
- `bill.update` termasuk perubahan status dan archive
- `bill.delete` untuk membuat tombstone
- `payment.record`
- `payment.delete` untuk membuat tombstone jika penghapusan pembayaran nanti
  diizinkan

Payload membawa snapshot lengkap, bukan patch per-field. Scope V1 kecil dan
snapshot membuat validasi, replay, serta conflict UI lebih mudah dipahami.

`payment.record` adalah domain operation atomik: satu operation membuat Payment
dan memajukan atau mengarsipkan Bill terkait. Payload-nya membawa
`bill_base_version`. Hub tidak boleh menerima Payment tetapi gagal memperbarui
Bill, atau sebaliknya.

## Penyimpanan client

Selain tabel `bills` dan `payments`, tiap replica nanti membutuhkan:

- `sync_outbox`: operation lokal yang belum selesai;
- `sync_state`: `device_id`, cursor pull terakhir, dan status sync;
- `applied_operations`: mencegah replay perubahan remote;
- `sync_conflicts`: kedua snapshot dan metadata conflict untuk resolusi user.

Tidak ada tabel ini yang ditambahkan pada milestone desain.

## Push

1. Client membaca batch outbox terurut, maksimal 100 operation.
2. Client mengirim batch ke `POST /v1/sync/push`.
3. Hub memeriksa credential device, format, `operation_id`, dan `base_version`.
4. Hub memproses operation berurutan dalam transaksi yang sesuai.
5. Response memberi hasil per operation: `accepted`, `duplicate`, `conflict`,
   atau `rejected`.
6. Client hanya menghapus atau menandai selesai operation yang sudah mendapat
   hasil durable dari hub.

Hub menyimpan hash payload dan hasil untuk setiap `operation_id`. Retry dengan ID
dan payload sama mengembalikan hasil lama tanpa mengulang mutation. ID sama dengan
payload berbeda ditolak sebagai protocol error.

Jika sebuah operation conflict, operation berikutnya untuk entity yang sama
ditahan. Data dan outbox lokal tidak dibuang.

## Pull

1. Client meminta `GET /v1/sync/pull?after=<cursor>&limit=100`.
2. Hub mengembalikan perubahan terurut beserta `next_cursor` dan `has_more`.
3. Client menerapkan satu halaman perubahan dan menyimpan cursor dalam satu
   transaksi lokal.
4. Jika aplikasi mati sebelum commit, halaman yang sama aman diputar ulang.
5. Pull dilanjutkan sampai `has_more` bernilai false.

Pola changes feed, sequence, batch, dan checkpoint ini mengambil pelajaran dari
[CouchDB replication protocol](https://docs.couchdb.org/en/stable/replication/protocol.html),
tetapi Tagihan Vendra tidak mencoba menjadi implementasi CouchDB.

## Bootstrap data yang sudah ada

Saat sync pertama kali diaktifkan, database Fedora mungkin sudah berisi tagihan
dan pembayaran yang dibuat sebelum outbox tersedia. Data tersebut tidak boleh
direkayasa menjadi rangkaian `payment.record`, karena replay riwayat dapat
memajukan jatuh tempo untuk kedua kalinya.

Rekomendasi bootstrap:

1. Hub yang masih kosong menerima snapshot awal dari Fedora melalui proses
   bootstrap khusus di localhost.
2. Bills dimasukkan lebih dahulu, lalu Payments sebagai historical snapshot tanpa
   menjalankan side effect pembayaran.
3. Hub menulis semuanya ke change log sehingga device baru dapat melakukan full
   pull dari cursor `0`.
4. Record iPhone yang dibuat mandiri dan memiliki ID berbeda tetap dapat masuk
   sebagai create biasa. ID sama dengan isi berbeda menjadi conflict.
5. Bootstrap hanya boleh berhasil sekali pada hub kosong dan harus aman diulang
   setelah timeout memakai satu bootstrap operation ID.

Detail apakah versi lama dipertahankan atau dinormalisasi akan dikunci bersama
schema hub pada Milestone 12. Rekomendasi awalnya mempertahankan version yang ada
agar tidak menurunkan versi record lokal.

## Conflict

Conflict terjadi ketika:

- `base_version` operation tidak sama dengan versi entity di hub; atau
- client menerima perubahan remote untuk entity yang masih memiliki perubahan
  lokal tertunda.

Hub atau client menyimpan dua sisi secara eksplisit: snapshot lokal yang diajukan
dan snapshot terbaru dari hub. Tidak ada last-write-wins.

Resolusi user membuat operation baru berdasarkan versi hub terbaru:

- **Gunakan Fedora/iPhone ini**: kirim snapshot pilihan lokal sebagai update baru;
- **Gunakan perangkat lain**: terapkan snapshot hub dan batalkan rantai operation
  lokal yang sudah digantikan.

Conflict pada `payment.record` tidak boleh menggandakan pembayaran. Payment ID
tetap dipertahankan; operation hasil rebase memakai ID baru karena operation ID
lama sudah tercatat idempotent sebagai conflict di hub.

Client mengelompokkan conflict berdasarkan operation ID dan menyelesaikan satu
kelompok dalam satu transaksi SQLite. Memilih versi hub membatalkan operation
lokal yang terdampak lalu menerapkan seluruh snapshot remote. Memilih versi
perangkat menerapkan snapshot remote sebagai base, kemudian membuat operation ID
baru untuk replay perubahan lokal. `payment.record` direbase terhadap versi Bill
hub; jika periode yang sama sudah dimajukan oleh perangkat lain, Bill tidak
dimajukan untuk kedua kalinya.

## Delete dan tombstone

Archive adalah perubahan status, bukan delete. Delete menghasilkan tombstone
dengan `deleted_at` dan version baru. Tombstone ikut change log dan pull seperti
perubahan lain. Tidak ada garbage collection tombstone pada V1 sync.

Jika satu perangkat mengedit entity yang sudah menjadi tombstone di hub, hasilnya
conflict, bukan menghidupkan kembali entity secara diam-diam.

## HTTP API dan dokumentasi

Endpoint awal:

```text
GET  /v1/health
POST /v1/sync/bootstrap
POST /v1/sync/push
GET  /v1/sync/pull?after=<sequence>&limit=<jumlah>
```

API memakai JSON dan version prefix `/v1`. Kontrak formal nanti disimpan sebagai
`docs/api/openapi.yaml` menggunakan OpenAPI 3.1. File tersebut menjadi sumber
dokumentasi dan dapat langsung di-import ke Postman. Daftar versi spesifikasi
resmi tersedia di [OpenAPI Initiative](https://spec.openapis.org/oas/).

Supabase tidak digunakan. Go service dibuat dengan `net/http` selama kebutuhannya
masih sederhana. Log boleh memuat operation ID, device ID, entity type, status,
dan durasi, tetapi tidak nominal atau notes finansial.

## Keamanan dan urutan implementasi

Sebelum pairing tersedia, Go service hanya boleh bind ke `127.0.0.1` untuk test
lokal. Service tidak boleh diekspos ke LAN tanpa autentikasi device. Pada
milestone pairing, credential, revoke, dan perlindungan transport dibahas khusus.

Karena itu pengujian protocol lokal dapat dilakukan pada milestone 12–17, tetapi
sync dengan iPhone fisik melalui LAN baru diaktifkan setelah pairing minimum aman.

## Skenario wajib diuji

- retry operation yang sama tidak menggandakan pembayaran;
- operation ID sama dengan payload berbeda ditolak;
- dua edit dari base version sama menghasilkan conflict;
- create Bill dan `payment.record` bekerja setelah restart;
- putus setelah hub commit tetapi sebelum response aman untuk retry;
- putus saat pull mengulang halaman tanpa duplikasi;
- delete versus edit menghasilkan conflict;
- operation Payment tidak diterima sebelum Bill terkait tersedia;
- cursor hanya maju setelah transaksi lokal berhasil;
- hub mati tidak menghalangi CRUD lokal.

## Koreksi roadmap yang direkomendasikan

- Milestone 12: Go hub foundation, hub SQLite, health endpoint, dan OpenAPI;
- Milestone 13: migration outbox Flutter dan push changes;
- Milestone 14: pull changes dan cursor;
- Milestone 15: idempotency serta simulasi timeout;
- Milestone 16: conflict detection;
- Milestone 17: conflict resolution UI;
- Milestone 18: pairing, credential, revoke, dan keamanan transport;
- sesudah Milestone 18: baru uji sync LAN dengan iPhone fisik.

## Keputusan yang memerlukan persetujuan

1. Hub memakai SQLite terpisah dan Fedora Flutter menjadi client simetris.
2. Snapshot lengkap dipakai sebagai payload V1.
3. `payment.record` diperlakukan sebagai operation atomik lintas Payment dan Bill.
4. Cursor memakai `server_sequence`, bukan jam perangkat.
5. Network listener tetap localhost sampai pairing minimum selesai.
6. OpenAPI 3.1 menjadi kontrak API dan di-import ke Postman.
7. Data Fedora yang sudah ada masuk melalui bootstrap snapshot satu kali, bukan
   replay riwayat mutation.

