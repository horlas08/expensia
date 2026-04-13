import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

Map<String, List<Map<String, dynamic>>> groupTransactionsByDate(List<Map<String, dynamic>> transactions, BuildContext context) {
  final Map<String, List<Map<String, dynamic>>> grouped = {};
  
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  for (var tx in transactions) {
    if (tx['date'] == null) continue;
    
    final date = DateTime.parse(tx['date']);
    final dateKey = DateTime(date.year, date.month, date.day);
    
    String headerText;
    if (dateKey == today) {
      headerText = 'history.today'.tr(); // E.g., "Today" if translation exists, or fallback string in en.json
      if (headerText == 'history.today') headerText = 'Today';
    } else if (dateKey == yesterday) {
      headerText = 'history.yesterday'.tr();
      if (headerText == 'history.yesterday') headerText = 'Yesterday';
    } else {
      headerText = DateFormat.yMMMd(context.locale.languageCode).format(date);
    }
    
    if (!grouped.containsKey(headerText)) {
      grouped[headerText] = [];
    }
    grouped[headerText]!.add(tx);
  }
  
  return grouped;
}
