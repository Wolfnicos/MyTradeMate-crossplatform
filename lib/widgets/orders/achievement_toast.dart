import 'package:flutter/material.dart';
import '../../services/achievement_service.dart';

class AchievementToast {
  static void show(BuildContext context, String id, String message) {
    if (!AchievementService().isUnlocked(id)) {
      AchievementService().unlock(id);
      final snack = SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      );
      ScaffoldMessenger.of(context).showSnackBar(snack);
    }
  }
}


