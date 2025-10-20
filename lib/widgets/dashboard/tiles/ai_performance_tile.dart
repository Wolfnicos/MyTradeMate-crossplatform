import 'package:flutter/material.dart';
import '../../../design_system/widgets/glass_card.dart';
import '../../../services/binance_service.dart';
import '../../../services/app_settings_service.dart';
import '../../../ml/ml_service.dart';

class AiPerformanceTile extends StatefulWidget {
  const AiPerformanceTile({super.key});

  @override
  State<AiPerformanceTile> createState() => _AiPerformanceTileState();
}

class _AiPerformanceTileState extends State<AiPerformanceTile> {
  final BinanceService _binance = BinanceService();
  // Focus on BTC/WLFI/TRUMP and respect selected quote (prefer EUR)
  List<String> _symbols = const <String>['BTCEUR', 'WLFIEUR', 'TRUMPEUR'];
  bool _loading = true;
  final Map<String, Map<String, dynamic>> _results = <String, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    AppSettingsService().addListener(_onSettingsChanged);
    _refresh();
  }

  @override
  void dispose() {
    AppSettingsService().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final String quote = AppSettingsService().quoteCurrency.toUpperCase();
    final List<String> bases = <String>['BTC', 'WLFI', 'TRUMP'];
    final List<String> wanted = <String>[];
    for (final String base in bases) {
      final List<String> candidates = _candidatesFor(base, quote);
      String? chosen;
      for (final String sym in candidates) {
        chosen = sym; // we will rely on getFeaturesForModel error handling if unsupported
        break;
      }
      if (chosen != null) wanted.add(chosen);
    }
    _symbols = wanted;

    final Map<String, Map<String, dynamic>> out = <String, Map<String, dynamic>>{};
    for (final String s in _symbols) {
      try {
        final feats = await _binance.getFeaturesForModel(s);
        final res = globalMlService.getSignal(feats, symbol: s);
        out[s] = res;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _results
        ..clear()
        ..addAll(out);
      _loading = false;
    });
  }

  List<String> _candidatesFor(String base, String quote) {
    switch (quote) {
      case 'EUR':
        return <String>['${base}EUR', '${base}USDT', '${base}USDC'];
      case 'USDC':
        return <String>['${base}USDC', '${base}USDT'];
      case 'USD':
      case 'USDT':
      default:
        return <String>['${base}USDT', '${base}USDC'];
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
              Expanded(child: Text('AI Performance — ${AppSettingsService().quoteCurrency.toUpperCase()}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())) else ..._symbols.map(_buildRow),
        ],
      ),
    );
  }

  Widget _buildRow(String symbol) {
    final Map<String, dynamic>? res = _results[symbol];
    TradingSignal? sig;
    List<double>? probs;
    if (res != null) {
      sig = res['signal'] as TradingSignal?;
      probs = (res['probabilities'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList();
    }
    final Color color;
    final String label;
    switch (sig) {
      case TradingSignal.BUY:
        color = Colors.green;
        label = 'BUY';
        break;
      case TradingSignal.SELL:
        color = Colors.red;
        label = 'SELL';
        break;
      case TradingSignal.HOLD:
      default:
        color = Colors.grey;
        label = 'HOLD';
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.15), child: Icon(Icons.smart_toy, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(_formatPair(symbol), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          if (probs != null && probs.length == 3)
            SizedBox(
              width: 90,
              child: Text('S ${(probs[0] * 100).toStringAsFixed(0)}%  H ${(probs[1] * 100).toStringAsFixed(0)}%  B ${(probs[2] * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  String _formatPair(String sym) {
    if (sym.endsWith('USDT')) return sym.replaceAll('USDT', '/USDT');
    if (sym.endsWith('USDC')) return sym.replaceAll('USDC', '/USDC');
    if (sym.endsWith('EUR')) return sym.replaceAll('EUR', '/EUR');
    if (sym.endsWith('USD')) return sym.replaceAll('USD', '/USD');
    return sym;
  }
}


