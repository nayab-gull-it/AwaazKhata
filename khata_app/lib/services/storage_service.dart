import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/models/udhaar_entry.dart';

/// Local persistence layer backed by Hive.
///
/// Each entity type is stored in its own box as a list of JSON-encoded maps.
/// This keeps the models free of Hive-specific adapters while still giving
/// us fast, local NoSQL storage that survives app restarts and force closes.
class StorageService {
  StorageService._();

  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;

  static const _inventoryBox = 'inventory_box';
  static const _tasksBox = 'tasks_box';
  static const _udhaarBox = 'udhaar_box';

  static const _inventoryKey = 'inventory';
  static const _tasksKey = 'tasks';
  static const _udhaarKey = 'udhaar';

  bool _initialized = false;

  /// Initializes Hive and opens the three boxes.
  ///
  /// Must be called once before the app reads or writes any data.
  Future<void> initialize() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox<String>(_inventoryBox);
    await Hive.openBox<String>(_tasksBox);
    await Hive.openBox<String>(_udhaarBox);
    _initialized = true;
  }

  Box<String> get _inventory => Hive.box<String>(_inventoryBox);
  Box<String> get _tasks => Hive.box<String>(_tasksBox);
  Box<String> get _udhaar => Hive.box<String>(_udhaarBox);

  List<InventoryItem> get inventory {
    final raw = _inventory.get(_inventoryKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(InventoryItem.fromJson)
        .toList();
  }

  Future<void> saveInventory(List<InventoryItem> items) async {
    final payload = jsonEncode(items.map((i) => i.toJson()).toList());
    await _inventory.put(_inventoryKey, payload);
  }

  List<Task> get tasks {
    final raw = _tasks.get(_tasksKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(Task.fromJson).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final payload = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await _tasks.put(_tasksKey, payload);
  }

  List<UdhaarEntry> get udhaar {
    final raw = _udhaar.get(_udhaarKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(UdhaarEntry.fromJson).toList();
  }

  Future<void> saveUdhaar(List<UdhaarEntry> entries) async {
    final payload = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _udhaar.put(_udhaarKey, payload);
  }

  /// Clears all locally persisted data. Used by the "clear old records"
  /// settings action.
  Future<void> clearAll() async {
    await _inventory.delete(_inventoryKey);
    await _tasks.delete(_tasksKey);
    await _udhaar.delete(_udhaarKey);
  }
}
