import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing20,
                      AppTheme.spacing24,
                      AppTheme.spacing20,
                      AppTheme.spacing16,
                    ),
                    child: Text('Portfolio', style: AppTheme.displayLarge),
                  ),
                ),

                // Portfolio Value Card - Scrollable
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
                    child: const _PortfolioValueCard(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: const SizedBox(height: AppTheme.spacing20),
                ),

                // TabBar - Sticky
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    const TabBar(
                      indicatorColor: AppTheme.primary,
                      labelColor: AppTheme.textPrimary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      tabs: [
                        Tab(text: 'Holdings'),
                        Tab(text: 'History'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _HoldingsList(),
                _buildHistoryTab(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            'Transaction History',
            style: AppTheme.headingLarge.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Your trading history will appear here',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _PortfolioValueCard extends StatelessWidget {
  const _PortfolioValueCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  'Total Portfolio Value',
                  style: AppTheme.headingMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing20),
          Text(
            r'$122,000',
            style: AppTheme.displayLarge.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.buyGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(
                color: AppTheme.buyGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, color: AppTheme.buyGreen, size: 18),
                  const SizedBox(width: AppTheme.spacing8),
                  Flexible(
                    child: Text(
                      r'+$4,200 Today',
                      style: AppTheme.headingSmall.copyWith(color: AppTheme.buyGreen),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    '(+3.44%)',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.buyGreen),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final holdings = [
      _HoldingData('Bitcoin', 'BTC', '1.5 BTC', r'$51,750', '+4.5%', true, Icons.currency_bitcoin),
      _HoldingData('Ethereum', 'ETH', '10 ETH', r'$21,000', '-2.1%', false, Icons.diamond_outlined),
      _HoldingData('BNB', 'BNB', '20 BNB', r'$6,000', '+1.8%', true, Icons.attach_money),
      _HoldingData('Solana', 'SOL', '50 SOL', r'$8,500', '-5.3%', false, Icons.sunny),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      itemCount: holdings.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
          child: _HoldingCard(holding: holdings[index]),
        );
      },
    );
  }
}

class _HoldingData {
  final String name;
  final String symbol;
  final String amount;
  final String value;
  final String pnl;
  final bool isGain;
  final IconData icon;

  _HoldingData(this.name, this.symbol, this.amount, this.value, this.pnl, this.isGain, this.icon);
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}

class _HoldingCard extends StatelessWidget {
  final _HoldingData holding;

  const _HoldingCard({required this.holding});

  @override
  Widget build(BuildContext context) {
    final pnlColor = holding.isGain ? AppTheme.buyGreen : AppTheme.sellRed;

    return GlassCard(
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: holding.isGain ? AppTheme.buyGradient : AppTheme.sellGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(
              holding.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacing16),

          // Name & Amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.name,
                  style: AppTheme.headingMedium,
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  holding.amount,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Value & PnL
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                holding.value,
                style: AppTheme.headingMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: pnlColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  holding.pnl,
                  style: AppTheme.bodySmall.copyWith(
                    color: pnlColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
