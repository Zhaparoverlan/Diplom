import 'package:flutter/material.dart';
import 'package:ledms_mobile/screens/doc_details_screen.dart';
import 'services/api_service.dart'; // Наш сервис с Dio
import 'login_screen.dart';
import 'create_doc_screen.dart';

void main() {
  // Обязательно для инициализации плагинов (Secure Storage) перед запуском приложения
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MaterialApp(
      title: 'LEDMS',
      home: LoginScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2563EB),
        useMaterial3: true,
        fontFamily: 'Inter', // Если добавил шрифт в pubspec
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
    ),
  );
}

class DocsListScreen extends StatefulWidget {
  // Токен теперь опционален, так как мы можем взять его из хранилища
  final String? token;
  DocsListScreen({this.token});

  @override
  _DocsListScreenState createState() => _DocsListScreenState();
}

class _DocsListScreenState extends State<DocsListScreen> {
  final ApiService _apiService = ApiService(); // Используем наш сервис
  List docs = [];
  Map<String, dynamic> stats = {
    "total_count": 0,
    "pending_count": 0,
    "approved_count": 0,
    "total_expenses": 0,
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

  // Общий метод для загрузки всех данных через сервис
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Получаем документы
      final fetchedDocs = await _apiService.getDocuments();
      print("DOCS FROM API: $fetchedDocs");
      // 2. Получаем статистику
      final fetchedStats = await _apiService.getStats();

      setState(() {
        docs = fetchedDocs;
        stats = fetchedStats;

        // Обновляем данные профиля
        displayUserName = fetchedStats['user_name'] ?? "User";
        displayUserRole =
            fetchedStats['user_role']?.toString().toUpperCase() ?? "EMPLOYEE";
        if (displayUserName.isNotEmpty) {
          userInitial = displayUserName[0].toUpperCase();
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() => _isLoading = false);
    }
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
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF2563EB)),
              accountName: Text(
                displayUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                displayUserRole,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  userInitial,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _buildDrawerItem(Icons.dashboard_outlined, "Dashboard", true),
            _buildDrawerItem(Icons.description_outlined, "Documents", false),
            const Spacer(),
            const Divider(),
            _buildDrawerItem(
              Icons.logout,
              "Logout",
              false,
              onTap: () async {
                // Добавь метод logout в ApiService, чтобы стирать токены
                // await _apiService.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildStatsRow(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
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

  // --- Вспомогательные методы UI (разбил для чистоты) ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome, $displayUserName!",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Check your latest updates",
            style: TextStyle(color: Colors.grey),
          ),
        ],
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
          const SizedBox(width: 12),
          _buildStatCard(
            "Pending",
            stats['pending_count'].toString(),
            Colors.orange,
            Icons.hourglass_empty,
          ),
          const SizedBox(width: 12),
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

  Widget _buildDocsList() {
    if (_isLoading && docs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (docs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("No documents found"),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildDocTile(docs[index]),
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
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
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF1F5F9),
          child: Icon(
            Icons.description_outlined,
            color: Colors.blueGrey,
            size: 20,
          ),
        ),
        title: Text(
          doc['title'] ?? 'No Title',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "Status: ${doc['status_label'] ?? doc['status'] ?? 'N/A'}",
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DocDetailsScreen(doc: doc)),
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    bool isSelected, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
    );
  }
}
