import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/services/storage_service.dart';

/// Holds the global application state for AwaazKhata.
///
/// Manages inventory, tasks, and udhaar (credit) lists. Screens read from
/// this provider and call its methods instead of manipulating data directly.
///
/// All mutations write through to [StorageService] (Hive) so data survives
/// app restarts and force closes.
class AppState extends ChangeNotifier {
  AppState() {
    _loadFromStorage();
  }

  final List<InventoryItem> _inventory = [];
  final List<Task> _tasks = [];
  final List<UdhaarEntry> _udhaar = [];

  final StorageService _storage = StorageService.instance;

  /// Unmodifiable view of the inventory list.
  List<InventoryItem> get inventory => List.unmodifiable(_inventory);

  /// Unmodifiable view of the task list.
  List<Task> get tasks => List.unmodifiable(_tasks);

  /// Unmodifiable view of the udhaar list.
  List<UdhaarEntry> get udhaar => List.unmodifiable(_udhaar);

  /// Total outstanding udhaar amount (not yet paid).
  double get totalPendingUdhaar {
    return _udhaar
        .where((entry) => !entry.isPaid)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  /// Number of inventory items that are at or below their minimum stock level.
  int get lowStockCount {
    return _inventory.where((item) => item.isLowStock).length;
  }

  /// Number of tasks that are still pending.
  int get pendingTaskCount {
    return _tasks.where((task) => !task.isCompleted).length;
  }

  /// Loads persisted data on startup. If nothing has been saved yet, seeds
  /// the realistic demo data so first-time users see a navigable UI.
  void _loadFromStorage() {
    _inventory.addAll(_storage.inventory);
    _tasks.addAll(_storage.tasks);
    _udhaar.addAll(_storage.udhaar);

    if (_inventory.isEmpty && _tasks.isEmpty && _udhaar.isEmpty) {
      _loadDummyData();
      _persistAll();
    }
  }

  void _persistInventory() {
    _storage.saveInventory(_inventory);
  }

  void _persistTasks() {
    _storage.saveTasks(_tasks);
  }

  void _persistUdhaar() {
    _storage.saveUdhaar(_udhaar);
  }

  void _persistAll() {
    _persistInventory();
    _persistTasks();
    _persistUdhaar();
  }

  /// Adds a new inventory item, automatically recording the creation time.
  void addInventoryItem(InventoryItem item) {
    _inventory.add(item.copyWith(createdAt: DateTime.now()));
    _persistInventory();
    notifyListeners();
  }

  /// Updates an existing inventory item by id.
  void updateInventoryItem(InventoryItem updatedItem) {
    final index = _inventory.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _inventory[index] = updatedItem;
      _persistInventory();
      notifyListeners();
    }
  }

  /// Removes an inventory item by id.
  void removeInventoryItem(String id) {
    _inventory.removeWhere((item) => item.id == id);
    _persistInventory();
    notifyListeners();
  }

  /// Adds a new task, automatically recording the creation time.
  void addTask(Task task) {
    _tasks.add(task.copyWith(createdAt: DateTime.now()));
    _persistTasks();
    notifyListeners();
  }

  /// Updates an existing task by id.
  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      _persistTasks();
      notifyListeners();
    }
  }

  /// Toggles a task's completion status.
  void toggleTaskCompletion(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      _persistTasks();
      notifyListeners();
    }
  }

  /// Removes a task by id.
  void removeTask(String id) {
    _tasks.removeWhere((task) => task.id == id);
    _persistTasks();
    notifyListeners();
  }

  /// Adds a new udhaar entry, automatically recording the creation time.
  void addUdhaar(UdhaarEntry entry) {
    _udhaar.add(entry.copyWith(createdAt: DateTime.now()));
    _persistUdhaar();
    notifyListeners();
  }

  /// Updates an existing udhaar entry by id.
  void updateUdhaar(UdhaarEntry updatedEntry) {
    final index = _udhaar.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      _udhaar[index] = updatedEntry;
      _persistUdhaar();
      notifyListeners();
    }
  }

  /// Marks an udhaar entry as paid.
  void markUdhaarPaid(String id) {
    final index = _udhaar.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      final entry = _udhaar[index];
      _udhaar[index] = entry.copyWith(
        isPaid: true,
        paidAt: DateTime.now(),
      );
      _persistUdhaar();
      notifyListeners();
    }
  }

  /// Removes an udhaar entry by id.
  void removeUdhaar(String id) {
    _udhaar.removeWhere((entry) => entry.id == id);
    _persistUdhaar();
    notifyListeners();
  }

  /// Clears all locally persisted records and in-memory lists.
  ///
  /// Used by the settings "clear old records" action.
  Future<void> clearAllRecords() async {
    _inventory.clear();
    _tasks.clear();
    _udhaar.clear();
    await _storage.clearAll();
    notifyListeners();
  }

  /// Finds unsettled udhaar entries whose customer name closely matches
  /// [name], best match first.
  ///
  /// Voice transcripts rarely match stored names exactly ("Ahmad Khan" vs
  /// "Ahmed Khan"), so matching is case-insensitive and tolerant: exact,
  /// prefix ("ahmad" → "Ahmad Khan"), word-subset ("khan" → "Ahmed Khan"),
  /// and fuzzy spelling variants all count. Settled entries are excluded —
  /// new credit for a customer whose previous entry is paid should start a
  /// fresh entry, not resurrect the old one.
  List<UdhaarEntry> findUdhaarMatches(String name) {
    final scored = <(double, UdhaarEntry)>[];
    for (final entry in _udhaar) {
      if (entry.isPaid) continue;
      final score = _nameMatchScore(name, entry.customerName);
      if (score >= 0.75) scored.add((score, entry));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      if (byScore != 0) return byScore;
      return b.$2.createdAt.compareTo(a.$2.createdAt);
    });
    return [for (final match in scored) match.$2];
  }

  /// Finds ALL udhaar entries (settled included) whose customer name closely
  /// matches [name], newest first. Used by the per-client ledger screen to
  /// show a customer's full transaction history.
  List<UdhaarEntry> findUdhaarHistory(String name) {
    final scored = <(double, UdhaarEntry)>[];
    for (final entry in _udhaar) {
      final score = _nameMatchScore(name, entry.customerName);
      if (score >= 0.75) scored.add((score, entry));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      if (byScore != 0) return byScore;
      return b.$2.createdAt.compareTo(a.$2.createdAt);
    });
    return [for (final match in scored) match.$2];
  }

  /// Finds inventory items whose name closely matches [name], best match
  /// first. Uses the same tolerant rules as [findUdhaarMatches].
  List<InventoryItem> findInventoryMatches(String name) {
    final scored = <(double, InventoryItem)>[];
    for (final item in _inventory) {
      final score = _nameMatchScore(name, item.name);
      if (score >= 0.75) scored.add((score, item));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      if (byScore != 0) return byScore;
      return b.$2.createdAt.compareTo(a.$2.createdAt);
    });
    return [for (final match in scored) match.$2];
  }

  /// Scores how closely a spoken [query] matches a stored [candidate] name.
  ///
  /// Returns 0 for no match, 1 for exact. Tiers (highest wins):
  /// exact 1.0, prefix 0.9, all-query-words-present 0.85, fuzzy ≥ 0.8.
  static double _nameMatchScore(String query, String candidate) {
    final q = _normalizeName(query);
    final c = _normalizeName(candidate);
    if (q.isEmpty || c.isEmpty) return 0;

    if (q == c) return 1;
    if (q.length >= 3 && (c.startsWith(q) || q.startsWith(c))) return 0.9;

    final qWords = q.split(' ');
    final cWords = c.split(' ');
    if (qWords.length <= cWords.length &&
        qWords.every((word) => cWords.contains(word))) {
      return 0.85;
    }

    final full = _similarity(q, c);
    if (full >= 0.8) return full;

    // Single spoken word against a multi-word stored name — "ahmad"
    // should still find "Ahmed Khan".
    if (qWords.length == 1 && cWords.length > 1) {
      var best = 0.0;
      for (final word in cWords) {
        best = math.max(best, _similarity(qWords[0], word));
      }
      if (best >= 0.8) return best * 0.95;
    }
    return 0;
  }

  static String _normalizeName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Normalized Levenshtein similarity: 1 = identical, 0 = completely
  /// different.
  static double _similarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;

    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = math.min(
          math.min(prev[j] + 1, curr[j - 1] + 1),
          prev[j - 1] + cost,
        );
      }
      final swap = prev;
      prev = curr;
      curr = swap;
    }
    return 1 - prev[b.length] / math.max(a.length, b.length);
  }

  /// Seeds the app with realistic demo data so the UI is navigable
  /// before the backend and voice features are wired in.
  void _loadDummyData() {
    final now = DateTime.now();

    _inventory.addAll([
      InventoryItem(
        id: 'inv-001',
        name: 'Dalda Cooking Oil 1L',
        category: 'Grocery',
        quantity: 24,
        unit: 'bottle',
        purchasePrice: 380.0,
        salePrice: 420.0,
        minStockLevel: 10,
        supplierName: 'Ali General Store',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      InventoryItem(
        id: 'inv-002',
        name: 'Tapal Danedar 900g',
        category: 'Tea & Coffee',
        quantity: 8,
        unit: 'pack',
        purchasePrice: 1050.0,
        salePrice: 1150.0,
        minStockLevel: 10,
        supplierName: 'Wholesale Bazaar',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      InventoryItem(
        id: 'inv-003',
        name: 'Shan Biryani Masala',
        category: 'Spices',
        quantity: 45,
        unit: 'pack',
        purchasePrice: 55.0,
        salePrice: 70.0,
        minStockLevel: 20,
        supplierName: 'Spice Hub',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      InventoryItem(
        id: 'inv-004',
        name: 'Nestle Milkpak 1L',
        category: 'Dairy',
        quantity: 30,
        unit: 'carton',
        purchasePrice: 180.0,
        salePrice: 200.0,
        minStockLevel: 15,
        supplierName: 'Dairy Fresh',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      InventoryItem(
        id: 'inv-005',
        name: 'Surf Excel 1kg',
        category: 'Household',
        quantity: 12,
        unit: 'pack',
        purchasePrice: 320.0,
        salePrice: 360.0,
        minStockLevel: 12,
        supplierName: 'Home Care Distributors',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ]);

    _tasks.addAll([
      Task(
        id: 'task-001',
        title: 'Subah dukaan kholo 9 baje',
        description: 'Voice reminder to open the shop on time.',
        createdAt: now.subtract(const Duration(days: 1)),
        dueAt: now.add(const Duration(hours: 8)),
        priority: TaskPriority.high,
      ),
      Task(
        id: 'task-002',
        title: 'Ali supplier se oil ki stock le kar aao',
        description: 'Restock Dalda oil before weekend rush.',
        createdAt: now.subtract(const Duration(hours: 6)),
        dueAt: now.add(const Duration(days: 1)),
        priority: TaskPriority.normal,
      ),
      Task(
        id: 'task-003',
        title: 'Monthly sale summary banayein',
        description: 'Prepare summary for business review.',
        createdAt: now.subtract(const Duration(days: 2)),
        dueAt: now.add(const Duration(days: 3)),
        priority: TaskPriority.low,
      ),
    ]);

    _udhaar.addAll([
      UdhaarEntry(
        id: 'udh-001',
        customerName: 'Ahmed Khan',
        phoneNumber: '03001234567',
        amount: 1500.0,
        description: 'Groceries on credit - 2 Sep',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      UdhaarEntry(
        id: 'udh-002',
        customerName: 'Fatima Bibi',
        phoneNumber: '03009876543',
        amount: 850.0,
        description: 'Tea and spices',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      UdhaarEntry(
        id: 'udh-003',
        customerName: 'Bilal Ahmed',
        phoneNumber: '03005551234',
        amount: 3200.0,
        description: 'Monthly credit for general store items',
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      UdhaarEntry(
        id: 'udh-004',
        customerName: 'Sana Malik',
        phoneNumber: '03007778899',
        amount: 500.0,
        description: 'Dairy products',
        createdAt: now.subtract(const Duration(days: 1)),
        isPaid: true,
        paidAt: now,
      ),
    ]);
  }
}
