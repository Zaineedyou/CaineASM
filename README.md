# CaineASM

Port **assembly-dominan** dari CaineGO untuk Discord. Repositori ini secara sengaja **tidak memiliki bridge Minecraft–Discord**: tidak ada WebSocket Minecraft, `BRIDGE_TOKEN`, `BRIDGE_PORT`, `setbridge`, `bridgestatus`, maupun `bridge_channel`.

| Komponen | Implementasi |
|---|---|
| Lifecycle bot, parsing environment, Gateway opcode/Hello/Identify/heartbeat, routing command, policy command | NASM x86-64 Linux |
| TLS, CA chain, hostname verification, DNS, HTTPS dan WSS frame transport | Adapter C kecil menggunakan libcurl |
| Go, discordgo, gorilla/websocket, database ORM | Tidak digunakan |

> Adapter C tidak mengambil keputusan bot. Ia hanya membuka transport terenkripsi dan tervalidasi; state machine Discord serta seluruh policy bot tetap di NASM.

## Status checkpoint

Checkpoint awal sudah memiliki bootstrap NASM, konfigurasi token, koneksi WSS Discord Gateway, parser `Hello`, Identify, heartbeat dasar, reconnect dasar, dan router command non-bridge. Router menguji bahwa `setbridge` dan `bridgestatus` sengaja menghasilkan command tidak dikenal.

Fitur CaineGO yang sedang dipindahkan selanjutnya mencakup dispatch `MESSAGE_CREATE`, payload Groq, storage history/XP/AFK, moderation REST, welcome/goodbye, role otomatis, dan interactions. Tidak ada logic Minecraft yang akan ditambahkan kembali.

## Build lokal

```bash
sudo apt-get install -y nasm build-essential pkg-config libcurl4-openssl-dev
make all
make test-commands
make source-ratio
```

## Environment

| Variabel | Kegunaan |
|---|---|
| `DISCORD_TOKEN` | Token aplikasi bot Discord. |
| `GROQ_API_KEY` | Kunci Groq untuk AI chat. |
| `BOT_PREFIX` | Prefix command; default handling akan mengikuti `Caine`. |

## Container

`Dockerfile` membangun NASM dan adapter C/libcurl langsung. Image deploy tidak memuat Go atau runtime Minecraft. TLS tetap menggunakan certificate dan hostname verification aktif melalui libcurl.

## Referensi

- [Discord Gateway documentation](https://docs.discord.com/developers/events/gateway)
- [Groq Chat Completions API](https://console.groq.com/docs/api-reference)
- [libcurl WebSocket interface](https://curl.se/libcurl/c/libcurl-ws.html)
