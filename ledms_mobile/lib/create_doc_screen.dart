import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/api_service.dart';

class CreateDocScreen extends StatefulWidget {
  const CreateDocScreen({super.key});

  @override
  State<CreateDocScreen> createState() => _CreateDocScreenState();
}

class _CreateDocScreenState extends State<CreateDocScreen> {
  final _titleController    = TextEditingController();
  final _supplierController = TextEditingController();
  final _amountController   = TextEditingController();
  final _apiService         = ApiService();

  String           _selectedCategory = 'other';
  PlatformFile?    _selectedFile;
  DateTime?        _selectedDate;
  bool             _isUploading = false;

  static const _blue = Color(0xFF2563EB);

  static const _categories = [
    {'value': 'purchase', 'label': 'Закуп'},
    {'value': 'rent',     'label': 'Аренда'},
    {'value': 'salary',   'label': 'Зарплата'},
    {'value': 'utility',  'label': 'Коммуналка'},
    {'value': 'other',    'label': 'Прочее'},
  ];

  // ── File / Camera ──────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
        withData: true,
      );
      if (result != null) setState(() => _selectedFile = result.files.first);
    } catch (e) {
      debugPrint('FilePicker error: $e');
    }
  }

  Future<void> _takePhoto() async {
    var perm = await Permission.camera.status;
    if (perm.isDenied || perm.isLimited) perm = await Permission.camera.request();
    if (!perm.isGranted) {
      if (perm.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Нужно разрешение на камеру.'),
            action: SnackBarAction(label: 'Настройки', onPressed: openAppSettings),
          ),
        );
      }
      return;
    }
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _selectedFile = PlatformFile(
          name:  photo.name,
          size:  bytes.length,
          bytes: bytes,
        );
      });
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate:   DateTime(2000),
      lastDate:    DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String? get _isoDate => _selectedDate == null
      ? null
      : '${_selectedDate!.year.toString().padLeft(4, '0')}'
        '-${_selectedDate!.month.toString().padLeft(2, '0')}'
        '-${_selectedDate!.day.toString().padLeft(2, '0')}';

  String get _dateLabel => _selectedDate == null
      ? 'Select date (optional)'
      : '${_selectedDate!.day.toString().padLeft(2, '0')}.'
        '${_selectedDate!.month.toString().padLeft(2, '0')}.'
        '${_selectedDate!.year}';

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (_titleController.text.trim().isEmpty) {
      _snack('Please enter a document title.');
      return;
    }
    if (_selectedFile == null) {
      _snack('Please attach a file or take a photo.');
      return;
    }

    setState(() => _isUploading = true);

    final response = await _apiService.createDocument(
      _titleController.text.trim(),
      _selectedFile!,
      supplier: _supplierController.text.trim(),
      amount:   double.tryParse(_amountController.text.trim()),
      docDate:  _isoDate,
      category: _selectedCategory,
    );

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (response == null) {
      _snack('Upload failed. Please try again.', error: true);
      return;
    }

    final docStatus = response['status'] as String? ?? '';

    if (docStatus == 'duplicate') {
      await _showDuplicateDialog(response);
    } else {
      _snack('Document saved — processing in background.');
      Navigator.pop(context, true);
    }
  }

  Future<void> _showDuplicateDialog(Map<String, dynamic> doc) async {
    // ctx is the dialog's own context — must use it for Navigator.pop so only
    // the dialog closes, not the whole screen.
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Possible Duplicate'),
          ],
        ),
        content: const Text(
          'This file looks very similar to an existing document.\n\n'
          'Do you want to keep it anyway or discard it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keep anyway',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (keep == true) {
      // Keep: document is already saved — return to the list
      _snack('Document kept — marked as duplicate for review.');
      Navigator.pop(context, true);
    } else {
      // Discard: delete the server-side document and stay on the form
      // so the user can modify and re-upload.
      final docId = doc['id'] as int?;
      if (docId != null) {
        await _apiService.deleteDocument(docId);
        if (!mounted) return;
      }
      _snack('Document discarded. You can modify and try again.');
      // Do NOT pop — user stays on the New Document form.
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('New Document',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title (required)
            _label('Document Title *'),
            TextField(
                controller: _titleController,
                decoration: _inputDeco('e.g. Invoice #123')),

            const SizedBox(height: 20),

            // Category (required — dropdown always has a value)
            _label('Category *'),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: _inputDeco('Select category'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c['value'],
                        child: Text(c['label']!),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),

            const SizedBox(height: 20),

            // Supplier (optional)
            _label('Supplier / Company'),
            TextField(
                controller: _supplierController,
                decoration: _inputDeco('Enter supplier name (optional)')),

            const SizedBox(height: 20),

            // Amount + Date row (both optional)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Amount'),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _inputDeco('0.00 (optional)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Date'),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _dateLabel,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedDate == null
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // File attachment (required)
            _label('File Attachment *'),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickFile,
                    icon: const Icon(Icons.file_present),
                    label: const Text('Pick File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Selected: ${_selectedFile!.name}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),

            // Info banner
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blue.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _blue.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OCR extraction runs in the background. '
                      'Supplier, amount and date will be auto-filled — '
                      'your manual values are always kept.',
                      style: TextStyle(fontSize: 12, color: _blue),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Save Document',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _supplierController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
