import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gtfs_feed.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../services/gtfs_rt_alerts.dart';

class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  final Set<String> _busy = {};
  String? _status;
  double _progress = 0;

  Future<void> _download(GtfsFeed feed) async {
    if (_busy.contains(feed.id)) return;
    setState(() {
      _busy.add(feed.id);
      _status = null;
      _progress = 0;
    });
    final state = context.read<AppState>();
    try {
      await state.downloadCityFeed(
        feed,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${feed.name} letöltve'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba (${feed.name}): $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(feed.id);
          _status = null;
          _progress = 0;
        });
      }
    }
  }

  Future<void> _delete(GtfsFeed feed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${feed.name} törlése?'),
        content: const Text('A letöltött menetrend adatai törlődnek a készülékről.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Mégse')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Törlés')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().deleteCityFeed(feed.id);
    if (mounted) setState(() {});
  }


  Future<void> _showRtAlerts(GtfsFeed feed) async {
    final url = feed.rtUrl;
    if (url == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final texts = await GtfsRtAlertsService().fetchAlertTexts(url);
      if (!mounted) return;
      Navigator.of(context).pop(); // loading
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${feed.name} — forgalmi infó'),
          content: SizedBox(
            width: double.maxFinite,
            child: texts.isEmpty
                ? const Text(
                    'Nincs aktív riasztás a GTFS-RT feedben '
                    '(vagy a feed csak Alerts típust ad, és most üres / elavult).',
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        'Forrás: GTFS-RT Alerts\n${feed.rtUrl}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      ...texts.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(s),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bezár'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RT hiba: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Városi menetrendek'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Válaszd ki, mely városok helyi GTFS adatát szeretnéd letölteni. '
            'A megállók a keresésben is megjelennek.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          if (_busy.isNotEmpty) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_status!, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
          ],
          ...KnownFeeds.cities.map((feed) {
            final meta = state.cityFeedMeta[feed.id];
            final enabled = state.enabledCityFeeds.contains(feed.id);
            final busy = _busy.contains(feed.id);
            final stopCount = meta?['stopCount'] as int?;
            final updated = meta?['updatedAt'] as String?;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: enabled
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                          child: Icon(
                            Icons.location_city_rounded,
                            color: enabled ? AppTheme.primary : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(feed.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 16)),
                              Text(feed.operatorName,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        if (!feed.available)
                          Chip(
                            label: const Text('Nem elérhető'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.orange.shade50,
                            labelStyle: TextStyle(
                                fontSize: 11, color: Colors.orange.shade900),
                          )
                        else if (enabled)
                          Chip(
                            label: Text(stopCount != null
                                ? '$stopCount megálló'
                                : 'Letöltve'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.green.shade50,
                            labelStyle: TextStyle(
                                fontSize: 11, color: Colors.green.shade800),
                          ),
                      ],
                    ),
                    if (feed.note != null) ...[
                      const SizedBox(height: 6),
                      Text(feed.note!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600)),
                    ],
                    if (feed.hasRealtime) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.bolt_rounded, size: 16),
                            label: Text(
                              feed.rtKind == 'alerts'
                                  ? 'GTFS-RT Alerts'
                                  : 'GTFS-RT',
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          TextButton.icon(
                            onPressed: () => _showRtAlerts(feed),
                            icon: const Icon(Icons.campaign_rounded, size: 18),
                            label: const Text('Forgalmi infó'),
                          ),
                        ],
                      ),
                    ],
                    if (updated != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Frissítve: ${updated.substring(0, 16).replaceFirst('T', ' ')}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (feed.available)
                          FilledButton.tonalIcon(
                            onPressed: busy ? null : () => _download(feed),
                            icon: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(enabled
                                    ? Icons.refresh_rounded
                                    : Icons.download_rounded),
                            label: Text(enabled ? 'Frissítés' : 'Letöltés'),
                          ),
                        if (enabled) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: busy ? null : () => _delete(feed),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Törlés'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Források: hivatalos szolgáltatói GTFS, MenetBrand, Transitous tükrök. '
            'Egyes oldalak botvédelmet használnak — ha a letöltés sikertelen, '
            'próbáld később vagy más hálózaton.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}