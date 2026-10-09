# CaineASM

CaineASM adalah port Linux x86-64 dari [CaineGO](https://github.com/Zaineedyou/CaineGO) yang memindahkan logika bot ke NASM. C/libcurl menangani koneksi HTTPS dan WSS. Fitur bridge Minecraft–Discord tidak disertakan.

## Status

Proyek ini masih dikerjakan. `make test` menjalankan vector test untuk modul seperti Gateway, JSON, REST, permissions, persistence, attachments, dan payload vision. Test tersebut berjalan pada modul terpisah. Test itu tidak menghubungkan bot ke Discord atau Groq, jadi belum membuktikan alur end-to-end atau kesiapan produksi.

## Batas kode

- `src/gateway.asm` menangani event Gateway, heartbeat, Identify, Resume, dan reconnect.
- `src/dispatch.asm`, `src/commands.asm`, dan `src/interactions.asm` menangani routing pesan, command, dan interactions.
- `src/guild_*.asm`, `src/channel_permissions.asm`, serta modul state mengelola konfigurasi guild, permissions, dan data bot.
- `src/groq.asm`, `src/attachment_*.asm`, dan `src/vision_payload.asm` menangani request AI serta pemrosesan attachment dan payload vision.
- `adapter/` berisi bootstrap C dan transport libcurl. Validasi sertifikat TLS dan hostname dilakukan libcurl, bukan implementasi TLS buatan proyek ini.
- [`docs/architecture.md`](docs/architecture.md) menjelaskan batas implementasi dan fitur yang masih menjadi target.

## Build dan test

Di Debian atau Ubuntu, pasang NASM, GCC, pkg-config, dan header libcurl:

```sh
sudo apt-get update
sudo apt-get install -y build-essential nasm pkg-config libcurl4-openssl-dev
```

Bangun program dan jalankan test vector:

```sh
make
make test
```

`make` membuat `build/caine-asm`. `make test` tidak memerlukan token Discord atau API key Groq.

Pemeriksaan tambahan yang dipakai repo:

```sh
bash tests/run-local.sh
```

## Menjalankan

Isi kedua variabel wajib berikut dengan kredensial milikmu, lalu jalankan binary:

```sh
export DISCORD_TOKEN='token-bot-discord'
export GROQ_API_KEY='api-key-groq'
./build/caine-asm
```

Jangan masukkan kredensial ke Git. Program berhenti jika salah satu variabel wajib tidak tersedia.

## Docker

Image dapat dibuat dari Dockerfile yang disertakan:

```sh
docker build -t caineasm .
docker run --rm -e DISCORD_TOKEN -e GROQ_API_KEY caineasm
```

Pastikan kedua variabel sudah tersedia di shell sebelum menjalankan container.

## Lisensi

[Lisensi CaineASM](LICENSE) mengizinkan penggunaan terbatas. Lisensi ini tidak mengizinkan modifikasi, pembuatan turunan, atau redistribusi kode maupun binary. Ini bukan lisensi open-source.
