# CaineASM

**CaineASM** adalah port Discord bot CaineGO yang dominan NASM untuk Linux x86-64. Repositori ini sengaja **menghapus seluruh fitur bridge Minecraft–Discord**. Tidak ada runtime Minecraft, endpoint bridge, token bridge, relay chat, maupun command konfigurasi bridge.

| Batas tanggung jawab | Implementasi |
|---|---|
| Lifecycle proses, environment, Gateway state machine, JSON bounded, command policy, AFK, XP, dan payload aplikasi | **NASM x86-64** |
| TLS, CA certificate chain, hostname verification, DNS, HTTPS, dan WSS frame transport | Adapter C/libcurl yang kecil |
| Go, discordgo, ORM, database client, dan runtime Minecraft | Tidak digunakan |

> Adapter C tidak membuat keputusan bot atau mem-parsing JSON Discord/Groq. Ia hanya menyediakan transport terenkripsi dengan verifikasi TLS aktif.

## Status implementasi

Gateway NASM menerima Hello, mengirim Identify, menyimpan sequence Dispatch, mengatur heartbeat dengan jitter awal, mengecek ACK, memproses READY, menyimpan informasi Resume, serta menangani Reconnect dan Invalid Session. Implementasi mengikuti siklus resmi Discord untuk payload Gateway, heartbeat, sequence, dan resume.[1]

| Fitur | Status saat ini |
|---|---|
| Gateway WSS, Hello, Identify, ACK heartbeat, sequence, READY, Resume | Diimplementasikan dan diuji dengan mock transport NASM |
| Dispatch `MESSAGE_CREATE` | Diimplementasikan untuk filter bot, prefix, command, dan REST reply |
| Command dasar | `help`, `status`, `reset`, `afk`, `afklist`, `rank`, `leaderboard`, dan `summarize` aktif |
| AFK | Set AFK per guild/user, `afklist` guild-scoped, dan clear otomatis saat pengguna berikutnya mengirim pesan; bertahan restart bila `CAINE_STATE_FILE` dikonfigurasi |
| XP/rank | Increment XP per pesan guild, `rank`, dan `leaderboard` guild-scoped; bertahan restart bila `CAINE_STATE_FILE` dikonfigurasi |
| Groq AI | `summarize <text>` membuat Chat Completion non-streaming melalui HTTPS dan parser respons NASM |
| REST Discord | Pengiriman pesan JSON escaped serta route DELETE message yang tervalidasi; policy moderasi belum diaktifkan |
| Moderasi, welcome/goodbye, autorole, interactions, history multi-turn | Belum diimplementasikan |
| Persistence disk | Journal append-only NASM opsional untuk AFK/XP; record checksum-valid di-replay sebelum Gateway berjalan |
| Database client | Tidak digunakan |

Klien Groq membuat request ke endpoint Chat Completions dengan header Bearer, model, dan messages, lalu mengambil `choices[0].message.content` dari respons.[2] Payload user, token Discord di Identify, dan teks reply di-escape sebagai string JSON bounded sebelum dikirim.

## Build dan test lokal

```bash
sudo apt-get install -y nasm build-essential pkg-config libcurl4-openssl-dev
make all
make test
make source-ratio
```

`make test` menjalankan vector test NASM untuk router command, store/AFK, formatter daftar state, journal persistence, replay state AFK/XP, REST Discord, parser JSON, dispatcher, Gateway, Groq, dan XP. Checkpoint saat ini tervalidasi secara lokal dengan mock deterministik dan syscall file aktual; **belum diuji end-to-end memakai token Discord/Groq nyata**.

## Environment

| Variabel | Kegunaan |
|---|---|
| `DISCORD_TOKEN` | Token bot Discord; wajib dan hanya dibaca saat runtime. |
| `GROQ_API_KEY` | API key Groq; wajib dan hanya dibaca saat runtime. |
| `BOT_PREFIX` | Prefix command opsional. Jika kosong/tidak disediakan, default runtime adalah `!`. |
| `CAINE_STATE_FILE` | Path absolut/relatif opsional untuk journal AFK/XP. Jika tidak disediakan, state tetap volatile seperti sebelumnya. |

Bila `CAINE_STATE_FILE` disediakan, bot membuat atau membuka file journal dengan mode `0600`, menolak symlink file akhir, dan memproses hanya record lengkap dengan checksum yang valid. Tail record yang terpotong akibat proses berhenti saat append diabaikan secara aman; journal lengkap tetapi rusak membuat startup gagal agar state tidak dipulihkan secara diam-diam. Journal ini belum melakukan compaction, sehingga operator perlu mengawasi pertumbuhan file pada deployment jangka panjang.

Jangan menyimpan token ke source, image container, commit, atau log. Aktifkan privileged intents yang diperlukan pada aplikasi Discord sebelum deployment; Gateway akan menolak intent privileged yang tidak dikonfigurasi.[1]

## Perilaku command saat ini

| Command | Perilaku |
|---|---|
| `!help` | Menampilkan ringkasan command saat ini. |
| `!status` | Mengonfirmasi jalur Gateway dan REST aktif. |
| `!reset` | Menjelaskan bahwa reset persistence belum tersedia. |
| `!afk [alasan]` | Menyimpan AFK untuk guild dan user pengirim; durable hanya bila `CAINE_STATE_FILE` tersedia. |
| `!afklist` | Menampilkan AFK guild saat ini dengan user ID dan alasan tersanitasi; output dibatasi 2000 byte. |
| `!rank` | Mengirim XP pengirim pada guild tersebut; durable hanya bila `CAINE_STATE_FILE` tersedia. |
| `!leaderboard` | Menampilkan maksimum 20 XP tertinggi pada guild, diurutkan XP menurun lalu user ID secara deterministik; output dibatasi 2000 byte. |
| `!summarize <teks>` | Mengirim teks bounded ke Groq dan membalas hasilnya. |

Formatter daftar state hanya memakai iterator store NASM, memfilter key tepat per guild, serta mengabaikan nilai XP yang bukan desimal `uint32` valid. Nama tampilan Discord tidak digunakan karena checkpoint ini hanya menyimpan user ID dari event `MESSAGE_CREATE`; ini bukan database atau layanan leaderboard lengkap. Jika ruang reply habis, formatter menambahkan penanda truncation dan berhenti sebelum melampaui batas Discord.

Command yang telah diklasifikasikan tetapi belum memiliki handler membalas status yang eksplisit. Ini disengaja agar bot tidak mengklaim melakukan moderasi atau konfigurasi yang belum benar-benar diimplementasikan.

## Container dan deployment

`Dockerfile` membangun NASM dan adapter libcurl langsung. Image deploy tidak memuat Go atau runtime Minecraft. Verifikasi peer dan hostname TLS libcurl tetap aktif untuk HTTPS dan WSS. Docker engine tidak tersedia di sandbox saat checkpoint ini, sehingga build image end-to-end perlu dijalankan oleh CI atau platform deployment.

Bot WebSocket perlu dijalankan sebagai proses yang tetap hidup pada host deployment. Sandbox pengembangan ini tidak dimaksudkan sebagai host produksi jangka panjang. Sebelum deploy, sediakan `DISCORD_TOKEN` dan `GROQ_API_KEY` sebagai environment secret platform, lalu jalankan `make test` dan build image tanpa memasukkan secret.

## Referensi

[1] [Discord Gateway Documentation](https://docs.discord.com/developers/events/gateway)

[2] [Groq API Reference — Create Chat Completion](https://console.groq.com/docs/api-reference)

[3] [libcurl WebSocket Interface](https://curl.se/libcurl/c/libcurl-ws.html)
