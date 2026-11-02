/// Egy városi / regionális GTFS feed leírása.
class GtfsFeed {
  final String id;
  final String name;
  final String operatorName;
  final String url;

  /// Opcionális GTFS-RT feed URL (VehiclePositions / TripUpdates / Alerts).
  final String? rtUrl;

  /// Milyen RT típus: vehicle | trip | alerts | unknown
  final String? rtKind;

  final String? note;
  final bool available;

  const GtfsFeed({
    required this.id,
    required this.name,
    required this.operatorName,
    required this.url,
    this.rtUrl,
    this.rtKind,
    this.note,
    this.available = true,
  });

  bool get hasRealtime => rtUrl != null && rtUrl!.isNotEmpty;
}

/// Elérhető feedek — menetrend.app / Transitous / hivatalos források alapján.
class KnownFeeds {
  static const List<GtfsFeed> cities = [
    GtfsFeed(
      id: 'bkk',
      name: 'Budapest (BKK)',
      operatorName: 'BKK / MÁV-HÉV',
      url: 'https://go.bkk.hu/api/static/v1/public-gtfs/budapest_gtfs.zip',
      note:
          'Teljes BKK hálózat (busz, troli, villamos, metró, HÉV, hajó). '
          'Nagy fájl (~50 MB). Élő GTFS-RT-hez BKK OpenData API kulcs kell.',
    ),
    GtfsFeed(
      id: 'szeged',
      name: 'Szeged',
      operatorName: 'SZKT / szegedimenetrend.hu',
      url: 'http://szegedimenetrend.hu/google_transit.zip',
      rtUrl: 'http://szegedimenetrend.hu/gtfs.dat',
      rtKind: 'alerts',
      note:
          'Villamos, troli, busz, tram-train. '
          'GTFS-RT: csak Alerts, nincs nyilvános járműpozíció.',
    ),
    GtfsFeed(
      id: 'miskolc',
      name: 'Miskolc',
      operatorName: 'MVK Zrt.',
      url: 'https://mvkzrt.hu/gtfs/mvkzrt.zip',
      note:
          'Busz + villamos (MVK hivatalos GTFS). Élő: valosidoben.mvkzrt.hu nem publikus API.',
    ),
    GtfsFeed(
      id: 'pecs',
      name: 'Pécs',
      operatorName: 'Tüke Busz / BIOKOM',
      url: 'https://mobilitas.biokom.hu/gtfs/',
      note: 'Helyi buszok (hivatalos BIOKOM GTFS).',
    ),
    GtfsFeed(
      id: 'debrecen',
      name: 'Debrecen',
      operatorName: 'DKV (partneri)',
      url: '',
      available: false,
      note:
          'Hivatalos GTFS / élő adat partneri (menetrend.app–DKV). '
          'Nincs nyilvános, kulcs nélküli zip.',
    ),
    GtfsFeed(
      id: 'kaposvar',
      name: 'Kaposvár',
      operatorName: 'Kaposvári Közlekedési Zrt.',
      url: 'https://www.kaposbusz.hu/static/files/kaposvar(11).zip',
      note:
          'Hivatalos GTFS. Ha 404, a fájlnév változott — kaposbusz.hu/letoltheto-menetrend',
    ),
    GtfsFeed(
      id: 'veszprem',
      name: 'Veszprém',
      operatorName: 'V-Busz Kft.',
      url: 'https://jbb.ghsq.de/gtfs/hu-v-busz_kft..gtfs.zip',
      note: 'Helyi buszok (Transitous tükör).',
    ),
    GtfsFeed(
      id: 'szombathely',
      name: 'Szombathely',
      operatorName: 'Blaguss Agora',
      url:
          'https://szombathely.utas.hu/api/static/v1/gtfs-google/gtfs-google.zip',
      note: 'Helyi buszok.',
    ),
    GtfsFeed(
      id: 'szekesfehervar',
      name: 'Székesfehérvár',
      operatorName: 'Székesfehérvár Önkormányzat',
      url: 'https://gtfs.menetbrand.com/download/szekesfehervar/',
      note: 'MenetBrand — botvédelem miatt sikertelen lehet.',
    ),
    GtfsFeed(
      id: 'tatabanya',
      name: 'Tatabánya',
      operatorName: 'T-Busz Kft.',
      url: 'https://gtfs.menetbrand.com/download/tatabanya',
      note: 'MenetBrand tükör.',
    ),
    GtfsFeed(
      id: 'kecskemet',
      name: 'Kecskemét',
      operatorName: 'nem hivatalos (derilevi / GitHub)',
      // Hivatalos KeKo zip auth-tal védve; közösségi GTFS:
      // https://github.com/derilevi/gtfs_kecskemet
      url:
          'https://github.com/derilevi/gtfs_kecskemet/releases/download/20210901-2/gtfs_kecskemet.zip',
      note:
          'Nem hivatalos, önkéntes GTFS (2021-es release). '
          'Hivatalos KeKo feed auth-os. Forrás: github.com/derilevi/gtfs_kecskemet',
    ),
    GtfsFeed(
      id: 'kiskunhalas',
      name: 'Kiskunhalas',
      operatorName: 'Halasbusz / közösségi',
      url: 'https://gy-mate.hu/gtfs/gtfs_hu_kiskunhalas.zip',
      note: 'Közösségi GTFS tükör.',
    ),
    GtfsFeed(
      id: 'eger',
      name: 'Eger',
      operatorName: 'helyimenetrend.hu (archív) / Volán',
      url: 'http://helyimenetrend.hu/eger_GTFS_E01-E09.zip',
      note: 'Archív helyi GTFS. Élő járatok: Volán országos GTFS.',
    ),
    GtfsFeed(
      id: 'dunaujvaros',
      name: 'Dunaújváros',
      operatorName: 'helyimenetrend.hu (archív) / Volán',
      url: 'http://helyimenetrend.hu/dunaujvaros_GTFS_B01-B21.zip',
      note: 'Archív. Hivatalos: Volán GTFS.',
    ),
    GtfsFeed(
      id: 'mav_gtfs',
      name: 'MÁV (statikus GTFS tükör)',
      operatorName: 'MÁV-START (Transitous tükör)',
      url:
          'https://jbb.ghsq.de/gtfs/hu-m%C3%A1v_szem%C3%A9lysz%C3%A1ll%C3%ADt%C3%A1si_zrt..gtfs.zip',
      note:
          'Nem hivatalos tükör. Hivatalos: mavcsoport.hu/gtfs-igenybejelento. '
          'Élő: EMESE / GetVonatok.',
    ),
  ];

  static GtfsFeed? byId(String id) {
    try {
      return cities.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}
