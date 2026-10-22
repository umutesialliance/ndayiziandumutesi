

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const StockApp());
}

String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

String money(num value) => NumberFormat('#,##0.##').format(value);

String dateTimeText(String value) {
  try {
    return DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.parse(value));
  } catch (_) {
    return value;
  }
}

class StockDB {
  StockDB._();
  static final StockDB instance = StockDB._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = kIsWeb
        ? 'stock_web.db'
        : p.join(await getDatabasesPath(), 'stock.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sku TEXT NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 0,
            price REAL NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            productName TEXT NOT NULL,
            type TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            unitPrice REAL NOT NULL,
            total REAL NOT NULL,
            createdAt TEXT NOT NULL,
            username TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<bool> register(String username, String password) async {
    try {
      final db = await database;
      await db.insert('users', {
        'username': username.trim(),
        'password': hashPassword(password),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username.trim(), hashPassword(password)],
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> products() async {
    final db = await database;
    return db.query('products', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> addProduct(
    String name,
    String sku,
    int quantity,
    double price,
  ) async {
    final db = await database;
    await db.insert('products', {
      'name': name.trim(),
      'sku': sku.trim(),
      'quantity': quantity,
      'price': price,
    });
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    final history = await db.query(
      'transactions',
      where: 'productId = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (history.isNotEmpty) {
      throw Exception('This product has transaction history and cannot be deleted.');
    }

    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> changeStock({
    required int productId,
    required String type,
    required int quantity,
    required String username,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }

    final db = await database;

    await db.transaction((txn) async {
      final found = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (found.isEmpty) throw Exception('Product not found.');

      final product = found.first;
      final current = product['quantity'] as int;
      final price = (product['price'] as num).toDouble();
      final name = product['name'] as String;

      if (type == 'OUT' && quantity > current) {
        throw Exception('Not enough stock available.');
      }

      final newQuantity =
          type == 'IN' ? current + quantity : current - quantity;

      await txn.update(
        'products',
        {'quantity': newQuantity},
        where: 'id = ?',
        whereArgs: [productId],
      );

      await txn.insert('transactions', {
        'productId': productId,
        'productName': name,
        'type': type,
        'quantity': quantity,
        'unitPrice': price,
        'total': quantity * price,
        'createdAt': DateTime.now().toIso8601String(),
        'username': username,
      });
    });
  }

  Future<List<Map<String, Object?>>> transactions({
    String filter = 'All',
  }) async {
    final db = await database;
    final now = DateTime.now();
    String? start;

    if (filter == 'Hour') {
      start = DateTime(now.year, now.month, now.day, now.hour)
          .toIso8601String();
    } else if (filter == 'Day') {
      start = DateTime(now.year, now.month, now.day)
          .toIso8601String();
    } else if (filter == 'Month') {
      start = DateTime(now.year, now.month)
          .toIso8601String();
    } else if (filter == 'Year') {
      start = DateTime(now.year).toIso8601String();
    }

    if (start == null) {
      return db.query('transactions', orderBy: 'createdAt DESC');
    }

    return db.query(
      'transactions',
      where: 'createdAt >= ?',
      whereArgs: [start],
      orderBy: 'createdAt DESC',
    );
  }
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stock Management',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

InputDecoration fieldDecoration(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      showMessage(context, 'Enter your username and password.');
      return;
    }

    setState(() => loading = true);
    try {
      final ok = await StockDB.instance.login(
        username.text,
        password.text,
      );

      if (!mounted) return;

      if (ok) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(user: username.text.trim()),
          ),
        );
      } else {
        showMessage(context, 'Incorrect username or password.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Login failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2,
                        size: 70, color: Colors.indigo),
                    const SizedBox(height: 12),
                    const Text('STOCK MANAGEMENT',
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Sign in to manage your stock'),
                    const SizedBox(height: 24),
                    TextField(
                      controller: username,
                      decoration: fieldDecoration('Username'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: password,
                      obscureText: hidePassword,
                      decoration: fieldDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => hidePassword = !hidePassword),
                        ),
                      ),
                      onSubmitted: (_) => login(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : login,
                        child: Text(loading ? 'Please wait...' : 'Login'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Create a new account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (username.text.trim().length < 3) {
      showMessage(context, 'Username must contain at least 3 characters.');
      return;
    }
    if (password.text.length < 8) {
      showMessage(context, 'Password must contain at least 8 characters.');
      return;
    }
    if (password.text != confirm.text) {
      showMessage(context, 'Passwords do not match.');
      return;
    }

    setState(() => loading = true);
    try {
      final ok = await StockDB.instance.register(
        username.text,
        password.text,
      );
      if (!mounted) return;

      if (ok) {
        showMessage(context, 'Account created. Please log in.');
        Navigator.pop(context);
      } else {
        showMessage(context, 'Username already exists or registration failed.');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Registration failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: username,
                      decoration: fieldDecoration('Username'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: fieldDecoration('Password (minimum 8 characters)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      decoration: fieldDecoration('Confirm password'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : register,
                        child: Text(loading ? 'Creating...' : 'Register'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewScreen(user: widget.user),
      ProductsScreen(user: widget.user),
      StockScreen(user: widget.user),
      ReportsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(widget.user)),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            ),
          ),
        ],
      ),
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (value) =>
            setState(() => selected = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.inventory), label: 'Products'),
          NavigationDestination(
              icon: Icon(Icons.swap_horiz), label: 'Stock In/Out'),
          NavigationDestination(
              icon: Icon(Icons.assessment), label: 'Reports'),
        ],
      ),
    );
  }
}

class OverviewScreen extends StatefulWidget {
  final String user;
  const OverviewScreen({super.key, required this.user});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Future<Map<String, dynamic>> load() async {
    final db = await StockDB.instance.database;
    final products = await db.query('products');
    final tx = await db.query('transactions');

    int quantity = 0;
    double value = 0;
    for (final item in products) {
      quantity += item['quantity'] as int;
      value += (item['quantity'] as int) *
          (item['price'] as num).toDouble();
    }

    return {
      'products': products.length,
      'quantity': quantity,
      'value': value,
      'transactions': tx.length,
    };
  }

  Widget stat(String title, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 34, color: Colors.indigo),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Welcome, ${widget.user}!',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Here is your current stock summary.'),
              const SizedBox(height: 16),
              stat('Products', '${data['products']}', Icons.inventory_2),
              stat('Items in stock', '${data['quantity']}', Icons.widgets),
              stat('Stock value', money(data['value']), Icons.payments),
              stat('Transactions', '${data['transactions']}', Icons.receipt_long),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tip: Record every stock-in and stock-out transaction '
                    'to keep your reports accurate.',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProductsScreen extends StatefulWidget {
  final String user;
  const ProductsScreen({super.key, required this.user});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  Future<List<Map<String, Object?>>> load() =>
      StockDB.instance.products();

  Future<void> addProductDialog() async {
    final name = TextEditingController();
    final sku = TextEditingController();
    final qty = TextEditingController(text: '0');
    final price = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: fieldDecoration('Product name')),
              const SizedBox(height: 12),
              TextField(controller: sku, decoration: fieldDecoration('SKU / Code')),
              const SizedBox(height: 12),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration('Opening quantity'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: fieldDecoration('Unit price'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final q = int.tryParse(qty.text);
              final pr = double.tryParse(price.text);
              if (name.text.trim().isEmpty ||
                  sku.text.trim().isEmpty ||
                  q == null || q < 0 ||
                  pr == null || pr < 0) {
                showMessage(context, 'Enter valid product details.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await StockDB.instance.addProduct(
          name.text,
          sku.text,
          int.parse(qty.text),
          double.parse(price.text),
        );
        if (mounted) {
          setState(() {});
          showMessage(context, 'Product added.');
        }
      } catch (e) {
        if (mounted) showMessage(context, 'Could not add product: $e');
      }
    }

    name.dispose();
    sku.dispose();
    qty.dispose();
    price.dispose();
  }

  Future<void> removeProduct(int id) async {
    try {
      await StockDB.instance.deleteProduct(id);
      if (mounted) {
        setState(() {});
        showMessage(context, 'Product deleted.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addProductDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No products yet. Add your first product.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final qty = item['quantity'] as int;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${qty}'),
                  ),
                  title: Text('${item['name']}'),
                  subtitle: Text(
                    'Code: ${item['sku']}\n'
                    'Quantity: $qty   |   Unit price: ${money(item['price'] as num)}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Delete product',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => removeProduct(item['id'] as int),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StockScreen extends StatefulWidget {
  final String user;
  const StockScreen({super.key, required this.user});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String type = 'IN';
  int? productId;
  final quantity = TextEditingController();

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final q = int.tryParse(quantity.text);
    if (productId == null || q == null || q <= 0) {
      showMessage(context, 'Choose a product and enter a positive quantity.');
      return;
    }

    try {
      await StockDB.instance.changeStock(
        productId: productId!,
        type: type,
        quantity: q,
        username: widget.user,
      );
      if (mounted) {
        quantity.clear();
        setState(() {});
        showMessage(context, type == 'IN'
            ? 'Stock-in recorded successfully.'
            : 'Stock-out recorded successfully.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: StockDB.instance.products(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return const Center(
              child: Text('Add a product before recording stock movements.'));
        }

        final validIds = products.map((e) => e['id'] as int).toSet();
        final selectedId =
            validIds.contains(productId) ? productId : products.first['id'] as int;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Record Stock Movement',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'IN',
                    label: Text('Stock In'),
                    icon: Icon(Icons.add_box)),
                ButtonSegment(
                    value: 'OUT',
                    label: Text('Stock Out'),
                    icon: Icon(Icons.remove_circle)),
              ],
              selected: {type},
              onSelectionChanged: (values) =>
                  setState(() => type = values.first),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: selectedId,
              decoration: fieldDecoration('Select product'),
              items: products.map((item) {
                return DropdownMenuItem<int>(
                  value: item['id'] as int,
                  child: Text(
                    '${item['name']} (Available: ${item['quantity']})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => productId = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: fieldDecoration('Quantity'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.save),
              label: const Text('Save Transaction'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Each successful stock movement is saved with its date, '
              'product, quantity, unit price and username.',
            ),
          ],
        );
      },
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String filter = 'Day';
  int refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<String>(
            value: filter,
            decoration: fieldDecoration('Report period'),
            items: const [
              DropdownMenuItem(value: 'Hour', child: Text('Current hour')),
              DropdownMenuItem(value: 'Day', child: Text('Today')),
              DropdownMenuItem(value: 'Month', child: Text('This month')),
              DropdownMenuItem(value: 'Year', child: Text('This year')),
              DropdownMenuItem(value: 'All', child: Text('All transactions')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => filter = value);
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            key: ValueKey('$filter-$refreshKey'),
            future: StockDB.instance.transactions(filter: filter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data ?? [];
              int inQty = 0;
              int outQty = 0;
              double totalIn = 0;
              double totalOut = 0;

              for (final row in rows) {
                final qty = row['quantity'] as int;
                final total = (row['total'] as num).toDouble();
                if (row['type'] == 'IN') {
                  inQty += qty;
                  totalIn += total;
                } else {
                  outQty += qty;
                  totalOut += total;
                }
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Transactions: ${rows.length}')),
                        Chip(label: Text('Stock in: $inQty')),
                        Chip(label: Text('Stock out: $outQty')),
                        Chip(label: Text('Value in: ${money(totalIn)}')),
                        Chip(label: Text('Value out: ${money(totalOut)}')),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('No transactions for this period.'))
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              final isIn = row['type'] == 'IN';
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                child: ListTile(
                                  leading: Icon(
                                    isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isIn ? Colors.green : Colors.red,
                                  ),
                                  title: Text('${row['productName']}'),
                                  subtitle: Text(
                                    '${isIn ? 'Stock In' : 'Stock Out'}'
                                    ' • Qty: ${row['quantity']}\n'
                                    '${dateTimeText('${row['createdAt']}')}'
                                    ' • User: ${row['username']}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    money(row['total'] as num),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
