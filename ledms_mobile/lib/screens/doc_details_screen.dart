import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class DocDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final String userRole; // 'OWNER', 'MANAGER', or 'EMPLOYEE'

  const DocDetailsScreen({
    super.key,
    required this.doc,
    this.userRole = 'EMPLOYEE',
  });

  @override
  State<DocDetailsScreen> createState() => _DocDetailsScreenState();
}

class _DocDetailsScreenState extends State<DocDetailsScreen> {
  final ApiService _apiService = ApiService();
  late TextEditingController _amountController;
  late TextEditingController _supplierController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final amount = widget.doc['amount'];
    _amountController = TextEditingController(
      text: amount != null ? amount.toString() : '',
    );
    _supplierController = TextEditingController(
      text: widget.doc['supplier'] ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  // ── Status helpers ────────────────────────────────────────────────────────────

  Color _statusColor(String? s) {
    switch (s) {
      case 'ready':
        return Colors.green;
      case 'duplicate':
        return Colors.red;
      case 'needs_verification':
      case 'needs_approval':
        return Colors.orange;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIconData(String? s) {
    switch (s) {
      case 'ready':
        return Icons.check_circle;
      case 'duplicate':
        return Icons.report_problem;
      case 'needs_verification':
      case 'needs_approval':
        return Icons.warning_amber_rounded;
      case 'pending':
      default:
        return Icons.access_time;
    }
  }

  String _statusLabel(String? s) {
    final display = widget.doc['status_display'] as String?;
    if (display != null && display.isNotEmpty) return display;
    switch (s) {
      case 'ready':
        return 'Approved';
      case 'duplicate':
        return 'Duplicate';
      case 'needs_verification':
        return 'Needs Review';
      case 'needs_approval':
        return 'Needs Approval';
      default:
        return 'Processing…';
    }
  }

  // ── API calls ─────────────────────────────────────────────────────────────────

  // Save only user-editable fields — NEVER sends status.
  Future<void> _saveDocument() async {
    setState(() => _isSaving = true);
    try {
      final data = <String, dynamic>{
        'supplier': _supplierController.text.trim(),
      };
      final amountText = _amountController.text.trim();
      if (amountText.isNotEmpty) data['amount'] = amountText;

      final docId = widget.doc['id'] as int;
      final result = await _apiService.patchDocument(docId, data);
      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // PATCH editable fields first, then POST /approve/.
  // A single tap saves the user's corrections AND approves atomically.
  Future<void> _approveDocument() async {
    setState(() => _isSaving = true);
    try {
      final docId = widget.doc['id'] as int;

      // Step 1: persist any edits the user made before tapping Approve.
      final patchData = <String, dynamic>{
        'supplier': _supplierController.text.trim(),
      };
      final amountText = _amountController.text.trim();
      if (amountText.isNotEmpty) patchData['amount'] = amountText;

      final patched = await _apiService.patchDocument(docId, patchData);
      if (!mounted) return;
      if (patched == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save changes. Please try again.'),
          ),
        );
        return;
      }

      // Step 2: approve — only reachable after a successful PATCH.
      final approved = await _apiService.approveDocument(docId);
      if (!mounted) return;
      if (approved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document approved ✓'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approval failed. You may not have permission.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final docId = widget.doc['id'] as int;
      final ok = await _apiService.deleteDocument(docId);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delete failed. You may not have permission.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final docStatus = widget.doc['status'] as String?;
    // Only managers/owners can approve. Approve is shown for every status that
    // requires human sign-off; it disappears once the document is ready.
    final canApprove =
        (docStatus == 'needs_approval' ||
         docStatus == 'needs_verification' ||
         docStatus == 'duplicate') &&
        widget.userRole != 'EMPLOYEE';
    final canDelete = widget.userRole != 'EMPLOYEE';

    String formattedDate = 'N/A';
    if (widget.doc['created_at'] != null) {
      final dt = DateTime.parse(widget.doc['created_at']).toLocal();
      formattedDate = DateFormat('MMMM d, yyyy • HH:mm').format(dt);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Document Details',
            style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _isSaving ? null : _deleteDocument,
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(docStatus),
                  const SizedBox(height: 20),
                  _buildEditableCard(formattedDate),
                  const SizedBox(height: 25),
                  const Text('Image Preview',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildImagePreview(),
                  const SizedBox(height: 25),
                  _buildRawTextSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomActions(canApprove),
    );
  }

  Widget _buildStatusBanner(String? docStatus) {
    final color = _statusColor(docStatus);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_statusIconData(docStatus), color: color),
          const SizedBox(width: 10),
          Text(
            _statusLabel(docStatus).toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCard(String date) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _supplierController,
            decoration: const InputDecoration(
              labelText: 'Supplier',
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const Divider(height: 40),
          _buildInfoRow(Icons.person_outline, 'Author',
              widget.doc['author_name'] ?? 'Unknown'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today_outlined, 'Created', date),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: widget.doc['file'] != null
          ? Image.network(
              widget.doc['file'],
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: Colors.black12,
                child: const Center(child: Text('Failed to load image')),
              ),
            )
          : Container(
              height: 200,
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported),
            ),
    );
  }

  Widget _buildRawTextSection() {
    return ExpansionTile(
      title: const Text('Recognized Text (AI)',
          style: TextStyle(fontWeight: FontWeight.bold)),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Text(
            widget.doc['raw_text'] ?? 'No text recognized',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(bool canApprove) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _saveDocument,
              child: const Text('Save'),
            ),
          ),
          if (canApprove) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : _approveDocument,
                child: const Text('Approve'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
