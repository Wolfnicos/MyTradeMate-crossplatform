import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../theme/app_theme.dart';

class ErrorHandler {
  /// Show user-friendly error message
  static void showError(BuildContext context, dynamic error, {String? title}) {
    final message = _getErrorMessage(error);
    
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Show success message
  static void showSuccess(BuildContext context, String message, {String? title}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Convert error to user-friendly message
  static String _getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    }
    
    if (error is FormatException) {
      return 'Invalid data format received.';
    }
    
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    
    if (error is Exception) {
      final message = error.toString();
      
      // Parse Binance API errors
      if (message.contains('401') || message.contains('Unauthorized')) {
        return 'Authentication failed. Please check your API keys.';
      }
      if (message.contains('429') || message.contains('Too many requests')) {
        return 'Too many requests. Please wait a moment.';
      }
      if (message.contains('insufficient') || message.contains('balance')) {
        return 'Insufficient balance for this order.';
      }
      if (message.contains('403') || message.contains('Forbidden')) {
        return 'Access denied. Check API permissions.';
      }
      if (message.contains('404') || message.contains('Not found')) {
        return 'Resource not found. Please try again.';
      }
      if (message.contains('500') || message.contains('Internal')) {
        return 'Server error. Please try again later.';
      }
      
      // Remove "Exception: " prefix
      return message.replaceAll('Exception: ', '').replaceAll('Error: ', '');
    }
    
    return 'An unexpected error occurred. Please try again.';
  }
  
  /// Handle async operation with error handling
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? errorTitle,
    String? successMessage,
  }) async {
    try {
      final result = await operation();
      
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      
      return result;
    } catch (e) {
      if (context.mounted) {
        showError(context, e, title: errorTitle);
      }
      return null;
    }
  }
}
