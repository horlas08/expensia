import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

class BackupRestoreService {
  static Future<void> backupDatabase(BuildContext context) async {
    try {
      const dbName = 'expensia.db';
      final dbPath = await getDatabasesPath();
      final sourceFile = File(p.join(dbPath, dbName));

      if (!await sourceFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final params = SaveFileDialogParams(
        sourceFilePath: sourceFile.path,
        fileName: "backup_$dbName",
      );

      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (savedPath != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<bool> restoreDatabase(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select backup file',
        type: FileType.any,
        allowedExtensions: ['db'],
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);

        // Validate file exists
        if (!await pickedFile.exists()) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected file does not exist'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        final appDir = await getDatabasesPath();
        final dbFile = File(p.join(appDir, 'expensia.db'));

        // Create directory if it doesn't exist
        await Directory(appDir).create(recursive: true);

        // Copy the backup file
        await pickedFile.copy(dbFile.path);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return false;
  }
}
