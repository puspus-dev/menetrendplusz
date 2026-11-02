/// Egy városi / regionális GTFS feed leírása.
class GtfsFeed {
  final String id;
  final String name;
  final String operatorName;
  final String url;
  final String? note;
  final bool available;

  const GtfsFeed({
    required this.id,
    required this.name,
    required this.operatorName,
    required this.url,
    this.note,
    this.available = true,
  });
}

/// Elérhető városi feedek — közvetlen zip URL-ekkel ahol van.
class KnownFeeds {
  static const List<GtfsFeed> cities = [
    GtfsFeed(
      id: 'veszprem',
      name: 'Veszprém',
      operatorName: 'V-Busz Kft.',
      url: 'https://jbb.ghsq.de/gtfs/hu-v-busz_kft..gtfs.zip',
      note: 'Helyi buszok',
    ),
    GtfsFeed(
      id: 'szombathely',
      name: 'Szombathely',
      operatorName: 'Blaguss Agora',
      url: 'https://szombathely.utas.hu/api/static/v1/gtfs-google/gtfs-google.zip',
      note: 'Helyi buszok',
    ),
    GtfsFeed(
      id: 'szekesfehervar',
      name: 'Székesfehérvár',
      operatorName: 'Székesfehérvár Önkormányzat',
      // MenetBrand proxy; ha botvédelem, később frissíthető
      url: 'https://gtfs.menetbrand.com/download/szekesfehervar/',
      note: 'MenetBrand forrás — letöltés sikertelen lehet',
      available: true,
    ),
    GtfsFeed(
      id: 'szeged',
      name: 'Szeged',
      operatorName: 'SZKT',
      url: 'https://gtfs.menetbrand.com/download/szeged/',
      note: 'Villamos, troli, busz — MenetBrand / NAP',
      available: true,
    ),
    GtfsFeed(
      id: 'pecs',
      name: 'Pécs',
      operatorName: 'Tüke Busz / BIOKOM',
      url: 'http://mobilitas.biokom.hu/gtfs',
      note: 'Helyi buszok',
    ),
    GtfsFeed(
      id: 'miskolc',
      name: 'Miskolc',
      operatorName: 'MVK Zrt.',
      url: 'http://gtfs.cdata.hu/mvkzrt.zip',
      note: 'Busz + villamos',
    ),
    GtfsFeed(
      id: 'eger',
      name: 'Eger',
      operatorName: 'helyimenetrend.hu (archív)',
      url: 'http://helyimenetrend.hu/eger_GTFS_E01-E09.zip',
      note: 'Archív GTFS (2021/2022) — a projekt szünetel, nem frissül',
      available: true,
    ),
    GtfsFeed(
      id: 'dunaujvaros',
      name: 'Dunaújváros',
      operatorName: 'helyimenetrend.hu (archív)',
      url: 'http://helyimenetrend.hu/dunaujvaros_GTFS_B01-B21.zip',
      note: 'Archív GTFS — a projekt szünetel; helyi járatok ma a Volán GTFS-ben is lehetnek',
      available: true,
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