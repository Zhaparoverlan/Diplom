import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateDocScreen extends StatefulWidget {
  @override
  _CreateDocScreenState createState() => _CreateDocScreenState();
}

class _CreateDocScreenState extends State<CreateDocScreen> {
  // Контроллеры для текстовых полей
  final _titleController = TextEditingController();
  final _supplierController = TextEditingController();
  final _amountController = TextEditingController();

  final ApiService _apiService = ApiService();

  String _selectedCategory = 'other';
  FilePickerResult? _selectedFile;
  bool _isUploading = false;
  bool _isDataRecognized = false; // Флаг: получили ли мы данные от OCR
  String? _recognizedRawText; // Распознанный текст с сервера (raw_text)

  // Список категорий для выпадающего меню
  final List<Map<String, String>> _categories = [
    {'value': 'purchase', 'label': 'Закуп'},
    {'value': 'rent', 'label': 'Аренда'},
    {'value': 'salary', 'label': 'Зарплата'},
    {'value': 'utility', 'label': 'Коммуналка'},
    {'value': 'other', 'label': 'Прочее'},
  ];

  // Выбор файла
  Future<void> selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedFile = result;
          _isDataRecognized = false; // Сбрасываем флаг, если файл изменился
          _recognizedRawText = null;
        });
      }
    } catch (e) {
      debugPrint("Ошибка выбора файла: $e");
    }
  }

  // Сделать фото
  Future<void> takePhoto() async {
    var status = await Permission.camera.status;
    if (status.isDenied || status.isLimited) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedFile = FilePickerResult([
            PlatformFile(name: photo.name, size: bytes.length, bytes: bytes),
          ]);
          _isDataRecognized = false;
          _recognizedRawText = null;
        });
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Нужно разрешение на камеру."),
            action: SnackBarAction(
              label: "Настройки",
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  // Основная функция загрузки и распознавания
  Future<void> handleUpload() async {
    if (_titleController.text.isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Введите название и выберите файл")),
      );
      return;
    }

    if (_isDataRecognized) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _isUploading = true);

    // Явно указываем dynamic, чтобы Dart не ругался на скобки []
    final dynamic responseData = await _apiService.createDocument(
      _titleController.text,
      _selectedFile!.files.first,
      supplier: _supplierController.text,
      amount: double.tryParse(_amountController.text),
      category: _selectedCategory,
    );

    if (mounted) {
      setState(() => _isUploading = false);

      // Проверяем, что ответ не null и не false
      if (responseData != null && responseData != false) {
        setState(() {
          // Безопасно извлекаем данные из ответа API (OCR на сервере: raw_text, amount, supplier)
          if (responseData['amount'] != null) {
            _amountController.text = responseData['amount'].toString();
          }
          if (responseData['supplier'] != null) {
            _supplierController.text = responseData['supplier'].toString();
          }
          if (responseData['raw_text'] != null &&
              responseData['raw_text'].toString().trim().isNotEmpty) {
            _recognizedRawText = responseData['raw_text'].toString();
          }
          _isDataRecognized = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Данные распознаны! Проверьте поля."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка при обработке файла")),
        );
      }
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "New Document",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("Document Title *"),
            TextField(
              controller: _titleController,
              decoration: _inputStyle("e.g. Invoice #123"),
            ),

            const SizedBox(height: 20),

            _buildLabel("Supplier / Company"),
            TextField(
              controller: _supplierController,
              decoration: _inputStyle("Enter supplier name"),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Amount"),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: _inputStyle("0.00"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Category"),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: _inputStyle("Select"),
                        items:
                            _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['value'],
                                    child: Text(c['label']!),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) => setState(() => _selectedCategory = val!),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            _buildLabel("File Attachment"),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: selectFile,
                    icon: const Icon(Icons.file_present),
                    label: const Text("Pick File"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Take Photo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "Selected: ${_selectedFile!.files.first.name}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            if (_recognizedRawText != null &&
                _recognizedRawText!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildLabel("Recognized text (preview)"),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _recognizedRawText!,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isUploading ? null : handleUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isDataRecognized
                          ? Colors.green
                          : const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          _isDataRecognized
                              ? "Confirm & Save"
                              : "Create & Analyze",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
