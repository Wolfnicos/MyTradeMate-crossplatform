import 'package:flutter/material.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../design_system/app_colors.dart';
import '../../services/binance_service.dart';

class OpenOrdersCard extends StatefulWidget {
  final String? symbol;
  final bool paperMode;
  const OpenOrdersCard({super.key, this.symbol, required this.paperMode});

  @override
  State<OpenOrdersCard> createState() => _OpenOrdersCardState();
}

class _OpenOrdersCardState extends State<OpenOrdersCard> {
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (widget.paperMode) {
      setState(() { _orders = const <Map<String, dynamic>>[]; _loading = false; _error = ''; });
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await BinanceService().fetchOpenOrders(symbol: widget.symbol);
      if (!mounted) return;
      setState(() { _orders = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
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
              Expanded(child: Text('Open Orders', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.paperMode)
            Text('Paper mode: orders execute immediately, no open orders list.', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted))
          else if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if (_error.isNotEmpty)
            Text(_error, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error))
          else if (_orders.isEmpty)
            Text('No open orders', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted))
          else
            ..._orders.map((o) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (o['side'] == 'BUY' ? theme.colorScheme.secondary : theme.colorScheme.error).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(o['side'] ?? '', style: TextStyle(color: o['side'] == 'BUY' ? theme.colorScheme.secondary : theme.colorScheme.error, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text((o['symbol'] ?? '') + '  @ ' + (o['price'] ?? '').toString() + '  x ' + (o['origQty'] ?? '').toString() )),
                  TextButton(
                    onPressed: () async {
                      try {
                        await BinanceService().cancelOrder(
                          symbol: (o['symbol'] ?? ''),
                          orderId: (o['orderId'] is int) ? o['orderId'] as int : int.tryParse((o['orderId'] ?? '').toString()),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled')));
                        }
                        _refresh();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel error: ' + e.toString())));
                        }
                      }
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}


