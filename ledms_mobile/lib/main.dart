import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/api_service.dart';
import 'login_screen.dart';
import 'create_doc_screen.dart';
import 'screens/doc_details_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/company_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = const FlutterSecureStorage();
  String? token = await storage.read(key: 'access_token');

  runApp(
    MaterialApp(
      title: 'LEDMS',
      home: token != null ? DocsListScreen() : LoginScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2563EB),
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
    ),
  );
}

class DocsListScreen extends StatefulWidget {
  @override
  _DocsListScreenState createState() => _DocsListScreenState();
}

class _DocsListScreenState extends State<DocsListScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();

  // Состояние фильтров
  Map<String, dynamic> activeFilters = {};
  final TextEditingController _searchController = TextEditingController();

  List docs = [];
  Map<String, dynamic> stats = {
    "total_count": 0,
    "pending_count": 0,
    "approved_count": 0,
  };

  String displayUserName = "Loading...";
  String displayUserRole = "USER";
  String userInitial = "U";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Передаем активные фильтры в запрос
      final fetchedDocs = await _apiService.getDocuments(
        filters: activeFilters,
      );
      final fetchedStats = await _apiService.getStats();

      if (mounted) {
        setState(() {
          docs = fetchedDocs;
          stats = fetchedStats;
          displayUserName = fetchedStats['user_name'] ?? "User";
          displayUserRole =
              fetchedStats['user_role']?.toString().toUpperCase() ?? "EMPLOYEE";
          if (displayUserName.isNotEmpty) {
            userInitial = displayUserName[0].toUpperCase();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Виджет фильтрации (теперь внутри класса)
  Widget _buildAdvancedFilter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Поиск документов...",
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) {
              activeFilters['search'] = val;
              _loadAllData(); // Живой поиск
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip("Все", null, 'status'),
              _filterChip("Ожидание", "pending", 'status'),
              _filterChip("Одобрено", "approved", 'status'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("|", style: TextStyle(color: Colors.grey)),
              ),
              // Твои новые категории из выпадающего списка
              _filterChip("Закуп", "purchase", 'category'),
              _filterChip("Аренда", "rent", 'category'),
              _filterChip("Зарплата", "salary", 'category'),
              _filterChip("Коммуналка", "utilities", 'category'),
              _filterChip("Прочее", "other", 'category'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? value, String key) {
    bool isSelected = activeFilters[key] == value;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (isSelected) {
              // Если уже выбрано — убираем фильтр (функция "второго нажатия")
              activeFilters.remove(key);
            } else {
              // Если не выбрано — ставим новое значение
              activeFilters[key] = value;
            }
          });
          _loadAllData();
        },
        selectedColor: const Color(0xFF2563EB).withOpacity(0.1),
        checkmarkColor: const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "LEDMS",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildStatsRow(),
              const SizedBox(height: 10),
              _buildAdvancedFilter(), // Вставляем фильтры сюда
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Text(
                  "Recent Documents",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildDocsList(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateDocScreen()),
          );
          if (refresh == true) _loadAllData();
        },
      ),
    );
  }

  // Остальные вспомогательные методы UI
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        "Welcome, $displayUserName!",
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            "Total",
            stats['total_count'].toString(),
            const Color(0xFF2563EB),
            Icons.folder_outlined,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            "Pending",
            stats['pending_count'].toString(),
            Colors.orange,
            Icons.hourglass_empty,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            "Approved",
            stats['approved_count'].toString(),
            Colors.blueGrey,
            Icons.archive_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocsList() {
    if (_isLoading && docs.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (docs.isEmpty) return const Center(child: Text("No documents found"));
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildDocTile(docs[index]),
    );
  }

  Widget _buildDocTile(dynamic doc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        title: Text(
          doc['title'] ?? 'No Title',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text("Status: ${doc['status_label'] ?? doc['status']}"),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DocDetailsScreen(doc: doc)),
          );
          if (refresh == true) _loadAllData();
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF2563EB)),
            accountName: Text(displayUserName),
            accountEmail: Text(displayUserRole),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                userInitial,
                style: const TextStyle(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: const Text("Company"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CompanySettingsScreen()),
              );
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              await _storage.delete(key: 'access_token');
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
                (r) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
