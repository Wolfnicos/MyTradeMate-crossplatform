import 'package:flutter/material.dart';
import '../../../design_system/widgets/glass_card.dart';
import '../../../screens/orders_screen.dart';

class OrdersTile extends StatelessWidget {
  const OrdersTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Orders', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Place market, hybrid or AI orders quickly.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersScreen())),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Open Orders'),
            ),
          )
        ],
      ),
    );
  }
}


