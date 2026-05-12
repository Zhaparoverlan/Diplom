import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CompanySettingsScreen extends StatefulWidget {
  @override
  _CompanySettingsScreenState createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final ApiService _apiService = ApiService();
  List employees = [];
  bool _isLoading = true;
  String companyName = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final empData = await _apiService.getEmployees();
      final profileData = await _apiService.getUserProfile();

      setState(() {
        employees = empData;
        companyName = profileData['company_name'] ?? "My Company";
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading company data: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- МЕТОД УДАЛЕНИЯ (Теперь с API) ---
  void _confirmDelete(dynamic emp) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text("Удалить сотрудника"),
            content: Text(
              "Вы уверены, что хотите удалить ${emp['first_name'] ?? emp['username']}?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Отмена"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context); // Закрываем диалог сразу

                  // 1. Показываем лоадер
                  setState(() => _isLoading = true);

                  try {
                    // 2. Вызываем метод удаления из ApiService
                    bool success = await _apiService.deleteEmployee(emp['id']);

                    if (success) {
                      // 3. Если на бэкенде удалено, обновляем список
                      await _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Сотрудник успешно удален"),
                        ),
                      );
                    } else {
                      throw Exception("Ошибка при удалении на сервере");
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Ошибка: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text(
                  "Удалить",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  // --- МЕТОД ДОБАВЛЕНИЯ (Оставляем твой, он верный) ---
  void _showAddEmployeeDialog() {
    final _firstNameController = TextEditingController();
    final _lastNameController = TextEditingController();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    String _selectedRole = 'employee';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text("Добавить сотрудника"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: "Имя"),
                        ),
                        TextField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: "Фамилия",
                          ),
                        ),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: "Email"),
                        ),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: "Пароль",
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: "Роль",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'employee',
                              child: Text("Сотрудник"),
                            ),
                            DropdownMenuItem(
                              value: 'manager',
                              child: Text("Менеджер"),
                            ),
                            DropdownMenuItem(
                              value: 'owner',
                              child: Text("Владелец"),
                            ),
                          ],
                          onChanged:
                              (val) =>
                                  setDialogState(() => _selectedRole = val!),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Отмена"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final userData = {
                          "first_name": _firstNameController.text,
                          "last_name": _lastNameController.text,
                          "email": _emailController.text,
                          "username": _emailController.text,
                          "password": _passwordController.text,
                          "role": _selectedRole,
                        };

                        try {
                          bool success = await _apiService.addEmployee(
                            userData,
                          );
                          if (success) {
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            await _loadData();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
                        }
                      },
                      child: const Text("Создать"),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Company Management"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Карточка компании
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.business, color: Color(0xFF2563EB)),
                ),
                title: Text(
                  companyName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Enterprise Plan • Active"),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Employees",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddEmployeeDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: employees.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final emp = employees[index];
                  String name =
                      "${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}"
                          .trim();
                  if (name.isEmpty) name = emp['username'] ?? "Unknown";

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      emp['role_display'] ?? emp['role'] ?? "Employee",
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _confirmDelete(emp),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
