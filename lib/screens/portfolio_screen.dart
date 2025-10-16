import 'package:flutter/material.dart';
import '../design_system/screen_backgrounds.dart';
import '../design_system/widgets/glass_card.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            decoration: ScreenBackgrounds.market(context),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Text('Portfolio', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: const PortfolioValueCard(),
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      const TabBar(
                        tabs: [
                          Tab(text: 'Holdings'),
                          Tab(text: 'History'),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: const TabBarView(
                children: [
                  HoldingsList(),
                  Center(child: Text('Transaction history will be displayed here.')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PortfolioValueCard extends StatelessWidget {
  const PortfolioValueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gainColor = theme.colorScheme.secondary;

    return GlassCard(
      padding: const EdgeInsets.all(20.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Portfolio Value', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(r'$122,000', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(r'+$4,200 Today', style: theme.textTheme.titleMedium?.copyWith(color: gainColor, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_upward, color: gainColor, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HoldingsList extends StatelessWidget {
  const HoldingsList({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(padding: const EdgeInsets.all(16), child: _buildHoldingRow(context, 'Bitcoin', '1.5 BTC', r'$51,750', '+4.5%', true)),
        const SizedBox(height: 12),
        GlassCard(padding: const EdgeInsets.all(16), child: _buildHoldingRow(context, 'Ethereum', '10 ETH', r'$21,000', '-8.2%', false)),
        const SizedBox(height: 12),
        GlassCard(padding: const EdgeInsets.all(16), child: _buildHoldingRow(context, 'BNB', '20 BNB', r'$6,000', '-15.3%', false)),
      ],
    );
  }

  Widget _buildHoldingRow(BuildContext context, String name, String amount, String value, String pnl, bool isGain) {
    final theme = Theme.of(context);
    final color = isGain ? theme.colorScheme.secondary : theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            child: Text(name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(amount, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(pnl, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper class pentru TabBar fix
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

