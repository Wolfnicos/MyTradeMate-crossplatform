import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../services/news_service.dart';
import '../../screens/all_news_screen.dart';

class CollapsibleNewsBanner extends StatefulWidget {
  const CollapsibleNewsBanner({super.key});

  @override
  State<CollapsibleNewsBanner> createState() => _CollapsibleNewsBannerState();
}

class _CollapsibleNewsBannerState extends State<CollapsibleNewsBanner> {
  bool _expanded = false;
  bool _loading = true;
  List<NewsItem> _items = <NewsItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await NewsService().fetchLatest(maxItems: 50);
      // Filter only crypto/BTC/WLFI/TRUMP
      final List<String> keys = <String>['crypto', 'bitcoin', 'btc', 'wlfi', 'trump'];
      final filtered = items.where((n) {
        final t = n.title.toLowerCase();
        return keys.any((k) => t.contains(k));
      }).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openAll() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllNewsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.newspaper, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _loading
                        ? [const Padding(padding: EdgeInsets.all(8), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)))]
                        : _items.take(5).map((e) => Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text(e.title, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                            )).toList(),
                  ),
                ),
              ),
              TextButton(
                onPressed: _openAll,
                child: const Text('See all'),
              ),
              IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                tooltip: _expanded ? 'Ascunde' : 'Arată tot',
              ),
            ],
          ),
          AnimatedCrossFade(
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            firstChild: _loading
                ? const SizedBox.shrink()
                : Column(
                    children: _items
                        .map((NewsItem m) => InkWell(
                              onTap: () async {
                                final url = m.link;
                                if (await canLaunchUrlString(url)) {
                                  await launchUrlString(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.article_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(m.title, style: theme.textTheme.bodyMedium)),
                                    const SizedBox(width: 8),
                                    Text(m.source, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}


