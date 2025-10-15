import 'package:flutter/material.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isBuy = true;
  bool isPaperTrading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = isBuy ? theme.colorScheme.secondary : theme.colorScheme.error;

    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // Header with title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Orders', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          // TabBar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Trade'),
              Tab(text: 'Paper Mode'),
            ],
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
            // Buy/Sell toggle
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isBuy = true),
                      child: Container(
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
                      child: Container(
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
            const SizedBox(height: 24),
            _buildTextField(label: 'Coin/Pair', hint: 'BTC/USDT', icon: Icons.search),
            const SizedBox(height: 16),
            _buildTextField(label: 'Amount', hint: '0.05 BTC'),
            const SizedBox(height: 16),
            _buildTextField(label: 'Limit Price', hint: '\$34,500'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paper Trading'),
                Switch(
                  value: isPaperTrading,
                  onChanged: (value) {
                    setState(() {
                      isPaperTrading = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: Colors.white,
                ),
                child: Text(isBuy ? 'Buy BTC' : 'Sell BTC', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
              ],
            ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, IconData? icon}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge?.copyWith(color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: icon != null ? Icon(icon) : null,
          ),
        ),
      ],
    );
  }
}

