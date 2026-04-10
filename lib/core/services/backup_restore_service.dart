import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class BackupRestoreService {
  static const String _dbName = 'expensia.db';
  static const String _backupFileName = 'expensia_backup.db';

  static final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn.instance;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize();
      _initialized = true;
    }
  }

  static Future<drive.DriveApi?> _getDriveApi() async {
    try {
      await _ensureInitialized();
      
      // 1. Authenticate (Sign In)
      final account = await _googleSignIn.authenticate();
      // Note: In gsi 7.x, authenticate() returns non-nullable or throws

      // 2. Authorize Scopes
      final scopes = [drive.DriveApi.driveAppdataScope];
      final authorization = await account.authorizationClient.authorizeScopes(scopes);
      
      // 3. Get Authenticated Client
      final client = authorization.authClient(scopes: scopes);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('Error getting Drive API: $e');
      return null;
    }
  }

  static Future<void> backupDatabase(BuildContext context) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(p.join(dbPath, _dbName));

      if (!await sourceFile.exists()) {
        if (context.mounted) {
          _showError(context, 'setup.error'.tr());
        }
        return;
      }

      final params = SaveFileDialogParams(
        sourceFilePath: sourceFile.path,
        fileName: "backup_$_dbName",
      );

      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (savedPath != null && context.mounted) {
        _showSuccess(context, 'setup.success'.tr());
      }
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  static Future<bool> restoreDatabase(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'get_started.restore_from_file'.tr(),
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        final appDir = await getDatabasesPath();
        final dbFile = File(p.join(appDir, _dbName));

        await pickedFile.copy(dbFile.path);
        return true;
      }
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
    return false;
  }

  static Future<bool> restoreFromGoogleDrive(BuildContext context) async {
    try {
      final drive.DriveApi? driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // Find the backup file in AppData folder
      final drive.FileList fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        if (context.mounted) _showError(context, 'get_started.drive_no_backup'.tr());
        return false;
      }

      final drive.File file = fileList.files!.first;
      final drive.Media media = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.metadata,
      ) as drive.Media;

      final List<int> dataBuffer = [];
      await media.stream.forEach((chunk) => dataBuffer.addAll(chunk));

      final appDir = await getDatabasesPath();
      final dbFile = File(p.join(appDir, _dbName));
      await dbFile.writeAsBytes(dataBuffer);

      return true;
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
      return false;
    }
  }

  static Future<void> backupToGoogleDrive(BuildContext context) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return;

      final dbPath = await getDatabasesPath();
      final sourceFile = File(p.join(dbPath, _dbName));

      final drive.File fileMetadata = drive.File();
      fileMetadata.name = _backupFileName;
      fileMetadata.parents = ['appDataFolder'];

      final drive.Media media = drive.Media(
        sourceFile.openRead(),
        sourceFile.lengthSync(),
      );

      await driveApi.files.create(fileMetadata, uploadMedia: media);

      if (context.mounted) _showSuccess(context, 'setup.success'.tr());
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  static void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
