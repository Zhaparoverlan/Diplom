import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final String role; // Передаем сюда 'admin', 'manager' или 'worker'
  final List docs;

  DashboardScreen({required this.role, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("LEDMS: ${role.toUpperCase()}"),
        actions: [CircleAvatar(child: Icon(Icons.person))],
      ),
      body: Column(
        children: [
          // БЛОК АНАЛИТИКИ (Тот самый из Figma)
          _buildAnalyticsGrid(),

          // СПИСОК ДОКУМЕНТОВ
          Expanded(
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) => _buildDocCard(docs[index]),
            ),
          ),
        ],
      ),
      // Кнопка добавления — только если ты не "Big Boss" (он только смотрит)
      floatingActionButton:
          role != 'ceo'
              ? FloatingActionButton(onPressed: () {}, child: Icon(Icons.add))
              : null,
    );
  }

  Widget _buildAnalyticsGrid() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          _analyticCard("Total", docs.length.toString(), Colors.blue),
          _analyticCard("Pending", "3", Colors.orange), // Статика для красоты
        ],
      ),
    );
  }

  Widget _analyticCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title, style: TextStyle(color: color)),
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard(Map doc) {
    return ListTile(
      title: Text(doc['title']),
      subtitle: Text(doc['status_label']),
      // Логика кнопок: если Менеджер — видим кнопку "Одобрить"
      trailing:
          role == 'manager'
              ? IconButton(
                icon: Icon(Icons.check_circle_outline),
                onPressed: () {},
              )
              : Icon(Icons.chevron_right),
    );
  }
}
