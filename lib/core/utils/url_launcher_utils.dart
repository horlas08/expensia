import 'package:url_launcher/url_launcher.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/material.dart';

class UrlLauncherUtils {
  static Future<void> launchWhatsApp(BuildContext context, String phoneNumber) async {
    // Basic normalization: remove non-digits
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final Uri uri = Uri.parse("https://wa.me/$cleanPhone");
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) _showError(context, 'Could not launch WhatsApp');
      }
    } catch (e) {
      if (context.mounted) _showError(context, 'Error launching WhatsApp: $e');
    }
  }

  static Future<void> launchCall(BuildContext context, String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) _showError(context, 'Could not launch dialer');
      }
    } catch (e) {
      if (context.mounted) _showError(context, 'Error launching dialer: $e');
    }
  }

  static void _showError(BuildContext context, String message) {
    toastification.show(
      context: context,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      type: ToastificationType.error,
      style: ToastificationStyle.minimal,
    );
  }
}
