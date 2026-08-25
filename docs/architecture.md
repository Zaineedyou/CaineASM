# Arsitektur Port CaineGO Assembly-Dominan

## Tujuan

Port ini mempertahankan bot Discord CaineGO tanpa fitur Minecraft–Discord. Semua logika bridge, endpoint WebSocket Minecraft, command `setbridge` dan `bridgestatus`, variabel `BRIDGE_*`, serta penyimpanan `bridge_channel` tidak dibawa ke repositori baru.

## Batas implementasi

| Lapisan | Implementasi | Alasan |
|---|---|---|
| Lifecycle proses, environment, retry, timer, rate limit | NASM x86-64/Linux | Deterministik dan tidak membutuhkan library protokol. |
| State machine Discord Gateway, intents, heartbeat, reconnect, payload Identify/Resume | NASM | Logika aplikasi bot, bukan fungsi keamanan. |
| Routing `MESSAGE_CREATE`, command prefix, role/permission policy, AFK, XP, blacklist, moderation command, welcome/goodbye | NASM | Kebijakan produk dan format payload dapat diimplementasikan langsung. |
| JSON terbatas, formatter Discord, request Groq, parser respons Groq | NASM | Hanya subset skema yang dibutuhkan bot. |
| Storage | File append-only dan indeks in-memory NASM | Menghindari runtime database/ORM; checkpoint pertama menargetkan konfigurasi, history pendek, AFK, XP, warning, blacklist, dan channel disable. |
| TLS, CA chain, hostname verification, DNS, HTTPS dan WSS transport | Adapter C/libcurl kecil | Bagian keamanan dan interoperabilitas yang tidak aman untuk ditulis ulang sembarangan. |

## Perilaku eksternal

Discord Gateway v10 menggunakan WSS. NASM memproses event `Hello`, menyimpan interval heartbeat, mengirim heartbeat dan Identify, menyimpan sequence terbaru, serta melakukan reconnect atau Resume. Adapter hanya membuka WSS tervalidasi dan mengirim/menerima frame.

Groq Chat Completions menggunakan HTTPS. NASM membangun body JSON dan header `Authorization: Bearer`, sementara adapter hanya menjalankan request HTTPS tervalidasi. Rilis awal mempertahankan chat teks; analisis attachment vision disimpan sebagai milestone sesudah parser upload/download teruji.

## Fitur target checkpoint

1. Prefix/mention chat Groq dengan history pendek per channel atau DM.
2. Command reset, help, AFK, rank, leaderboard, blacklist, enable/disable channel, dan status.
3. Welcome/goodbye, auto-role, dan level-up event melalui Gateway + Discord REST.
4. Moderation REST: warn, kick, ban, timeout, clear, lock/unlock, slowmode, nick, dan role; tiap operasi melewati policy permission NASM.
5. Slash command dasar `/info`, `/help`, dan `/healthcheck` melalui Interactions REST.

## Referensi

- Discord Gateway: https://docs.discord.com/developers/events/gateway
- Groq Chat Completions: https://console.groq.com/docs/api-reference
- libcurl WebSocket: https://curl.se/libcurl/c/libcurl-ws.html
