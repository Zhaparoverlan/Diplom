import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Замени 'your_project_name' на название твоего пакета (как в pubspec.yaml)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DocDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  // Если тестируешь на эмуляторе Android, используй 10.0.2.2 вместо 127.0.0.1
  final String baseUrl = "http://127.0.0.1:8000/api";

  const DocDetailsScreen({super.key, required this.doc});

  @override
  State<DocDetailsScreen> createState() => _DocDetailsScreenState();
}

class _DocDetailsScreenState extends State<DocDetailsScreen> {
  late TextEditingController _amountController;
  late TextEditingController _supplierController;
  bool _isSaving = false;

  // Создаем хранилище, чтобы достать токен
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.doc['amount'].toString(),
    );
    _supplierController = TextEditingController(
      text: widget.doc['supplier'] ?? '',
    );
  }

  // --- МЕТОДЫ API ---

  // Универсальный метод для получения токена
  Future<String?> _getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> _updateDocument(String status) async {
    // 1. Достаем токен СТРОГО перед запросом
    final token = await _storage.read(key: 'access_token');

    // 2. Печатаем в консоль ДЛЯ СЕБЯ (проверь это в VS Code / Android Studio)
    print("TOKEN: $token");

    if (token == null) {
      print("ОШИБКА: Токена нет в хранилище!");
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await http.patch(
        Uri.parse('${widget.baseUrl}/documents/${widget.doc['id']}/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // ПРОВЕРЬ ПРОБЕЛ ПОСЛЕ Bearer
        },
        body: jsonEncode({
          "amount": _amountController.text,
          "supplier": _supplierController.text,
          "status": status,
        }),
      );

      print("RESPONSE CODE: ${response.statusCode}");
      print("RESPONSE BODY: ${response.body}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Успешно!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        print("ОШИБКА СЕРВЕРА: ${response.body}");
      }
    } catch (e) {
      print("ERROR: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteDocument() async {
    final bool confirm = await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Удалить документ?"),
            content: const Text("Это действие нельзя отменить."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Отмена"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Удалить",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final token = await _getToken();
        final response = await http.delete(
          Uri.parse('${widget.baseUrl}/documents/${widget.doc['id']}/'),
          headers: {"Authorization": "Bearer $token"},
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          _showSnackBar('Документ удален', Colors.blueGrey);
          Navigator.pop(context, true);
        }
      } catch (e) {
        print("Delete error: $e");
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // --- ВЕРСТКА ---

  @override
  Widget build(BuildContext context) {
    String formattedDate = "N/A";
    if (widget.doc['created_at'] != null) {
      DateTime dt = DateTime.parse(widget.doc['created_at']).toLocal();
      formattedDate = DateFormat('MMMM d, yyyy • HH:mm').format(dt);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Детали документа",
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteDocument,
          ),
        ],
      ),
      body:
          _isSaving
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBanner(),
                    const SizedBox(height: 20),
                    _buildEditableCard(formattedDate),
                    const SizedBox(height: 25),
                    const Text(
                      "Превью изображения",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildImagePreview(),
                    const SizedBox(height: 25),
                    _buildRawTextSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildStatusBanner() {
    bool isApproved = widget.doc['status'] == 'approved';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color:
            isApproved
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.check_circle : Icons.pending,
            color: isApproved ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 10),
          Text(
            isApproved ? "ОДОБРЕНО" : "ЧЕРНОВИК / ОЖИДАЕТ ПРОВЕРКИ",
            style: TextStyle(
              color: isApproved ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _supplierController,
            decoration: const InputDecoration(
              labelText: "Поставщик",
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
              labelText: "Сумма (сом)",
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const Divider(height: 40),
          _buildInfoRow(
            Icons.person_outline,
            "Загрузил",
            widget.doc['author_name'] ?? "Erlan",
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today_outlined, "Дата", date),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child:
          widget.doc['file'] != null
              ? Image.network(
                widget.doc['file'],
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.black12,
                      child: Center(child: Text("Ошибка загрузки фото")),
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
      title: const Text(
        "Распознанный текст (AI)",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Text(
            widget.doc['raw_text'] ?? "Текст не распознан",
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
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
              onPressed: () => _updateDocument('pending'),
              child: const Text("Сохранить"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _updateDocument('approved'),
              child: const Text("Одобрить"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
