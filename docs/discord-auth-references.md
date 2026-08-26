# Catatan referensi otorisasi Discord

Dokumentasi resmi Discord yang diperiksa pada 26 Agustus 2026:

- [Gateway Events](https://docs.discord.com/developers/events/gateway-events)
- [Gateway](https://docs.discord.com/developers/events/gateway)
- [Guild Resource](https://docs.discord.com/developers/resources/guild)
- [Permissions](https://docs.discord.com/developers/topics/permissions)

Temuan teknis yang dipakai untuk port CaineGO:

1. Event `MESSAGE_CREATE` menyertakan objek member, tetapi field `user` tidak disertakan pada member yang melekat di event tersebut.
2. Field `permissions` pada Member adalah total izin kanal termasuk overwrite **ketika member dikembalikan pada interaction object**; karena tidak dijamin ada pada `MESSAGE_CREATE`, command teks tidak boleh menganggap field tersebut tersedia.
3. `GUILD_CREATE` menyediakan state guild, termasuk `owner_id` dan daftar role; cache role/owner NASM dipopulasi dari event ini.
4. Permission Discord adalah integer panjang-variabel yang diserialisasi sebagai string dan diperiksa sebagai bitfield. Dokumentasi menjelaskan bahwa permission kanal juga bergantung pada overwrite `@everyone`, role, dan member.
5. Nilai bit yang relevan untuk perilaku sumber CaineGO mencakup `KICK_MEMBERS=0x2`, `BAN_MEMBERS=0x4`, `ADMINISTRATOR=0x8`, `MANAGE_CHANNELS=0x10`, `MANAGE_MESSAGES=0x2000`, `MANAGE_NICKNAMES=0x8000000`, `MANAGE_ROLES=0x10000000`, dan `MODERATE_MEMBERS=0x10000000000`.

Implikasi: cache owner/role hanya merupakan fondasi base permission. Operasi Discord destruktif tidak diaktifkan sampai resolver overwrite kanal dan hierarchy role bot/target diberlakukan di NASM.
