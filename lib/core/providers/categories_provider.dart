import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

/// Provider for categories filtered by type.
/// Loads data directly from the SQLite database.
final categoriesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, type) async {
  final db = DatabaseService();
  return db.getCategoriesByType(type);
});
