import 'package:flutter/foundation.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/models/udhaar_entry.dart';

/// Holds the global application state for AwaazKhata.
///
/// Manages inventory, tasks, and udhaar (credit) lists. Screens read from
/// this provider and call its methods instead of manipulating data directly.
class AppState extends ChangeNotifier {
  AppState() {
    _loadDummyData();
  }

  final List<InventoryItem> _inventory = [];
  final List<Task> _tasks = [];
  final List<UdhaarEntry> _udhaar = [];

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

  /// Adds a new inventory item, automatically recording the creation time.
  void addInventoryItem(InventoryItem item) {
    _inventory.add(item.copyWith(createdAt: DateTime.now()));
    notifyListeners();
  }

  /// Updates an existing inventory item by id.
  void updateInventoryItem(InventoryItem updatedItem) {
    final index = _inventory.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _inventory[index] = updatedItem;
      notifyListeners();
    }
  }

  /// Removes an inventory item by id.
  void removeInventoryItem(String id) {
    _inventory.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  /// Adds a new task, automatically recording the creation time.
  void addTask(Task task) {
    _tasks.add(task.copyWith(createdAt: DateTime.now()));
    notifyListeners();
  }

  /// Updates an existing task by id.
  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  /// Toggles a task's completion status.
  void toggleTaskCompletion(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      notifyListeners();
    }
  }

  /// Removes a task by id.
  void removeTask(String id) {
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
  }

  /// Adds a new udhaar entry, automatically recording the creation time.
  void addUdhaar(UdhaarEntry entry) {
    _udhaar.add(entry.copyWith(createdAt: DateTime.now()));
    notifyListeners();
  }

  /// Updates an existing udhaar entry by id.
  void updateUdhaar(UdhaarEntry updatedEntry) {
    final index = _udhaar.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      _udhaar[index] = updatedEntry;
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
      notifyListeners();
    }
  }

  /// Removes an udhaar entry by id.
  void removeUdhaar(String id) {
    _udhaar.removeWhere((entry) => entry.id == id);
    notifyListeners();
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
