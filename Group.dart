import 'dart:io';

// ---------- MODELS ----------
class Staff {
  final String username;
  final String password;
  final String role; // Admin or Pharmacist
  Staff(this.username, this.password, this.role);
}

class Medicine {
  final int id;
  String name;
  String category;
  double price;
  int quantity;
  int reorderLevel;
  DateTime expiryDate;

  Medicine(this.id, this.name, this.category, this.price, this.quantity,
      this.reorderLevel, this.expiryDate);

  bool get isLowStock => quantity <= reorderLevel;
  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool isExpiringSoon(int days) =>
      !isExpired && expiryDate.difference(DateTime.now()).inDays <= days;
}

class Sale {
  final int id;
  final Medicine medicine;
  final int quantity;
  final double total;
  final DateTime date;
  final String soldBy;
  Sale(this.id, this.medicine, this.quantity, this.total, this.date,
      this.soldBy);
}

// ---------- CORE LOGIC ----------
class PharmTrack {
  final List<Staff> staffList = [
    Staff('admin', 'admin123', 'Admin'),
    Staff('musu', 'pharma123', 'Pharmacist'),
  ];
  final List<Medicine> medicines = [];
  final List<Sale> sales = [];
  int _nextMedicineId = 1;
  int _nextSaleId = 1;
  Staff? currentUser;

  bool login(String username, String password) {
    for (final s in staffList) {
      if (s.username == username && s.password == password) {
        currentUser = s;
        return true;
      }
    }
    return false;
  }

  bool get isAdmin => currentUser?.role == 'Admin';

  Medicine addMedicine(String name, String category, double price, int qty,
      int reorderLevel, DateTime expiry) {
    final m =
        Medicine(_nextMedicineId++, name, category, price, qty, reorderLevel, expiry);
    medicines.add(m);
    return m;
  }

  Medicine? findById(int id) {
    for (final m in medicines) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<Medicine> search(String keyword) => medicines
      .where((m) => m.name.toLowerCase().contains(keyword.toLowerCase()))
      .toList();

  void restock(int id, int qty) {
    final m = findById(id);
    if (m == null) throw Exception('Medicine not found.');
    if (qty <= 0) throw Exception('Quantity must be greater than zero.');
    m.quantity += qty;
  }

  Sale sell(int id, int qty) {
    final m = findById(id);
    if (m == null) throw Exception('Medicine not found.');
    if (qty <= 0) throw Exception('Quantity must be greater than zero.');
    if (m.isExpired) throw Exception('Cannot sell an expired medicine.');
    if (m.quantity < qty) {
      throw Exception('Insufficient stock. Only ${m.quantity} available.');
    }
    m.quantity -= qty;
    final sale = Sale(_nextSaleId++, m, qty, m.price * qty, DateTime.now(),
        currentUser!.username);
    sales.add(sale);
    return sale;
  }

  double get totalRevenue => sales.fold(0.0, (sum, s) => sum + s.total);
}

// ---------- INPUT HELPERS ----------
String readText(String prompt) {
  while (true) {
    stdout.write(prompt);
    final input = stdin.readLineSync()?.trim() ?? '';
    if (input.isNotEmpty) return input;
    print('Input cannot be empty.');
  }
}

int readInt(String prompt) {
  while (true) {
    final value = int.tryParse(readText(prompt));
    if (value != null) return value;
    print('Please enter a valid whole number.');
  }
}

double readDouble(String prompt) {
  while (true) {
    final value = double.tryParse(readText(prompt));
    if (value != null && value >= 0) return value;
    print('Please enter a valid amount.');
  }
}

DateTime readDate(String prompt) {
  while (true) {
    final value = DateTime.tryParse(readText(prompt));
    if (value != null) return value;
    print('Use the format YYYY-MM-DD.');
  }
}

String fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------- SCREENS ----------
void printMedicines(List<Medicine> list) {
  if (list.isEmpty) {
    print('No medicines found.');
    return;
  }
  print('\nID  Name                 Category       Price(Le)  Qty  Expiry      Status');
  print('-' * 82);
  for (final m in list) {
    String status = 'OK';
    if (m.isExpired) {
      status = 'EXPIRED';
    } else if (m.isLowStock) {
      status = 'LOW STOCK';
    } else if (m.isExpiringSoon(90)) {
      status = 'EXPIRING SOON';
    }
    print('${m.id.toString().padRight(4)}${m.name.padRight(21)}'
        '${m.category.padRight(15)}${m.price.toStringAsFixed(2).padRight(11)}'
        '${m.quantity.toString().padRight(5)}${fmt(m.expiryDate).padRight(12)}$status');
  }
}

void addMedicineScreen(PharmTrack app) {
  final name = readText('Medicine name: ');
  final category = readText('Category: ');
  final price = readDouble('Unit price (Le): ');
  final qty = readInt('Opening quantity: ');
  final reorder = readInt('Reorder level: ');
  final expiry = readDate('Expiry date (YYYY-MM-DD): ');
  final m = app.addMedicine(name, category, price, qty, reorder, expiry);
  print('Added "${m.name}" with ID ${m.id}.');
}

void sellScreen(PharmTrack app) {
  printMedicines(app.medicines);
  try {
    final id = readInt('Medicine ID to sell: ');
    final qty = readInt('Quantity: ');
    final sale = app.sell(id, qty);
    print('\n--- RECEIPT #${sale.id} ---');
    print('Item    : ${sale.medicine.name}');
    print('Quantity: ${sale.quantity}');
    print('Total   : Le ${sale.total.toStringAsFixed(2)}');
    print('Served by ${sale.soldBy} on ${fmt(sale.date)}');
  } on Exception catch (e) {
    print('Error: ${e.toString().replaceFirst('Exception: ', '')}');
  }
}

void restockScreen(PharmTrack app) {
  try {
    final id = readInt('Medicine ID to restock: ');
    final qty = readInt('Quantity received: ');
    app.restock(id, qty);
    print('Stock updated. New quantity: ${app.findById(id)!.quantity}');
  } on Exception catch (e) {
    print('Error: ${e.toString().replaceFirst('Exception: ', '')}');
  }
}

void alertsScreen(PharmTrack app) {
  print('\n== LOW STOCK ==');
  printMedicines(app.medicines.where((m) => m.isLowStock).toList());
  print('\n== EXPIRED OR EXPIRING WITHIN 90 DAYS ==');
  printMedicines(
      app.medicines.where((m) => m.isExpired || m.isExpiringSoon(90)).toList());
}

void salesReportScreen(PharmTrack app) {
  if (app.sales.isEmpty) {
    print('No sales recorded yet.');
    return;
  }
  print('\nSale  Item                 Qty  Total(Le)   Staff');
  print('-' * 58);
  for (final s in app.sales) {
    print('${s.id.toString().padRight(6)}${s.medicine.name.padRight(21)}'
        '${s.quantity.toString().padRight(5)}${s.total.toStringAsFixed(2).padRight(12)}${s.soldBy}');
  }
  print('-' * 58);
  print('Total revenue: Le ${app.totalRevenue.toStringAsFixed(2)}');
}

// ---------- MAIN ----------
void seedData(PharmTrack app) {
  final now = DateTime.now();
  app.addMedicine('Paracetamol 500mg', 'Analgesic', 5.00, 120, 30,
      now.add(const Duration(days: 400)));
  app.addMedicine('Amoxicillin 250mg', 'Antibiotic', 12.50, 15, 20,
      now.add(const Duration(days: 200)));
  app.addMedicine('Artemether/Lum.', 'Antimalarial', 35.00, 60, 25,
      now.add(const Duration(days: 45)));
  app.addMedicine('ORS Sachet', 'Rehydration', 3.00, 8, 10,
      now.subtract(const Duration(days: 10)));
}

void main() {
  final app = PharmTrack();
  seedData(app);

  print('=== PharmTrack: Pharmacy Stock & Sales System ===');
  int attempts = 0;
  while (app.currentUser == null) {
    if (attempts == 3) {
      print('Too many failed attempts. Exiting.');
      return;
    }
    final u = readText('Username: ');
    final p = readText('Password: ');
    if (!app.login(u, p)) {
      attempts++;
      print('Invalid credentials. Attempt $attempts of 3.');
    }
  }
  print('\nWelcome, ${app.currentUser!.username} (${app.currentUser!.role})');

  bool running = true;
  while (running) {
    print('\n1. View all medicines');
    print('2. Search medicine');
    print('3. Sell medicine');
    print('4. View alerts (low stock / expiry)');
    print('5. Sales report');
    if (app.isAdmin) {
      print('6. Add new medicine');
      print('7. Restock medicine');
    }
    print('0. Logout and exit');
    final choice = readText('Choose an option: ');

    switch (choice) {
      case '1':
        printMedicines(app.medicines);
        break;
      case '2':
        printMedicines(app.search(readText('Search keyword: ')));
        break;
      case '3':
        sellScreen(app);
        break;
      case '4':
        alertsScreen(app);
        break;
      case '5':
        salesReportScreen(app);
        break;
      case '6':
        app.isAdmin ? addMedicineScreen(app) : print('Admin access only.');
        break;
      case '7':
        app.isAdmin ? restockScreen(app) : print('Admin access only.');
        break;
      case '0':
        running = false;
        print('Goodbye.');
        break;
      default:
        print('Invalid option. Try again.');
    }
  }
}