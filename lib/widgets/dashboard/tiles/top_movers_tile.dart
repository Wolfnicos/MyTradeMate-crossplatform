import 'package:flutter/material.dart';
import '../../../design_system/widgets/glass_card.dart';
import '../../../services/binance_service.dart';
import '../../../services/app_settings_service.dart';

class TopMoversTile extends StatefulWidget {
  const TopMoversTile({super.key});

  @override
  State<TopMoversTile> createState() => _TopMoversTileState();
}

class _TopMoversTileState extends State<TopMoversTile> {
  final BinanceService _binance = BinanceService();
  bool _loading = true;
  // Restrict to focused coins only
  final List<String> _bases = const <String>['BTC', 'WLFI', 'TRUMP'];
  List<_Mover> _movers = <_Mover>[];

  @override
  void initState() {
    super.initState();
    AppSettingsService().addListener(_onSettingsChanged);
    _refresh();
  }

  void _onSettingsChanged() {
    _refresh();
  }

  @override
  void dispose() {
    AppSettingsService().removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final String quote = AppSettingsService().quoteCurrency.toUpperCase();
    final List<_Mover> tmp = <_Mover>[];
    for (final String base in _bases) {
      final List<String> candidates = _candidatesFor(base, quote);
      Map<String, double>? t;
      String? chosen;
      for (final String sym in candidates) {
        try {
          final res = await _binance.fetchTicker24h(sym);
          t = res;
          chosen = sym;
          break;
        } catch (_) {
          continue;
        }
      }
      if (t != null && chosen != null) {
        tmp.add(_Mover(symbol: chosen, changePct: t['priceChangePercent'] ?? 0.0));
      }
    }
    if (!mounted) return;
    tmp.sort((a, b) => b.changePct.compareTo(a.changePct));
    setState(() {
      _movers = tmp;
      _loading = false;
    });
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
              Expanded(child: Text('Top Movers (24h) — ${AppSettingsService().quoteCurrency.toUpperCase()}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())) else ..._buildRows(),
        ],
      ),
    );
  }

  List<Widget> _buildRows() {
    final List<Widget> rows = <Widget>[];
    for (final _Mover m in _movers.take(3)) {
      final double chg = m.changePct;
      final bool isGain = chg >= 0;
      final color = isGain ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error;
      final String s = m.symbol;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade300, child: Text(s.substring(0, 1))),
            const SizedBox(width: 12),
            Expanded(child: Text(_formatPair(s), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
            Text('${isGain ? '+' : ''}${chg.toStringAsFixed(2)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ));
    }
    return rows;
  }

  String _formatPair(String sym) {
    if (sym.endsWith('USDT')) return sym.replaceAll('USDT', '/USDT');
    if (sym.endsWith('USDC')) return sym.replaceAll('USDC', '/USDC');
    if (sym.endsWith('EUR')) return sym.replaceAll('EUR', '/EUR');
    return sym;
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
}

class _Mover {
  final String symbol;
  final double changePct;
  _Mover({required this.symbol, required this.changePct});
}


