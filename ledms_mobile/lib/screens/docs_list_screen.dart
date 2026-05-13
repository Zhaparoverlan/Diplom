import 'package:flutter/material.dart';

import '../create_doc_screen.dart';
import '../login_screen.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'doc_details_screen.dart';

class DocsListScreen extends StatefulWidget {
  const DocsListScreen({super.key});

  @override
  State<DocsListScreen> createState() => _DocsListScreenState();
}

class _DocsListScreenState extends State<DocsListScreen> {
  final ApiService _apiService = ApiService();

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fetchedDocs = await _apiService.getDocuments(filters: activeFilters);
      final fetchedStats = await _apiService.getStats();

      if (mounted) {
        setState(() {
          docs = fetchedDocs;
          stats = fetchedStats;
          displayUserName = fetchedStats['user_name'] ?? "User";
          displayUserRole =
              fetchedStats['user_role']?.toString().toUpperCase() ?? "EMPLOYEE";
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Filters ──────────────────────────────────────────────────────────────────

  Widget _buildAdvancedFilter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search documents...",
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
              _loadAllData();
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _chip("All",        null,         'status'),
              _chip("Pending",    "pending",    'status'),
              _chip("Approved",   "approved",   'status'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("|", style: TextStyle(color: Colors.grey)),
              ),
              _chip("Purchase",   "purchase",   'category'),
              _chip("Rent",       "rent",       'category'),
              _chip("Salary",     "salary",     'category'),
              _chip("Utilities",  "utilities",  'category'),
              _chip("Other",      "other",      'category'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String? value, String key) {
    final isSelected = activeFilters[key] == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            if (isSelected) {
              activeFilters.remove(key);
            } else {
              activeFilters[key] = value;
            }
          });
          _loadAllData();
        },
        selectedColor: const Color(0xFF2563EB).withAlpha(25),
        checkmarkColor: const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("LEDMS", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Уведомления',
            onPressed: () {},
          ),
        ],
      ),
      drawer: const AppDrawer(activePage: DrawerPage.home),
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
              _buildAdvancedFilter(),
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
            MaterialPageRoute(builder: (_) => CreateDocScreen()),
          );
          if (refresh == true) _loadAllData();
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        "Welcome, $displayUserName!",
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _statCard("Total",   stats['total_count'].toString(),   const Color(0xFF2563EB), Icons.folder_outlined),
          const SizedBox(width: 8),
          _statCard("Pending", stats['pending_count'].toString(), Colors.orange,           Icons.hourglass_empty),
          const SizedBox(width: 8),
          _statCard("Approved",stats['approved_count'].toString(),Colors.blueGrey,         Icons.archive_outlined),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
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
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocsList() {
    if (_isLoading && docs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (docs.isEmpty) {
      return const Center(child: Text("No documents found"));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _docTile(docs[i]),
    );
  }

  Widget _docTile(dynamic doc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        title: Text(doc['title'] ?? 'No Title',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text("Status: ${doc['status_label'] ?? doc['status']}"),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DocDetailsScreen(doc: doc)),
          );
          if (refresh == true) _loadAllData();
        },
      ),
    );
  }
}

