import 'dart:io';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cointally/core/services/cloud_auth_service.dart';
import 'dart:developer';

class DriveService {
  static const String BACKUP_FILENAME = 'cointally_backup.db';

  Future<drive.File?> findBackup() async {
    final client = await CloudAuthService().getAuthenticatedClient();
    if (client == null) return null;

    final driveApi = drive.DriveApi(client);
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$BACKUP_FILENAME'",
      $fields: "files(id, name, modifiedTime)",
    );

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first;
    }
    return null;
  }

  Future<bool> uploadBackup() async {
    try {
      final client = await CloudAuthService().getAuthenticatedClient();
      if (client == null) return false;

      final driveApi = drive.DriveApi(client);
      
      // Get local DB path
      final databasesPath = await getDatabasesPath();
      final localPath = join(databasesPath, 'hisaabmate.db');
      final file = File(localPath);

      if (!await file.exists()) {
        log("Local database file not found at $localPath");
        return false;
      }

      // EXPORT: Save shared preferences into the DB before uploading
      await _exportPreferencesToDb(localPath);

      // Check if file exists to overwrite or create
      final existingFile = await findBackup();
      
      final media = drive.Media(file.openRead(), await file.length());
      final driveFile = drive.File();
      driveFile.name = BACKUP_FILENAME;

      if (existingFile != null) {
        log("Updating existing backup...");
        await driveApi.files.update(driveFile, existingFile.id!, uploadMedia: media);
      } else {
        log("Creating new backup...");
        driveFile.parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      return true;
    } catch (e) {
      log("Upload Backup Error: $e");
      return false;
    }
  }

  Future<bool> restoreBackup() async {
    try {
      final client = await CloudAuthService().getAuthenticatedClient();
      if (client == null) return false;

      final backupFile = await findBackup();
      if (backupFile == null || backupFile.id == null) return false;

      final driveApi = drive.DriveApi(client);
      
      // Actually download the file
      final media = await driveApi.files.get(backupFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      final databasesPath = await getDatabasesPath();
      final localPath = join(databasesPath, 'hisaabmate.db');
      final file = File(localPath);

      // Write to local file
      List<int> dataStore = [];
      await for (final data in media.stream) {
        dataStore.addAll(data);
      }
      await file.writeAsBytes(dataStore);
      
      // RESTORE: Load shared preferences from the DB after downloading
      await _restorePreferencesFromDb(localPath);
      
      log("Restore successful. Replacement path: $localPath");
      return true;
    } catch (e) {
      log("Restore Backup Error: $e");
      return false;
    }
  }

  Future<String> getDatabasesPath() async {
    return await sqflite.getDatabasesPath();
  }

  Future<void> _exportPreferencesToDb(String dbPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final db = await sqflite.openDatabase(dbPath);
      
      // Ensure the table exists in case migration hasn't run yet
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_preferences (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          type TEXT NOT NULL
        )
      ''');
      
      await db.transaction((txn) async {
        for (String key in keys) {
          final value = prefs.get(key);
          if (value == null) continue;
          
          String type = 'String';
          String stringValue = value.toString();
          
          if (value is bool) type = 'bool';
          else if (value is int) type = 'int';
          else if (value is double) type = 'double';
          else if (value is List<String>) {
            type = 'StringList';
            stringValue = jsonEncode(value);
          }
          
          await txn.insert(
            'app_preferences',
            {'key': key, 'value': stringValue, 'type': type},
            conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
          );
        }
      });
      
      log("Exported ${keys.length} preferences to database.");
    } catch (e) {
      log("Error exporting preferences: $e");
    }
  }

  Future<void> _restorePreferencesFromDb(String dbPath) async {
    try {
      final db = await sqflite.openDatabase(dbPath);
      
      // Check if table exists
      final tables = await db.query('sqlite_master', where: 'name = ?', whereArgs: ['app_preferences']);
      if (tables.isEmpty) {
        log("No app_preferences table found in restored database.");
        return;
      }
      
      final List<Map<String, dynamic>> rows = await db.query('app_preferences');
      final prefs = await SharedPreferences.getInstance();
      
      for (var row in rows) {
        final key = row['key'] as String;
        final value = row['value'] as String;
        final type = row['type'] as String;
        
        switch (type) {
          case 'bool':
            await prefs.setBool(key, value.toLowerCase() == 'true');
            break;
          case 'int':
            await prefs.setInt(key, int.parse(value));
            break;
          case 'double':
            await prefs.setDouble(key, double.parse(value));
            break;
          case 'StringList':
            final list = (jsonDecode(value) as List).cast<String>();
            await prefs.setStringList(key, list);
            break;
          default:
            await prefs.setString(key, value);
        }
      }
      
      log("Restored ${rows.length} preferences from database.");
    } catch (e) {
      log("Error restoring preferences: $e");
    }
  }
}
