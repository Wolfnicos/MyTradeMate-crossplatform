import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/news_service.dart';

class AllNewsScreen extends StatefulWidget {
  const AllNewsScreen({super.key});

  @override
  State<AllNewsScreen> createState() => _AllNewsScreenState();
}

class _AllNewsScreenState extends State<AllNewsScreen> {
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
      final items = await NewsService().fetchLatest(maxItems: 100);
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
    return Scaffold(
      appBar: AppBar(title: const Text('All news')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final m = _items[index];
                  return ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: Text(m.title),
                    subtitle: Text(m.source),
                    onTap: () async {
                      final url = m.link;
                      if (await canLaunchUrlString(url)) {
                        await launchUrlString(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}
