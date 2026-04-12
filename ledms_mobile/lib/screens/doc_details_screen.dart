import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DocDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> doc;

  const DocDetailsScreen({super.key, required this.doc});

  // Функция-помощник для определения иконки
  Widget _getFileIcon(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(
        Icons.insert_drive_file_outlined,
        color: Colors.grey,
        size: 48,
      );
    }

    String extension = url.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return const Icon(
          Icons.picture_as_pdf,
          color: Colors.redAccent,
          size: 48,
        );
      case 'xls':
      case 'xlsx':
        return const Icon(Icons.description, color: Colors.green, size: 48);
      case 'txt':
        return const Icon(
          Icons.article_outlined,
          color: Colors.blueGrey,
          size: 48,
        );
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Icon(Icons.image_outlined, color: Colors.purple, size: 48);
      case 'doc':
      case 'docx':
        return const Icon(Icons.description, color: Colors.blue, size: 48);
      default:
        return const Icon(
          Icons.insert_drive_file_outlined,
          color: Colors.grey,
          size: 48,
        );
    }
  }

  // Вспомогательная функция для текста типа файла
  String _getFileExtensionText(String? url) {
    if (url == null || !url.contains('.')) return "Unknown";
    return url.split('.').last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = "N/A";
    if (doc['created_at'] != null) {
      DateTime dt = DateTime.parse(doc['created_at']).toLocal();
      formattedDate = DateFormat('MMMM d, yyyy • HH:mm').format(dt);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Back to Documents",
          style: TextStyle(color: Colors.black87, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainInfoCard(context, formattedDate),
            const SizedBox(height: 25),
            const Text(
              "Распознанный текст / Описание",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                doc['raw_text'] ?? "Текст еще не распознан или описание пустое",
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
            ),
            //
            const SizedBox(height: 25),
            const Text(
              "Document Preview",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildPreviewPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfoCard(BuildContext context, String date) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusBadge(doc['status'] ?? 'draft'),
                  ],
                ),
              ),
              // ПРИМЕНЕНИЕ: Умная иконка вместо статичной
              _getFileIcon(doc['file']),
            ],
          ),
          const Divider(height: 40),
          _buildInfoRow(Icons.person_outline, "Author", "Erlan (You)"),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today_outlined, "Created Date", date),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.file_present_outlined,
            "File Type",
            _getFileExtensionText(doc['file']), // Динамический текст расширения
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri _url = Uri.parse(
                      doc['file'],
                    ); // Получаем URL файла из Django
                    if (!await launchUrl(
                      _url,
                      mode: LaunchMode.externalApplication,
                    )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open file')),
                      );
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("Download"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Логика предпросмотра
                  },
                  icon: const Icon(Icons.remove_red_eye_outlined),
                  label: const Text("Preview"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ... (Остальные методы _buildInfoRow, _buildStatusBadge и _buildPreviewPlaceholder остаются без изменений)

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'draft' ? Colors.blueGrey : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPreviewPlaceholder() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Preview not available for this format yet",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
