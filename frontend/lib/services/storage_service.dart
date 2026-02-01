import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<void> init() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await _database;
    await _migrateFromJsonIfNeeded();
    await _cleanupOldMessages();
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'hydrashare_v2.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peer_ip TEXT,
            text TEXT,
            is_me INTEGER,
            type TEXT,
            timestamp TEXT,
            extra TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  Future<void> _migrateFromJsonIfNeeded() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final historyFile = File('${directory.path}/hydrashare_history.json');

      if (await historyFile.exists()) {
        debugPrint('📦 Migrating history from JSON to SQLite...');
        final content = await historyFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final messages = List<Map<String, dynamic>>.from(
          data['messages'] ?? [],
        );

        final db = await _database;
        await db.transaction((txn) async {
          for (var msg in messages) {
            await txn.insert('messages', {
              'peer_ip': msg['peerIp'],
              'text': msg['text'],
              'is_me': msg['isMe'] == true ? 1 : 0,
              'type': msg['type'] ?? 'text',
              'timestamp': msg['timestamp'] ?? DateTime.now().toIso8601String(),
              'extra': jsonEncode(
                msg..removeWhere(
                  (k, v) => [
                    'peerIp',
                    'text',
                    'isMe',
                    'type',
                    'timestamp',
                  ].contains(k),
                ),
              ),
            });
          }
        });

        // Rename or delete old file to prevent re-migration
        await historyFile.rename(
          '${directory.path}/hydrashare_history.json.bak',
        );
        debugPrint('✅ Migration complete and old file backed up.');
      }
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
    }
  }

  // Settings
  Future<dynamic> getSetting(String key) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (maps.isEmpty) return null;

      // Try to decode as JSON (dynamic value)
      final val = maps.first['value'] as String;
      try {
        return jsonDecode(val);
      } catch (_) {
        return val;
      }
    } catch (e) {
      debugPrint('Error loading setting $key: $e');
      return null;
    }
  }

  Future<void> saveSetting(String key, dynamic value) async {
    try {
      final db = await _database;
      final stringVal = (value is String) ? value : jsonEncode(value);
      await db.insert('settings', {
        'key': key,
        'value': stringVal,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHistory(String peerIp) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'peer_ip = ?',
        whereArgs: [peerIp],
        orderBy: 'timestamp ASC',
      );

      return List.generate(maps.length, (i) {
        final Map<String, dynamic> msg = Map<String, dynamic>.from(maps[i]);
        // Reconstruct expected JSON format for UI
        final extra = msg['extra'] != null
            ? jsonDecode(msg['extra']) as Map<String, dynamic>
            : {};
        return {
          'peerIp': msg['peer_ip'],
          'text': msg['text'],
          'isMe': msg['is_me'] == 1,
          'type': msg['type'],
          'timestamp': msg['timestamp'],
          ...extra,
        };
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return [];
    }
  }

  Future<void> saveMessage({
    required String peerIp,
    required String text,
    required bool isMe,
    String? type,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final db = await _database;
      await db.insert('messages', {
        'peer_ip': peerIp,
        'text': text,
        'is_me': isMe ? 1 : 0,
        'type': type ?? 'text',
        'timestamp': DateTime.now().toIso8601String(),
        'extra': extra != null ? jsonEncode(extra) : null,
      });
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<void> _cleanupOldMessages() async {
    try {
      final db = await _database;
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();
      int count = await db.delete(
        'messages',
        where: 'timestamp < ?',
        whereArgs: [sevenDaysAgo],
      );
      if (count > 0) {
        debugPrint('🧹 SQLite Scrubber: Deleted $count old messages');
      }
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }
}
