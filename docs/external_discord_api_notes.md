# Rujukan Discord API untuk migrasi moderasi

- Dokumentasi audit log resmi Discord menyatakan aplikasi dapat mengirim header `X-Audit-Log-Reason`; nilainya disimpan sebagai `reason`, mendukung **1–512 karakter UTF-8 yang URL-encoded**. Sumber: <https://docs.discord.com/developers/resources/audit-log>.
- Dokumentasi event Gateway resmi Discord mendeskripsikan `communication_disabled_until` sebagai timestamp ISO-8601 atau `null` pada state anggota. Sumber: <https://docs.discord.com/developers/events/gateway-events>.
- Batas timeout yang digunakan implementasi adalah **28 hari** atau `40.320` menit. Rujukan penemuan: <https://discordjs.guide/legacy/popular-topics/faq>.

Catatan: rujukan ini mendukung kontrak wire API saja. Semua policy, parser, cache, payload, dan timestamp aplikasi tetap di NASM; C hanya membawa transport TLS dan header generik.

- Dokumentasi Discord menyatakan nickname memiliki panjang **1–32 karakter**. Rute nick akan membatasi input lebih ketat pada byte UTF-8 tetap agar tidak ada buffer atau payload tak terbatas. Sumber: <https://docs.discord.com/developers/resources/user>.
