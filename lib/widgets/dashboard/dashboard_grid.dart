import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/widgets/glass_card.dart';
import 'tiles/portfolio_tile.dart';
import 'tiles/quick_trade_tile.dart';
import 'tiles/ai_performance_tile.dart';
import 'tiles/top_movers_tile.dart';
// Removed Orders tile by request

class DashboardGrid extends StatefulWidget {
  const DashboardGrid({super.key});

  @override
  State<DashboardGrid> createState() => _DashboardGridState();
}

class _DashboardGridState extends State<DashboardGrid> {
  static const String _prefsKey = 'dashboard_tiles_order_v1';

  // Identifier order persisted to prefs
  List<String> _tileOrder = const <String>[
    'portfolio',
    'quick_trade',
    'ai_performance',
    'top_movers',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        // Filter out any deprecated/removed tiles like 'orders' and 'news'
        final filtered = saved.where((e) => e != 'orders' && e != 'news').toList(growable: false);
        setState(() => _tileOrder = filtered);
      }
    } catch (_) {}
  }

  Future<void> _saveOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _tileOrder);
    } catch (_) {}
  }

  Widget _buildTile(String id) {
    switch (id) {
      case 'portfolio':
        return const PortfolioTile(key: ValueKey('portfolio'));
      case 'quick_trade':
        return const QuickTradeTile(key: ValueKey('quick_trade'));
      case 'ai_performance':
        return const AiPerformanceTile(key: ValueKey('ai_performance'));
      case 'top_movers':
        return const TopMoversTile(key: ValueKey('top_movers'));
      default:
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: const Text('Unknown tile'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _tileOrder
        .map((id) => SizedBox(
              key: ValueKey('tile_$id'),
              width: _tileWidthFor(context),
              child: _buildTile(id),
            ))
        .toList(growable: false);

    return ReorderableWrap(
      spacing: 16,
      runSpacing: 16,
      buildDraggableFeedback: (context, constraints, child) => Opacity(opacity: 0.85, child: child),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          final String item = _tileOrder.removeAt(oldIndex);
          _tileOrder.insert(newIndex, item);
        });
        _saveOrder();
      },
      children: children,
    );
  }

  double _tileWidthFor(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    final double p = 16 * 2; // symmetric page padding assumed outside
    final double usable = w - p;
    if (usable >= 1000) return (usable - 16 * 2) / 3; // 3 columns
    if (usable >= 640) return (usable - 16) / 2; // 2 columns
    return usable; // 1 column
  }
}


