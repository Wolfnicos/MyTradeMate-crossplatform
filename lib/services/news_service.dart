import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class NewsItem {
  final String title;
  final String link;
  final String source;
  final DateTime? pubDate;

  const NewsItem({required this.title, required this.link, required this.source, this.pubDate});
}

class NewsService {
  static final NewsService _instance = NewsService._internal();
  factory NewsService() => _instance;
  NewsService._internal();

  // Public crypto feeds (RSS/Atom)
  final List<Map<String, String>> _feeds = const <Map<String, String>>[
    {'name': 'CoinDesk', 'url': 'https://www.coindesk.com/arc/outboundfeeds/rss/'},
    {'name': 'CoinTelegraph', 'url': 'https://cointelegraph.com/rss'},
    {'name': 'The Block', 'url': 'https://www.theblock.co/rss'},
    {'name': 'CryptoSlate', 'url': 'https://cryptoslate.com/feed/'},
  ];

  Future<List<NewsItem>> fetchLatest({int maxItems = 20}) async {
    final List<NewsItem> all = <NewsItem>[];
    for (final Map<String, String> f in _feeds) {
      try {
        final String name = f['name'] ?? 'RSS';
        final String url = f['url'] ?? '';
        if (url.isEmpty) continue;
        final http.Response res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) continue;
        final String body = utf8.decode(res.bodyBytes);
        final xml.XmlDocument doc = xml.XmlDocument.parse(body);
        for (final channel in doc.findAllElements('channel')) {
          for (final item in channel.findElements('item')) {
            final title = item.getElement('title')?.text.trim() ?? '';
            final link = item.getElement('link')?.text.trim() ?? '';
            final pd = item.getElement('pubDate')?.text.trim();
            DateTime? dt;
            if (pd != null && pd.isNotEmpty) {
              try { dt = DateTime.parse(pd); } catch (_) {}
            }
            if (title.isNotEmpty && link.isNotEmpty) {
              all.add(NewsItem(title: title, link: link, source: name, pubDate: dt));
            }
          }
        }
        // Atom entries
        for (final feed in doc.findAllElements('feed')) {
          for (final entry in feed.findElements('entry')) {
            final title = entry.getElement('title')?.text.trim() ?? '';
            String link = '';
            final linkElem = entry.findElements('link').firstWhere((_) => true, orElse: () => xml.XmlElement(xml.XmlName('link')));
            if (linkElem.getAttribute('href') != null) link = (linkElem.getAttribute('href') ?? '').trim();
            final pd = entry.getElement('updated')?.text.trim() ?? entry.getElement('published')?.text.trim();
            DateTime? dt;
            if (pd != null && pd.isNotEmpty) {
              try { dt = DateTime.parse(pd); } catch (_) {}
            }
            if (title.isNotEmpty && link.isNotEmpty) {
              all.add(NewsItem(title: title, link: link, source: name, pubDate: dt));
            }
          }
        }
      } catch (_) {}
    }
    all.sort((a, b) => (b.pubDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.pubDate ?? DateTime.fromMillisecondsSinceEpoch(0)));
    if (all.length > maxItems) {
      return all.sublist(0, maxItems);
    }
    return all;
  }
}


