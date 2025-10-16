import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/widgets/glass_card.dart';
import '../../../providers/navigation_provider.dart';

class QuickTradeTile extends StatelessWidget {
  const QuickTradeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Trade', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(3),
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Buy/Sell'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}


