import 'dart:async';

import 'package:flutter/material.dart';

import '../create_doc_screen.dart';
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

  List<dynamic> docs  = [];
  Map<String, dynamic> stats = {
    'total_count':   0,
    'pending_count': 0,
    'ready_count':   0,
    'flagged_count': 0,
  };

  String displayUserName = 'Loading...';
  String displayUserRole = 'USER';
  bool   _isLoading = true;

  Timer? _pollTimer;
  int    _pollCount = 0;
  // After 40 ticks × 3 s = 2 minutes, assume Celery is down and stop polling.
  static const _maxPollCount = 40;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getDocuments(filters: activeFilters),
        _apiService.getStats(),
      ]);
      if (!mounted) return;
      setState(() {
        docs              = results[0] as List<dynamic>;
        stats             = results[1] as Map<String, dynamic>;
        displayUserName   = stats['user_name'] ?? 'User';
        displayUserRole   = (stats['user_role'] as String? ?? 'employee').toUpperCase();
        _isLoading        = false;
      });
      _updatePolling();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────────

  bool get _hasPendingDocs =>
      docs.any((d) => (d['status'] as String?) == 'pending');

  void _updatePolling() {
    if (_hasPendingDocs) {
      if (_pollTimer == null) {
        _pollCount = 0;   // reset counter each time we start a fresh poll cycle
        _pollTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => _pollPendingDocs(),
        );
      }
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
      _pollCount = 0;
    }
  }

  Future<void> _pollPendingDocs() async {
    if (!mounted) return;

    // Safety valve: stop after 2 minutes so we never poll indefinitely
    // when the Celery worker is down or a task crashes.
    _pollCount++;
    if (_pollCount >= _maxPollCount) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _pollCount = 0;
      return;
    }

    final fresh = await _apiService.getDocuments(filters: activeFilters);
    if (!mounted) return;

    final hadPending = _hasPendingDocs;         // read BEFORE setState
    setState(() => docs = fresh);               // update list

    // No more pending docs → stop timer and refresh stats so the stat
    // cards (Total / Ready / Flagged) immediately reflect the new counts.
    if (!_hasPendingDocs && hadPending) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _pollCount = 0;
      final freshStats = await _apiService.getStats();
      if (mounted) setState(() => stats = freshStats);
    }
  }

  // ── Status helpers ────────────────────────────────────────────────────────────

  Widget _statusIcon(String? s) {
    switch (s) {
      case 'ready':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'duplicate':
        return const Icon(Icons.report_problem, color: Colors.red, size: 20);
      case 'needs_verification':
      case 'needs_approval':
        return const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 20);
      case 'pending':
      default:
        return const Icon(Icons.access_time, color: Colors.orange, size: 20);
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'ready':              return Colors.green;
      case 'duplicate':          return Colors.red;
      case 'needs_verification':
      case 'needs_approval':     return Colors.orange;
      case 'pending':            return Colors.orange;
      default:                   return Colors.grey;
    }
  }

  String _statusLabel(dynamic doc) {
    final display = doc['status_display'] as String?;
    if (display != null && display.isNotEmpty) return display;
    switch (doc['status'] as String?) {
      case 'ready':              return 'Approved';
      case 'duplicate':          return 'Duplicate';
      case 'needs_verification': return 'Needs Review';
      case 'needs_approval':     return 'Needs Approval';
      default:                   return 'Processing…';
    }
  }

  // ── Filters ───────────────────────────────────────────────────────────────────

  Widget _buildAdvancedFilter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search documents...',
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
              _chip('All',          null,                'status'),
              _chip('Pending',      'pending',           'status'),
              _chip('Ready',        'ready',             'status'),
              _chip('Flagged',      'needs_verification','status'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('|', style: TextStyle(color: Colors.grey)),
              ),
              _chip('Purchase',  'purchase', 'category'),
              _chip('Rent',      'rent',     'category'),
              _chip('Salary',    'salary',   'category'),
              _chip('Utilities', 'utility',  'category'),
              _chip('Other',     'other',    'category'),
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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('LEDMS',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: Text('Recent Documents',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
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
            MaterialPageRoute(builder: (_) => const CreateDocScreen()),
          );
          if (refresh == true) _loadAllData();
        },
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(
          'Welcome, $displayUserName!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );

  Widget _buildStatsRow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _statCard('Total',
                (stats['total_count'] ?? 0).toString(),
                const Color(0xFF2563EB), Icons.folder_outlined),
            const SizedBox(width: 8),
            _statCard('Ready',
                (stats['ready_count'] ?? 0).toString(),
                Colors.green, Icons.bolt),
            const SizedBox(width: 8),
            _statCard('Flagged',
                (stats['flagged_count'] ?? 0).toString(),
                Colors.orange, Icons.warning_amber_rounded),
          ],
        ),
      );

  Widget _statCard(String title, String value, Color color, IconData icon) =>
      Expanded(
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
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(title,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      );

  Widget _buildDocsList() {
    if (_isLoading && docs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (docs.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(40),
        child: Text('No documents found',
            style: TextStyle(color: Colors.grey)),
      ));
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

  Future<void> _approveDoc(dynamic doc) async {
    final docId = doc['id'] as int?;
    if (docId == null) return;
    final result = await _apiService.approveDocument(docId);
    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document approved ✓'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve document.')),
      );
    }
  }

  Widget _docTile(dynamic doc) {
    final docStatus = doc['status'] as String?;
    final amount    = doc['amount'];
    final amountStr = amount != null && amount.toString().isNotEmpty
        ? '  •  $amount'
        : '';

    // Show approve button for needs_approval docs (owner / manager only)
    final canApprove =
        (docStatus == 'needs_approval' ||
         docStatus == 'needs_verification' ||
         docStatus == 'duplicate') &&
        displayUserRole != 'EMPLOYEE';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: _statusIcon(docStatus),
        title: Text(
          doc['title'] ?? 'No Title',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_statusLabel(doc)}$amountStr',
          style: TextStyle(fontSize: 12, color: _statusColor(docStatus)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canApprove)
              IconButton(
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 22),
                tooltip: 'Approve',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _approveDoc(doc),
              ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
        onTap: () async {
          final refresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocDetailsScreen(
                doc: doc,
                userRole: displayUserRole,
              ),
            ),
          );
          if (refresh == true) _loadAllData();
        },
      ),
    );
  }
}
