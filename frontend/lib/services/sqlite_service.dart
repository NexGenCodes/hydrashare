import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  factory SqliteService() => _instance;
  SqliteService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hydrashare.db');

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
            extra TEXT -- JSON string for extra data
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

  // Messages
  Future<void> saveMessage({
    required String peerIp,
    required String text,
    required bool isMe,
    String? type,
    String? extraJson,
  }) async {
    final db = await database;
    await db.insert('messages', {
      'peer_ip': peerIp,
      'text': text,
      'is_me': isMe ? 1 : 0,
      'type': type ?? 'text',
      'timestamp': DateTime.now().toIso8601String(),
      'extra': extraJson,
    });
  }

  Future<List<Map<String, dynamic>>> getHistory(String peerIp) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'peer_ip = ?',
      whereArgs: [peerIp],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return {...maps[i], 'isMe': maps[i]['is_me'] == 1};
    });
  }

  // Settings
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'];
  }

  // Maintenance
  Future<void> scrubOldMessages() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    int count = await db.delete(
      'messages',
      where: 'timestamp < ?',
      whereArgs: [sevenDaysAgo],
    );
    if (count > 0) {
      debugPrint('🗑️ SQLite Scrubber: Deleted $count old messages');
    }
  }
}
