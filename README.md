# CaineASM

CaineASM adalah port assembly-dominan dari bot Discord [CaineGO](https://github.com/Zaineedyou/CaineGO) untuk Linux x86-64. Port ini tidak menyertakan bridge Minecraft–Discord.

Logika bot ditulis dalam NASM. Adapter C kecil memakai libcurl untuk transport HTTPS dan WSS, termasuk verifikasi TLS.

## Status

**Work in progress.** Build dan vector test tersedia, tetapi test tersebut memeriksa modul secara terpisah. Lolos test tidak membuktikan seluruh alur bot sudah bekerja end-to-end dengan Discord dan Groq, dan bukan jaminan siap produksi.

## Isi repositori

- `src/`: modul NASM untuk Gateway, command routing, interactions, policy guild, parsing, moderation, attachment, AI, dan persistence.
- `adapter/`: bootstrap proses dan adapter transport C/libcurl.
- `tests/`: assembly vector test untuk modul-modul seperti JSON, Gateway, REST, persistence, permissions, dan payload vision.
- [`docs/architecture.md`](docs/architecture.md): pembagian tanggung jawab dan batas implementasi.

## Build dan test

Pada Debian atau Ubuntu, pasang toolchain berikut:

```sh
sudo apt-get update
sudo apt-get install -y build-essential nasm pkg-config libcurl4-openssl-dev
```

Bangun executable dan jalankan vector test:

```sh
make
make test
```

Untuk menjalankan pemeriksaan lokal tambahan, termasuk build, test, dan pengecekan rasio source Assembly:

```sh
bash tests/run-local.sh
```

Executable hasil build berada di `build/caine-asm`.

## Menjalankan

Program memerlukan token bot Discord dan API key Groq dari environment:

```sh
export DISCORD_TOKEN='isi-token-bot-discord'
export GROQ_API_KEY='isi-api-key-groq'
./build/caine-asm
```

Jangan commit token atau API key ke repositori. Program berhenti dengan pesan konfigurasi jika salah satu variabel wajib tersebut tidak tersedia.

## Container

Repositori menyertakan Dockerfile multi-stage:

```sh
docker build -t caineasm .
docker run --rm \
  -e DISCORD_TOKEN="$DISCORD_TOKEN" \
  -e GROQ_API_KEY="$GROQ_API_KEY" \
  caineasm
```

## Lisensi

Repositori ini belum menyertakan file lisensi. Ketentuan penggunaan ulang belum dinyatakan.
