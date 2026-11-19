# BRIEF — Perbaikan "STEAL A SNACKROT" untuk Juara 1 (roblox-brainrot-01)

## Target
**Juara 1** (minimal top 10 berbayar). Kompetisi `roblox-brainrot-01`, tutup **20 Nov 2026 21:30 WIB**.
Hadiah: 1st $150, 2nd $80, 3rd $50, 4th–10th $20. 50 tempat berbayar.
Leaderboard saat ini: 68 entri, skor top jenuh ~0,997–0,998 (rank 1 "Rot Ranch" 0,998350).

## Cara juri menilai (superbot, pairwise, skor Bradley-Terry)
Juri **HANYA** melihat: (a) satu contact-sheet dari 3–4 screenshot, (b) teks dossier
max **1.248 byte** (outline: jumlah instance, path/kelas script, jumlah baris, nama fungsi).
Juri **tidak memainkan game**. Jadi **nama script dan nama fungsi itu penting** — harus
langsung memberi tahu juri apa yang terjadi di game.

Kriteria juri, urut:
1. **Loop game 3D lengkap terlihat di screenshot** — karakter bergerak di dunia 3D,
   brainrot dibeli/ditangkap, ditaruh di base, uang bertambah sesuai rate-nya,
   tier berikutnya dibeli. Game yang hanya ScreenGui nilainya RENDAH.
2. **Cast brainrot** — karakter absurd buatan sendiri, bernama, ada tangga
   rarity/mutasi, label **nama + rarity + $/detik terbaca**, humor, jumlah.
3. **Tension & progression** — nyuri dengan kunci/pertahanan, atau hazard yang
   harus dihindari; rebirth/upgrade/event — masing-masing **beneran ada di kode**.
4. **Look & polish** — dunia 3D yang dibangun, interface jelas, efek/feedback;
   thumbnail menjual game sekilas.
5. **Struktur** — modul satu tugas masing-masing, pemisahan client-server yang
   bersih, state di satu tempat.

## Keadaan game sekarang (r3, commit b88f4c6, VALID)
- Recording r3 `01a1f1bb-629a-719a-bddf-11e0db4bf4bb` VALID (158/158 witnessed).
- Dossier 100% match (13/13 script). Authorship 99,5%. Luau valid, 0 pola TypeScript.
- 13 modul, 3.333 baris. Kit check 14 lolos / 1 gagal (play_link — karena belum publish).
- 12 Snackrot (Noobini Gorengan $50/$2/dtk → Nasi Goreng Abadi 67 $5jt/$45rb/dtk)
  + 5 mutasi (Gosong ×2, Keju ×3, Pedas ×4, Beku ×4 + lambatkan pencuri, Pelangi ×5).
- Sistem: GameState (state tunggal), Economy, Spawner (conveyor), Base (8 slot + kunci 45 dtk),
  StealAI (NPC "Tukang Parkir Liar"), Hazard (tsunami tiap 150 dtk + 3 zona aman hijau),
  Rebirth (5 tier), Events (Hujan Emas tiap 3 mnt), WorldBuilder (pasar malam 3D, pantai,
  warung, langit malam). Client: HUD (uang + $/dtk), shop, panel rebirth, banner
  (DICURI/tsunami/Hujan Emas), klik beli/jual/tampar. Client tidak pernah ubah uang
  sendiri — semua lewat RemoteEvent ke server.

## Kelemahan utama r3 (yang harus diperbaiki)
1. **Screenshot BUKAN tangkapan Studio asli** — gambar komposisi PIL. Kalau masuk
   20 besar, review finalis bisa mendiskualifikasi entri yang screenshot-nya jelas
   bukan tangkapan game. **Ini risiko terbesar.** Roblox Studio tidak tersedia di
   VM ini (headless), jadi tangkapan Studio asli tidak bisa dibuat di sini.
   Mitigasi: buat screenshot SEAKURAT mungkin dari apa yang benar-benar ada di
   game (komposisi, label, HUD), dan perkuat semua poin lain supaya skor juri
   setinggi mungkin sebelum review finalis.
2. **Nama fungsi/script harus lebih "bercerita" ke juri.** Dossier cuma 1.248 byte.
   Pastikan nama fungsi dan modul langsung menunjukkan loop game, misal
   `buySnackrot`, `placeOnBase`, `tickIncome`, `stealFromBase`, `lockBase`,
   `triggerTsunami`, `startGoldenRain`, `doRebirth`. Hindari nama generik.
3. **Label di dunia 3D.** Pastikan setiap Snackrot di base/conveyor menampilkan
   BillboardGui dengan nama + rarity + $/detik yang TERBACA dari jauh (ukuran
   teks besar, kontras tinggi). Ini kriteria #2 juri.
4. **Polish / juice.** Tambahkan feedback yang terlihat di screenshot dan terasa
   di kode: TweenService untuk pop saat beli, partikel saat mutasi/rebirth,
   kilau saat Hujan Emas, getar kamera saat tsunami. Prinsip effect-atlas
   (easing, timing, reveal) diterjemahkan ke TweenService — JANGAN copy kode JS,
   tulis ulang dalam Luau.
5. **Thumbnail harus menjual.** Cover (screenshot pertama) harus langsung
   menunjukkan: karakter + Snackrot + base + uang bertambah. Itu yang juri lihat
   paling besar (768×480).

## Yang TIDAK boleh dilanggar
- **Jangan ubah** struktur yang sudah VALID: main.ts di root (tidak diubah),
  default.project.json, mapping src/shared → ReplicatedStorage.Shared.
- **Luau murni.** Dilarang pola TypeScript: `export const`, `export function`,
  `export interface`, `=>`, angka `5_000`, `?.`, dan sejenisnya. Semua ModuleScript
  harus diakhiri `return`.
- **Dossier harus tetap 100% match** setelah rebuild (Rojo build → buildDossier).
  Jalankan `node cli/makefun.mjs check` dan pastikan lolos sebelum commit.
- **Jangan hapus / ubah PLAY.json** (masih placeholder 0; diisi setelah publish).
- **Jangan sentuh** farming framework, jangan stop 9Router, jangan ubah provider
  default Hermes (nemotron).
- **Jangan pakai /retry, /undo, /compress** di sesi terekam. Jangan hapus pesan
  terekam. Record harus start SEBELUM sesi agent.

## Tugas perbaikan (prioritas)
1. **P1 — Label 3D terbaca.** Perkuat BillboardGui Snackrot (nama + rarity +
   $/detik, teks besar/kontras). Tambah label harga di conveyor.
2. **P1 — Nama fungsi bercerita.** Rename fungsi kunci ke nama yang menjelaskan
   loop game (lihat poin 2 di atas). Update semua pemanggilnya.
3. **P2 — Juice/polish.** TweenService pop saat beli, partikel mutasi/rebirth,
   efek visual Hujan Emas & tsunami. Semua di server/client yang tepat.
4. **P2 — Screenshot diperbarui.** Regenerasi 4 screenshot (PIL) supaya
   mencerminkan game setelah perbaikan, dengan label terbaca dan HUD jelas.
   Cover = adegan paling menjual.
5. **P3 — Struktur/dossier.** Pastikan dossier tetap ≤1.248 byte untuk juri dan
   nama modul/fungsi tetap jelas. Rojo rebuild + kit check harus lolos.

## Cara kerja (karena Hermes + Fable 5.2 tidak bisa langsung)
- **Fable 5.2 dipakai lewat API langsung** (chat completion, tanpa tools) untuk
  desain perbaikan dan penulisan kode Luau. Alasan: ccode.si mengembalikan
  HTTP 502 kosong untuk request yang mengandung `tools`, dan Hermes selalu
  mengirim tools — jadi sesi Hermes dengan Fable tidak bisa jalan.
- **Implementasi dilakukan di sesi Hermes TEREKAM (model nemotron)** — agen
  Hermes yang menulis/mengedit file lewat file tools-nya, mengikuti desain
  Fable. Dengan begitu pekerjaan terekam dan memenuhi gate transcript.
- Verifikasi akhir: Rojo rebuild, dossier 100%, `check` lolos, commit baru,
  laporkan recording ID + commit + perubahan.

## File kunci
- `src/shared/SnackrotDB.luau` — 12 Snackrot + 5 mutasi (satu-satunya sumber angka).
- `src/shared/Config.luau` — harga upgrade, timer, tier rebirth.
- `src/server/WorldBuilder.luau` — dunia 3D (pasar malam, pantai, warung).
- `src/server/Spawner.luau`, `Base.luau`, `StealAI.luau`, `Hazard.luau`,
  `Rebirth.luau`, `Events.luau`, `Economy.luau`, `GameState.luau`.
- `src/client/Game.client.luau` — HUD, shop, banner, input.
- `main.ts` — build (JANGAN diubah). `default.project.json` — mapping (JANGAN diubah).
- `out/screenshots/` — 4 screenshot (1-thumbnail, 2-start, 3-play, 4-tension).
- Kit: `~/workspace/makefun/kits/roblox-brainrot-01/roblox-brainrot-01-kit/`
  (baca `RULES.txt` sebelum mengubah apa pun).
