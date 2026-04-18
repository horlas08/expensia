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
import 'shared_preferences_service.dart';
import 'database_service.dart';
import '../models/user_setup_model.dart';



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

  static Future<bool> backupDatabase(BuildContext context) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourceFile = File(p.join(dbPath, _dbName));

      if (!await sourceFile.exists()) {
        if (context.mounted) {
          _showError(context, 'setup.error'.tr());
        }
        return false;
      }

      final params = SaveFileDialogParams(
        sourceFilePath: sourceFile.path,
        fileName: "backup_$_dbName",
      );

      final savedPath = await FlutterFileDialog.saveFile(params: params);

      if (savedPath != null && context.mounted) {
        _showSuccess(context, 'setup.success'.tr());
        return true;
      }
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
    return false;
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

        // Close existing connection before overwriting
        await DatabaseService().closeConnection();

        await pickedFile.copy(dbFile.path);
        
        // Reset singleton to pick up new file
        DatabaseService().resetInstance();

        // Sync settings from restored DB to SharedPreferences
        await _syncSettingsWithPrefs();
        
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
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBuffer = [];
      await media.stream.forEach((chunk) => dataBuffer.addAll(chunk));

      final appDir = await getDatabasesPath();
      final dbFile = File(p.join(appDir, _dbName));
      
      // Close existing connection before overwriting
      await DatabaseService().closeConnection();
      
      await dbFile.writeAsBytes(dataBuffer);

      // Reset singleton to pick up new file
      DatabaseService().resetInstance();

      // Sync settings from restored DB to SharedPreferences
      await _syncSettingsWithPrefs();

      return true;
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
      return false;
    }
  }

  static Future<bool> backupToGoogleDrive(BuildContext context) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final dbPath = await getDatabasesPath();
      final file = File(p.join(dbPath, _dbName));

      final driveFile = drive.File();
      driveFile.name = _backupFileName;
      driveFile.parents = ['appDataFolder'];

      final response = await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
      );

      if (response.id != null && context.mounted) {
        _showSuccess(context, 'setup.success'.tr());
        return true;
      }
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
    return false;
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

  static Future<void> _syncSettingsWithPrefs() async {
    try {
      final dbService = DatabaseService();
      // Ensure we are working with the fresh database from file
      final db = await dbService.database;
      final settingsList = await db.query('settings', limit: 1);
      
      if (settingsList.isNotEmpty) {
        final settings = settingsList.first;
        final prefs = await SharedPreferencesService.getInstance();
        
        final int? currencyId = settings['default_currency_id'] as int?;
        final String? userName = settings['user_name'] as String?;
        debugPrint('Restored settings currencyId: $currencyId, userName: $userName');

        // 1. Mark onboarding completed
        await prefs.setFirstPageCompleted();

        // 2. Sync User Name
        if (userName != null) {
          await prefs.setUserName(userName);
        }

        // 3. Sync Default Currency
        if (currencyId != null) {
          final currencies = await db.query(
            'all_currencies', 
            where: 'id = ?', 
            whereArgs: [currencyId],
            limit: 1
          );
          
          if (currencies.isNotEmpty) {
            final currencyModel = CurrencyModel.fromMap(currencies.first);
            await prefs.setDefaultCurrency(currencyModel);
            debugPrint('Synced currency: ${currencyModel.currencyCode} (${currencyModel.currencySymbol})');
          }
        }

        // 4. Fetch actual cash balance from wallets table
        final wallets = await db.query(
          'wallets', 
          where: 'type = ?', 
          whereArgs: ['cash'],
          limit: 1
        );
        final double cashBalance = wallets.isNotEmpty 
            ? (wallets.first['balance'] as num?)?.toDouble() ?? 0.0 
            : 0.0;

        // 5. Sync User Setup Model
        final userSetup = UserSetupModel(
          name: userName ?? '',
          defaultCurrency: currencyId ?? 1,
          cash: cashBalance,
          salary: (settings['salary_amount'] as num?)?.toDouble() ?? 0.0,
          dayOfSalary: settings['salary_day'] as int? ?? 1,
          autoAddSalary: (settings['auto_add_salary'] as int? ?? 0) == 1,
          startThisMonth: false,
          isOptions: ((settings['salary_amount'] as num?)?.toDouble() ?? 0.0) > 0,
        );
        await prefs.setUserSetup(userSetup.toMap());

        debugPrint('Settings synced from restored database successfully for $userName.');
      } else {
        debugPrint('No settings found in restored database.');
      }
    } catch (e) {
      debugPrint('Error syncing settings: $e');
    }
  }
}
