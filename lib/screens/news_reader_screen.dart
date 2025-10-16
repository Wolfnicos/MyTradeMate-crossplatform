import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NewsReaderScreen extends StatefulWidget {
  final String url;
  final String title;
  const NewsReaderScreen({super.key, required this.url, required this.title});

  @override
  State<NewsReaderScreen> createState() => _NewsReaderScreenState();
}

class _NewsReaderScreenState extends State<NewsReaderScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}


