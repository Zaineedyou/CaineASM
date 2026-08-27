# Discord Interaction Callback Notes

Handler interaksi Gateway CaineASM menggunakan callback HTTP resmi Discord dengan payload dan URL yang dibentuk di NASM.

- Discord menerima interaksi Gateway dan mengharuskan respons awal dikirim melalui HTTP, bukan sebagai perintah pada Gateway.
- Endpoint respons awal adalah `POST /interactions/<interaction_id>/<interaction_token>/callback`.
- Respons awal harus dikirim dalam tiga detik sejak event diterima; token interaksi lalu tidak boleh dicatat atau dipersistenkan.
- Tipe respons `4` adalah respons pesan sumber, dan data pesan dapat membawa flag `EPHEMERAL` bernilai `64`.

Sumber: [Discord Developer Documentation — Receiving and Responding to Interactions](https://docs.discord.com/developers/interactions/receiving-and-responding), bagian “Interaction Callback”, diakses 2026-08-27.
