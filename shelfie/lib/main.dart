import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
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
    final themeProvider = context.watch<ShelfieProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

// --- UPDATED DATA MODEL ---
class InventoryItem {
  String name;
  String category;
  double quantity; // Changed to double for fractional amounts
  String unit; // e.g., "Gallon", "Quart", "Items", "lbs"
  bool onShoppingList;

  // Wardrobe Workflow Metadata
  String? material;
  String? storageLocation;

  InventoryItem({
    required this.name,
    required this.category,
    this.quantity = 1.0,
    this.unit = "Items",
    this.onShoppingList = false,
    this.material,
    this.storageLocation,
  });
}

// --- STATE MANAGEMENT ---
class ShelfieProvider extends ChangeNotifier {
  bool isDarkMode = false;

  final List<String> categories = [
    'Grocery',
    'Cleaners',
    'Beauty',
    'Pet',
    'Health',
    'Housewares',
    'Hobbies',
    'Wardrobes',
  ];
  final List<String> units = [
    'Items',
    'Gallon',
    'Quart',
    'Pint',
    'lbs',
    'oz',
    'Pack',
  ];

  final List<InventoryItem> _items = [
    InventoryItem(
      name: '2% Milk',
      category: 'Grocery',
      quantity: 1.0,
      unit: 'Gallon',
    ),
    InventoryItem(
      name: 'Leather Boots',
      category: 'Wardrobe',
      material: 'Leather',
      storageLocation: 'Closet A',
    ),
  ];

  List<InventoryItem> get items => _items;

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  void addItem(InventoryItem item) {
    _items.add(item);
    notifyListeners();
  }

  void updateQuantity(InventoryItem item, double newValue) {
    item.quantity = newValue < 0 ? 0 : newValue;
    notifyListeners();
  }

  void toggleShoppingList(InventoryItem item) {
    item.onShoppingList = !item.onShoppingList;
    notifyListeners();
  }

  // THIS IS THE MISSING METHOD
  void purchaseItem(InventoryItem item) {
    item.onShoppingList = false; // Remove from shopping list
    item.quantity += 1.0; // Increment inventory count (FR3)
    notifyListeners(); // Tell the UI to refresh
  }

  // ADDING DELETE AS WELL (Recommended for clean management)
  void removeItem(InventoryItem item) {
    _items.remove(item);
    notifyListeners();
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
  final _screens = [
    const InventoryScreen(),
    const ShoppingListScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
    );
  }
}

// --- UI: INVENTORY SCREEN ---
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShelfieProvider>();
    final list = provider.items
        .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelfie'),
        actions: [
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: provider.toggleTheme,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SearchBar(
              hintText: "Search items...",
              onChanged: (v) => setState(() => query = v),
              leading: const Icon(Icons.search),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final item = list[i];
          bool low = item.quantity <= 0.5; // Alert logic
          return ListTile(
            title: Text(item.name),
            subtitle: Text("${item.category} • ${item.quantity} ${item.unit}"),
            leading: Icon(
              item.category == 'Wardrobe' ? Icons.checkroom : Icons.inventory,
              color: low ? Colors.red : Colors.teal,
            ),
            onTap: () => _showEditSheet(context, item, provider),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, provider),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, ShelfieProvider provider) {
    String name = "";
    String cat = 'Grocery';
    String unit = 'Items';
    String? mat, loc;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Add Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (v) => name = v,
                ),
                DropdownButtonFormField(
                  value: cat,
                  items: provider.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setD(() => cat = v!),
                ),
                DropdownButtonFormField(
                  value: unit,
                  items: provider.units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setD(() => unit = v!),
                ),
                if (cat == 'Wardrobe') ...[
                  TextField(
                    decoration: const InputDecoration(labelText: 'Material'),
                    onChanged: (v) => mat = v,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Location'),
                    onChanged: (v) => loc = v,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                provider.addItem(
                  InventoryItem(
                    name: name,
                    category: cat,
                    unit: unit,
                    material: mat,
                    storageLocation: loc,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    InventoryItem item,
    ShelfieProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: () =>
                      provider.updateQuantity(item, item.quantity - 0.5),
                ),
                Text(
                  "${item.quantity} ${item.unit}",
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () =>
                      provider.updateQuantity(item, item.quantity + 0.5),
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.shopping_basket),
              title: const Text("Add to Shopping List"),
              onTap: () {
                provider.toggleShoppingList(item);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- UI: REPORTS SCREEN (Usage/Waste Requirement) ---
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShelfieProvider>();
    int lowStock = provider.items.where((i) => i.quantity <= 1).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Usage Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.teal.shade100,
              child: ListTile(
                title: const Text("Inventory Health"),
                subtitle: Text("${provider.items.length} Total Items Tracked"),
              ),
            ),
            Card(
              color: Colors.orange.shade100,
              child: ListTile(
                title: const Text("Low Stock Alert"),
                subtitle: Text(
                  "$lowStock items are running low. Check your shopping list!",
                ),
                trailing: const Icon(Icons.warning, color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- UI: SHOPPING LIST (Fixed Logic for FR3) ---
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We use context.watch to make sure the list updates instantly when an item is bought
    final provider = context.watch<ShelfieProvider>();
    final list = provider.items.where((i) => i.onShoppingList).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: list.isEmpty
          ? const Center(
              child: Text(
                'Your shopping list is empty.\nAdd items from the Inventory tab.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final item = list[i];
                return ListTile(
                  leading: const Icon(Icons.shopping_basket_outlined),
                  title: Text(item.name),
                  subtitle: Text(
                    'Current Stock: ${item.quantity} ${item.unit}',
                  ),
                  trailing: Checkbox(
                    value:
                        false, // Always false because checking it "completes" the task
                    onChanged: (bool? checked) {
                      if (checked == true) {
                        // This moves the item back to inventory and increases count
                        provider.purchaseItem(item);

                        // Optional: Show a quick confirmation snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${item.name} to Inventory!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
