# Menetrend+

Magyar menetrend app (Flutter) — **Volánbusz + MÁV**

## v0.4

### 1. Útvonaltervező (MÁV)
- Állomásválasztó (MÁV kódokkal)
- `GetUtazasiAjanlat` → idő, járat, ár, érintett állomások

### 2. Volán indulások
- **UTAS** élő API: `arrivals-and-departures-for-stop`
- Fallback: **GTFS stop_times.txt** streamelt offline parse
- GTFS letöltéskor: stops + trips + routes + stop_times

### 3. Élő térkép + cluster
- MÁV vonatok (`GetVonatok`) + Volán buszok (`utas.hu` vehicles-for-location)
- Zoom < 10: rács-alapú cluster (szám a körben, kattintás → zoom)
- Késés színkód: zöld / sárga / narancs / piros
- Ikon tap → pontos késés

### Futtatás
```bash
cd menetrend_plus
flutter pub get
flutter run
```

### API-k
| Forrás | Endpoint |
|--------|----------|
| Volán GTFS | gtfs.kti.hu/public-gtfs/volanbusz_gtfs.zip |
| MÁV REST | vim.mav-start.hu/.../GetVonatok, GetAllomasInfo, GetUtazasiAjanlat |
| UTAS élő | utas.hu/api/.../vehicles-for-location, arrivals-and-departures-for-stop |

Nem hivatalos API-k — saját felelősségre.
