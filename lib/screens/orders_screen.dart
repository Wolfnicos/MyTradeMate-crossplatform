import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backtest/backtester.dart';
import '../services/paper_broker.dart';
import '../services/binance_service.dart';
import '../services/hybrid_strategies_service.dart';
import '../ml/ml_service.dart';
import 'dart:async';
import '../design_system/screen_backgrounds.dart';
import '../design_system/widgets/glass_card.dart';
import '../design_system/app_colors.dart';
import '../services/app_settings_service.dart';
import '../widgets/orders/ai_strategy_carousel.dart';
import '../widgets/orders/achievement_toast.dart';
import '../widgets/orders/open_orders_card.dart';
import '../widgets/orders/collapsible_protection_banner.dart';

enum OrderType { hybrid, aiModel, market }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  bool isBuy = true;
  OrderType _orderType = OrderType.market;
  String _selectedPair = 'BTCUSDT';
  List<Map<String, String>> _pairs = <Map<String, String>>[];
  bool _loadingPairs = true;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _totalCtrl = TextEditingController();
  bool _updatingFields = false;
  String _aiInterval = '1h';
  bool _ocoEnabled = false;
  double _stopLossPct = 3.0;
  double _takeProfitPct = 6.0;
  StreamSubscription<List<StrategySignal>>? _hybridSub;
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    // Load last order type preference
    _loadSavedOrderType();
    _loadPairs();
  }

  Future<void> _loadSavedOrderType() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('order_type');
    if (saved != null) {
      setState(() {
        switch (saved) {
          case 'hybrid':
            _orderType = OrderType.hybrid;
            break;
          case 'ai_model':
            _orderType = OrderType.aiModel;
            break;
          default:
            _orderType = OrderType.market;
        }
      });
    }
  }

  Future<void> _loadPairs() async {
    try {
      final binance = BinanceService();
      final all = await binance.fetchTradingPairs();
      // Keep only user's bases + selected quote
      final String selectedQuote = AppSettingsService().quoteCurrency.toUpperCase();
      final Set<String> allowedBases = <String>{'BTC','ETH','BNB','SOL','WLFI','TRUMP'};
      final List<Map<String, String>> filtered = <Map<String, String>>[];
      final Set<String> seen = <String>{};
      for (final m in all) {
        final base = (m['base'] ?? '').toUpperCase();
        final quote = (m['quote'] ?? '').toUpperCase();
        if (quote == selectedQuote && allowedBases.contains(base)) {
          final sym = (m['symbol'] ?? '').toUpperCase();
          if (!seen.contains(sym)) {
            seen.add(sym);
            filtered.add({'symbol': sym, 'base': base, 'quote': quote});
          }
        }
      }
      filtered.sort((a, b) => (a['base'] ?? '').compareTo(b['base'] ?? ''));
      setState(() {
        _pairs = filtered;
        _loadingPairs = false;
        // default selected to first if current not in list
        if (_pairs.isNotEmpty && !_pairs.any((p) => (p['symbol'] ?? '') == _selectedPair)) {
          _selectedPair = _pairs.first['symbol'] ?? _selectedPair;
        }
      });
    } catch (e) {
      setState(() => _loadingPairs = false);
    }
  }

  @override
  void dispose() {
    _hybridSub?.cancel();
    _aiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = isBuy ? theme.colorScheme.secondary : theme.colorScheme.error;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: ScreenBackgrounds.market(context),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Orders', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: GlassCard(
                            key: ValueKey(isBuy),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => isBuy = true),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isBuy ? activeColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(child: Text('Buy', style: TextStyle(color: isBuy ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.bold))),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => isBuy = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !isBuy ? activeColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(child: Text('Sell', style: TextStyle(color: !isBuy ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.bold))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FutureBuilder<SharedPreferences>(
                          future: SharedPreferences.getInstance(),
                          builder: (context, snap) {
                            final paper = (snap.data?.getBool('paper_trading') ?? false);
                            return OpenOrdersCard(symbol: _selectedPair, paperMode: paper);
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 110,
                          child: AiStrategyCarousel(
                            strategies: hybridStrategiesService.strategies,
                            onSelect: (_) {},
                          ),
                        ),
                        const SizedBox(height: 16),
                        CollapsibleProtectionBanner(
                          enabled: _ocoEnabled,
                          stopLossPct: _stopLossPct,
                          takeProfitPct: _takeProfitPct,
                          onEnabledChanged: (v) => setState(() => _ocoEnabled = v),
                          onStopLossChanged: (v) => setState(() => _stopLossPct = v),
                          onTakeProfitChanged: (v) => setState(() => _takeProfitPct = v),
                        ),
                        const SizedBox(height: 16),
                        GlassCard(padding: const EdgeInsets.all(16), child: _buildPairSelector(context)),
                        const SizedBox(height: 16),
                        GlassCard(padding: const EdgeInsets.all(16), child: _buildOrderTypeBanner(context)),
                        const SizedBox(height: 16),
                        GlassCard(padding: const EdgeInsets.all(16), child: _buildAmountField()),
                        const SizedBox(height: 16),
                        GlassCard(padding: const EdgeInsets.all(16), child: _buildLimitPriceField()),
                        const SizedBox(height: 16),
                        GlassCard(padding: const EdgeInsets.all(16), child: _buildTotalFiatField()),
                        _buildAmountSummary(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final bool paper = prefs.getBool('paper_trading') ?? false;
                              if (_orderType == OrderType.market) {
                                if (paper) {
                                  final price = double.tryParse(_priceCtrl.text) ?? 0.0;
                                  final qty = double.tryParse(_amountCtrl.text) ?? 0.0;
                                  PaperBroker().execute(Trade(time: DateTime.now(), side: isBuy ? 'BUY' : 'SELL', price: price, quantity: qty));
                                  AchievementToast.show(context, 'first_paper_trade', 'Achievement unlocked: First Paper Trade!');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Market order (Paper) executed')));
                                  }
                                } else {
                                  try {
                                    final double? qty = double.tryParse(_amountCtrl.text);
                                    final double? total = double.tryParse(_totalCtrl.text);
                                    final res = await BinanceService().placeMarketOrder(
                                      symbol: _selectedPair,
                                      side: isBuy ? 'BUY' : 'SELL',
                                      quantity: (qty != null && qty > 0) ? qty : null,
                                      quoteOrderQty: (total != null && total > 0) ? total : null,
                                    );
                                    // If protection enabled and BUY, place OCO (SELL) with TP/SL based on last price
                                    if (_ocoEnabled && isBuy) {
                                      final lastPrice = double.tryParse(_priceCtrl.text);
                                      final usePrice = lastPrice ?? (res['fills'] != null && (res['fills'] as List).isNotEmpty ? double.tryParse(((res['fills'] as List).first as Map)['price']?.toString() ?? '') : null);
                                      final double? filledQty = double.tryParse(res['executedQty']?.toString() ?? '') ?? qty;
                                      if (usePrice != null && filledQty != null && filledQty > 0) {
                                        final tp = usePrice * (1 + _takeProfitPct / 100.0);
                                        final sl = usePrice * (1 - _stopLossPct / 100.0);
                                        try {
                                          await BinanceService().placeOcoOrder(
                                            symbol: _selectedPair,
                                            side: 'SELL',
                                            quantity: filledQty,
                                            price: tp,
                                            stopPrice: sl,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Protection OCO placed')));
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCO error: ' + e.toString())));
                                          }
                                        }
                                      }
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Order sent: ' + (res['status']?.toString() ?? 'OK'))),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Order error: ' + e.toString())),
                                      );
                                    }
                                  }
                                }
                              } else if (_orderType == OrderType.hybrid) {
                                _hybridSub?.cancel();
                                _hybridSub = hybridStrategiesService.signalsStream.listen((signals) {
                                  final StrategySignal? m = signals.firstWhere(
                                    (s) => (isBuy && s.type == SignalType.BUY) || (!isBuy && s.type == SignalType.SELL),
                                    orElse: () => StrategySignal(strategyName: 'none', type: SignalType.HOLD, confidence: 0.0, reason: 'no match'),
                                  );
                                  if (m != null && ((isBuy && m.type == SignalType.BUY) || (!isBuy && m.type == SignalType.SELL))) {
                                    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
                                    final qty = double.tryParse(_amountCtrl.text) ?? 0.0;
                                    PaperBroker().execute(Trade(time: DateTime.now(), side: isBuy ? 'BUY' : 'SELL', price: price, quantity: qty));
                                    _hybridSub?.cancel();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hybrid signal executed (${m.type.name})')));
                                    }
                                  }
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Armed: waiting for Hybrid strategy signal...')));
                                }
                              } else {
                                _aiTimer?.cancel();
                                _aiTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
                                  try {
                                    final feats = await BinanceService().getFeaturesForModel(_selectedPair, interval: _aiInterval);
                                    final res = globalMlService.getSignal(feats, symbol: _selectedPair);
                                    final TradingSignal sig = res['signal'] as TradingSignal;
                                    if ((isBuy && sig == TradingSignal.BUY) || (!isBuy && sig == TradingSignal.SELL)) {
                                      final price = double.tryParse(_priceCtrl.text) ?? 0.0;
                                      final qty = double.tryParse(_amountCtrl.text) ?? 0.0;
                                      PaperBroker().execute(Trade(time: DateTime.now(), side: isBuy ? 'BUY' : 'SELL', price: price, quantity: qty));
                                      _aiTimer?.cancel();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Model signal executed (${sig.name})')));
                                      }
                                    }
                                  } catch (_) {}
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Armed: AI Model monitoring...')));
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: Colors.white,
                            ),
                            child: Text((isBuy ? 'Buy ' : 'Sell ') + _formatPairLabel(_selectedPair).split('/').first, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Removed unused _buildTextField

  Widget _buildAmountField() {
    final theme = Theme.of(context);
    final String base = _selectedPair.replaceAll(RegExp(r'(USDT|USDC|EUR)$'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amount', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixText: base,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onChanged: (_) {
            if (_updatingFields) return;
            _updatingFields = true;
            final qty = double.tryParse(_amountCtrl.text) ?? 0.0;
            final price = double.tryParse(_priceCtrl.text) ?? 0.0;
            final total = qty * price;
            _totalCtrl.text = total > 0 ? total.toStringAsFixed(2) : '';
            _updatingFields = false;
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildLimitPriceField() {
    final theme = Theme.of(context);
    final String quote = _selectedPair.endsWith('USDT')
        ? 'USDT'
        : _selectedPair.endsWith('USDC')
            ? 'USDC'
            : 'EUR';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Limit Price', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixText: quote == 'EUR' ? '€ ' : (quote == 'USDC' || quote == 'USDT') ? '\$ ' : '',
            suffixText: quote,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onChanged: (_) {
            if (_updatingFields) return;
            _updatingFields = true;
            final qty = double.tryParse(_amountCtrl.text) ?? 0.0;
            final price = double.tryParse(_priceCtrl.text) ?? 0.0;
            final total = qty * price;
            _totalCtrl.text = total > 0 ? total.toStringAsFixed(2) : '';
            _updatingFields = false;
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildAmountSummary() {
    if (_amountCtrl.text.isEmpty || _priceCtrl.text.isEmpty) return const SizedBox.shrink();
    final double qty = double.tryParse(_amountCtrl.text) ?? 0.0;
    final double price = double.tryParse(_priceCtrl.text) ?? 0.0;
    final double total = qty * price;
    final String quote = _selectedPair.endsWith('USDT')
        ? 'USDT'
        : _selectedPair.endsWith('USDC')
            ? 'USDC'
            : 'EUR';
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text('Total: ' + total.toStringAsFixed(2) + ' ' + quote),
      ),
    );
  }

  Widget _buildTotalFiatField() {
    final theme = Theme.of(context);
    final String quote = _selectedPair.endsWith('USDT')
        ? 'USDT'
        : _selectedPair.endsWith('USDC')
            ? 'USDC'
            : 'EUR';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total (' + quote + ")", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _totalCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '',
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixText: quote == 'EUR' ? '€ ' : (quote == 'USDC' || quote == 'USDT') ? '\$ ' : '',
            suffixText: quote,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onChanged: (_) {
            if (_updatingFields) return;
            _updatingFields = true;
            final total = double.tryParse(_totalCtrl.text) ?? 0.0;
            final price = double.tryParse(_priceCtrl.text) ?? 0.0;
            if (price > 0) {
              final qty = total / price;
              _amountCtrl.text = qty > 0 ? qty.toStringAsFixed(8) : '';
            }
            _updatingFields = false;
            setState(() {});
          },
        ),
      ],
    );
  }

  // Removed unused _buildAiIntervalChips

  String _orderTypeLabel(OrderType t) {
    switch (t) {
      case OrderType.hybrid:
        return 'Hybrid (Strategies)';
      case OrderType.aiModel:
        return 'AI Model';
      case OrderType.market:
        return 'Market';
    }
  }

  IconData _orderTypeIcon(OrderType t) {
    switch (t) {
      case OrderType.hybrid:
        return Icons.auto_graph;
      case OrderType.aiModel:
        return Icons.smart_toy_outlined;
      case OrderType.market:
        return Icons.show_chart;
    }
  }

  Future<void> _pickOrderType() async {
    final theme = Theme.of(context);
    final OrderType? selected = await showModalBottomSheet<OrderType>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        Widget tile(OrderType t, String title, String subtitle) {
          final bool isSel = _orderType == t;
          return ListTile(
            leading: Icon(_orderTypeIcon(t), color: isSel ? theme.colorScheme.primary : null),
            title: Text(title, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.w500)),
            subtitle: Text(subtitle),
            trailing: isSel ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
            onTap: () => Navigator.of(context).pop(t),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(OrderType.hybrid, 'Hybrid (Strategies)', 'Combines rule-based logic with ML signal'),
              tile(OrderType.aiModel, 'AI Model', 'Folosește doar modelul TFLite'),
              tile(OrderType.market, 'Market', 'Immediate execution at market price'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _orderType = selected);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('order_type', _orderType.name);
    }
  }

  Widget _buildOrderTypeBanner(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _pickOrderType,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (theme.brightness == Brightness.dark ? AppColors.outline : AppColors.lightOutline).withOpacity(0.20),
          ),
        ),
        child: Row(
          children: [
            Icon(_orderTypeIcon(_orderType), color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Type', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(_orderTypeLabel(_orderType), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildPairSelector(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Select Pair', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: _loadingPairs
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _pairs.length,
                            itemBuilder: (context, index) {
                              final m = _pairs[index];
                              final sym = m['symbol'] ?? '';
                              final base = m['base'] ?? '';
                              final quote = m['quote'] ?? '';
                              return ListTile(
                                title: Text(base + '/' + quote),
                                subtitle: Text(sym),
                                onTap: () {
                                  setState(() => _selectedPair = sym);
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (theme.brightness == Brightness.dark ? AppColors.outline : AppColors.lightOutline).withOpacity(0.20),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coin/Pair', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(_formatPairLabel(_selectedPair), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  String _formatPairLabel(String sym) {
    if (sym.endsWith('USDT')) return sym.replaceAll('USDT', '/USDT');
    if (sym.endsWith('USDC')) return sym.replaceAll('USDC', '/USDC');
    if (sym.endsWith('EUR')) return sym.replaceAll('EUR', '/EUR');
    return sym;
  }
}

