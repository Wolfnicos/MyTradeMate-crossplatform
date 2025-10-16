import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../design_system/widgets/glass_card.dart';
import '../../../services/news_service.dart';

class NewsTile extends StatefulWidget {
  const NewsTile({super.key});

  @override
  State<NewsTile> createState() => _NewsTileState();
}

class _NewsTileState extends State<NewsTile> {
  bool _loading = true;
  List<NewsItem> _items = <NewsItem>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final items = await NewsService().fetchLatest(maxItems: 10);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('News', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else
            ..._items.take(5).map((NewsItem m) => _buildItem(m)),
        ],
      ),
    );
  }

  Widget _buildItem(NewsItem m) {
    return InkWell(
      onTap: () async {
        final String url = m.link;
        if (await canLaunchUrlString(url)) {
          await launchUrlString(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            const Icon(Icons.article_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(m.title, style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(width: 8),
            Text(m.source, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}


