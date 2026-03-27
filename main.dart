import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Enable offline persistence for NFR2 compliance
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ShelfieProvider(),
      child: const ShelfieApp(),
    ),
  );
}

class ShelfieApp extends StatelessWidget {
  const ShelfieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelfie',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, secondary: Colors.orange),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

// --- MODELS ---
class InventoryItem {
  String id;
  String name;
  String category;
  int quantity;
  bool isFavorite;
  bool onShoppingList;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    this.quantity = 1,
    this.isFavorite = false,
    this.onShoppingList = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'quantity': quantity,
    'isFavorite': isFavorite,
    'onShoppingList': onShoppingList,
  };
}

// --- LOGIC / PROVIDER (FR2, FR3, FR4) ---
class ShelfieProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Categories as defined in the Requirements Analysis
  final List<String> categories = [
    'Grocery', 'Cleaners', 'Beauty', 'Pet', 
    'Health & Nutrition', 'Housewares', 'Hobbies', 'Wardrobe'
  ];

  Stream<List<InventoryItem>> get inventoryStream => _db
      .collection('inventory')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => InventoryItem(
            id: doc.id,
            name: doc['name'],
            category: doc['category'],
            quantity: doc['quantity'],
            isFavorite: doc['isFavorite'],
            onShoppingList: doc['onShoppingList'],
          )).toList());

  Future<void> addItem(String name, String category) async {
    await _db.collection('inventory').add({
      'name': name,
      'category': category,
      'quantity': 1,
      'isFavorite': false,
      'onShoppingList': false,
    });
  }

  Future<void> toggleShoppingList(InventoryItem item) async {
    await _db.collection('inventory').doc(item.id).update({
      'onShoppingList': !item.onShoppingList,
    });
  }

  // FR3: Moving items from Shopping List back to Inventory
  Future<void> purchaseItem(InventoryItem item) async {
    await _db.collection('inventory').doc(item.id).update({
      'onShoppingList': false,
      'quantity': item.quantity + 1,
    });
  }

  Future<void> updateQuantity(String id, int newQty) async {
    await _db.collection('inventory').doc(id).update({'quantity': newQty});
  }
}

// --- UI: NAVIGATION ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;
  final _screens = [const InventoryScreen(), const ShoppingListScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Shopping List'),
        ],
      ),
    );
  }
}

// --- UI: INVENTORY SCREEN (FR1, FR5, NFR3) ---
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShelfieProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Shelfie Inventory')),
      body: StreamBuilder<List<InventoryItem>>(
        stream: provider.inventoryStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              bool lowStock = item.quantity <= 1; // FR5 logic

              return ListTile(
                title: Text(item.name),
                subtitle: Text(item.category),
                leading: Icon(
                  lowStock ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: lowStock ? Colors.red : Colors.green,
                ),
                trailing: Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onTap: () => _showEditDialog(context, item, provider),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, provider),
        child: const Icon(Icons.add),
      ),
    );
  }

  // FR1: Detailed Add Form
  void _showAddDialog(BuildContext context, ShelfieProvider provider) {
    String name = "";
    String category = provider.categories.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Inventory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: const InputDecoration(labelText: 'Item Name'), onChanged: (v) => name = v),
            DropdownButtonFormField(
              value: category,
              items: provider.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => category = v!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            provider.addItem(name, category);
            Navigator.pop(context);
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, InventoryItem item, ShelfieProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Increase Quantity'),
            onTap: () { provider.updateQuantity(item.id, item.quantity + 1); Navigator.pop(context); },
          ),
          ListTile(
            leading: const Icon(Icons.remove),
            title: const Text('Decrease Quantity'),
            onTap: () { provider.updateQuantity(item.id, item.quantity - 1); Navigator.pop(context); },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_basket),
            title: const Text('Add to Shopping List'),
            onTap: () { provider.toggleShoppingList(item); Navigator.pop(context); },
          ),
        ],
      ),
    );
  }
}

// --- UI: SHOPPING LIST (FR3, FR4) ---
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShelfieProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: StreamBuilder<List<InventoryItem>>(
        stream: provider.inventoryStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final list = snapshot.data!.where((i) => i.onShoppingList).toList();

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              return ListTile(
                title: Text(item.name),
                // FR4: Highlighting staples or favorites
                trailing: IconButton(
                  icon: const Icon(Icons.check_box_outline_blank),
                  onPressed: () => provider.purchaseItem(item), // Moves back to inventory
                ),
              );
            },
          );
        },
      ),
    );
  }
}