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
      url: 'https://gtfs.menetbrand.com/download/szekesfehervar/',
      note: 'MenetBrand forrás — letöltés sikertelen lehet',
    ),
    GtfsFeed(
      id: 'szeged',
      name: 'Szeged',
      operatorName: 'SZKT / szegedimenetrend.hu',
      // Közvetlen, stabil forrás (Cseh Attila GTFS)
      url: 'http://szegedimenetrend.hu/google_transit.zip',
      rtUrl: 'http://szegedimenetrend.hu/gtfs.dat',
      rtKind: 'alerts',
      note:
          'Statikus GTFS + GTFS-RT Alerts (forgalmi változások). '
          'Nincs élő járműpozíció a nyilvános RT feedben.',
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
      url: 'http://mvkzrt.hu/gtfs/mvkzrt.zip',
      note: 'Busz + villamos',
    ),
    GtfsFeed(
      id: 'eger',
      name: 'Eger',
      operatorName: 'helyimenetrend.hu (archív)',
      url: 'http://helyimenetrend.hu/eger_GTFS_E01-E09.zip',
      note: 'Archív, nem frissül.',
    ),
    GtfsFeed(
      id: 'dunaujvaros',
      name: 'Dunaújváros',
      operatorName: 'helyimenetrend.hu (archív)',
      url: 'http://helyimenetrend.hu/dunaujvaros_GTFS_B01-B21.zip',
      note:
          'Archív, nem frissül.',
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
