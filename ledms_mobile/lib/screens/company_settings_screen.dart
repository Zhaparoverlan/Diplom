import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'employee_profile_screen.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  static const _blue    = Color(0xFF2563EB);
  static const _purple  = Color(0xFF7C3AED);
  static const _bannerH = 130.0;
  static const _logoD   = 68.0; // logo circle diameter
  static const _logoOverlap = 32.0; // how far logo dips below the banner

  final ApiService _apiService = ApiService();
  final ImagePicker _picker    = ImagePicker();

  List _employees             = [];
  Map<String, dynamic>? _company;
  Map<String, dynamic>? _currentUser;
  bool _isLoading             = true;

  String get _myRole => _currentUser?['role'] ?? 'employee';
  int?   get _myId   => _currentUser?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _apiService.getEmployees(),
        _apiService.getUserProfile(),
        _apiService.getCompanyDetail(),
      ]);
      setState(() {
        _employees   = results[0] as List;
        _currentUser = results[1] as Map<String, dynamic>;
        _company     = results[2] as Map<String, dynamic>;
        _isLoading   = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── Permission helpers ────────────────────────────────────────────────────

  bool _canAdd() => _myRole == 'owner' || _myRole == 'manager';

  bool _canModify(dynamic emp) {
    if (emp['id'] == _myId) return false;
    if (_myRole == 'owner') return true;
    if (_myRole == 'manager') return emp['role'] == 'employee';
    return false;
  }

  // ── Upload helpers ────────────────────────────────────────────────────────

  Future<void> _uploadMedia({required bool isBanner}) async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    setState(() => _isLoading = true);
    final ok = await (isBanner
        ? _apiService.updateCompany(bannerFile: img)
        : _apiService.updateCompany(logoFile: img));
    if (ok) {
      await _loadData();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBanner
                ? "Ошибка загрузки баннера"
                : "Ошибка загрузки логотипа"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  void _confirmDelete(dynamic emp) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Удалить сотрудника"),
        content: Text(
          "Вы уверены, что хотите удалить "
          "${emp['first_name'] ?? emp['username']}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Отмена"),
          ),
          TextButton(
            onPressed: () async {
              final nav       = Navigator.of(dlgCtx);
              final messenger = ScaffoldMessenger.of(context);
              nav.pop();
              setState(() => _isLoading = true);
              try {
                final ok = await _apiService.deleteEmployee(emp['id'] as int);
                if (ok) {
                  await _loadData();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Сотрудник удалён")),
                    );
                  }
                } else {
                  throw Exception("Сервер вернул ошибку");
                }
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("Ошибка: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Add employee ──────────────────────────────────────────────────────────

  void _showAddEmployeeDialog() {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl  = TextEditingController();
    final emailCtrl     = TextEditingController();
    final passwordCtrl  = TextEditingController();
    String selectedRole = 'employee';
    bool isSubmitting   = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Добавить сотрудника"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dlgField(firstNameCtrl, "Имя"),
                _dlgField(lastNameCtrl,  "Фамилия"),
                _dlgField(emailCtrl,     "Email",
                    type: TextInputType.emailAddress),
                _dlgField(passwordCtrl, "Пароль", obscure: true),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: "Роль",
                    border: OutlineInputBorder(),
                  ),
                  items: _buildRoleItems(forOwner: _myRole == 'owner'),
                  onChanged: (v) => setDlg(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text("Отмена"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final nav       = Navigator.of(dlgCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      setDlg(() => isSubmitting = true);
                      try {
                        final ok = await _apiService.addEmployee({
                          "first_name": firstNameCtrl.text.trim(),
                          "last_name":  lastNameCtrl.text.trim(),
                          "email":      emailCtrl.text.trim(),
                          "password":   passwordCtrl.text,
                          "role":       selectedRole,
                        });
                        if (!mounted) return;
                        if (ok) {
                          nav.pop();
                          setState(() => _isLoading = true);
                          await _loadData();
                        } else {
                          setDlg(() => isSubmitting = false);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Ошибка: проверьте данные"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlg(() => isSubmitting = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text("Ошибка: $e")),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Создать"),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit employee ─────────────────────────────────────────────────────────

  void _showEditEmployeeDialog(dynamic emp) {
    final emailCtrl     = TextEditingController(text: emp['email']      ?? '');
    final firstNameCtrl = TextEditingController(text: emp['first_name'] ?? '');
    final lastNameCtrl  = TextEditingController(text: emp['last_name']  ?? '');
    final passwordCtrl  = TextEditingController();
    String selectedRole = emp['role'] ?? 'employee';

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Редактировать сотрудника"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dlgField(firstNameCtrl, "Имя"),
                _dlgField(lastNameCtrl,  "Фамилия"),
                _dlgField(emailCtrl,     "Email",
                    type: TextInputType.emailAddress),
                _dlgField(passwordCtrl,
                    "Новый пароль (необязательно)", obscure: true),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: "Роль",
                    border: OutlineInputBorder(),
                  ),
                  items: _buildRoleItems(forOwner: _myRole == 'owner'),
                  onChanged: (v) => setDlg(() => selectedRole = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text("Отмена"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nav       = Navigator.of(dlgCtx);
                final messenger = ScaffoldMessenger.of(context);
                final data = <String, dynamic>{
                  'email':      emailCtrl.text.trim(),
                  'first_name': firstNameCtrl.text.trim(),
                  'last_name':  lastNameCtrl.text.trim(),
                  'role':       selectedRole,
                };
                if (passwordCtrl.text.isNotEmpty) {
                  data['password'] = passwordCtrl.text;
                }
                try {
                  final ok = await _apiService.updateEmployee(
                    emp['id'] as int,
                    data,
                  );
                  if (!mounted) return;
                  if (ok) {
                    nav.pop();
                    setState(() => _isLoading = true);
                    await _loadData();
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text("Данные сотрудника обновлены")),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text("Ошибка сохранения"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("Ошибка: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text("Сохранить"),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _dlgField(
    TextEditingController ctrl,
    String label, {
    TextInputType? type,
    bool obscure = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  List<DropdownMenuItem<String>> _buildRoleItems({required bool forOwner}) => [
        if (forOwner)
          const DropdownMenuItem(value: 'owner',    child: Text("Владелец")),
        const DropdownMenuItem(value: 'manager',  child: Text("Менеджер")),
        const DropdownMenuItem(value: 'employee', child: Text("Сотрудник")),
      ];

  String _empName(dynamic emp) {
    final full = (emp['full_name'] as String?) ?? '';
    if (full.isNotEmpty) return full;
    final n = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : (emp['username'] ?? 'Unknown');
  }

  // ── Company header (banner + logo) ────────────────────────────────────────

  Widget _buildCompanyHeader() {
    final bannerUrl = (_company?['banner'] as String?) ?? '';
    final logoUrl   = (_company?['logo']   as String?) ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Banner ──────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _myRole == 'owner' ? () => _uploadMedia(isBanner: true) : null,
          child: SizedBox(
            height: _bannerH,
            width: double.infinity,
            child: bannerUrl.isNotEmpty
                ? Image.network(
                    bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultBanner(),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _defaultBanner(),
                      if (_myRole == 'owner')
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.white54, size: 28),
                              SizedBox(height: 4),
                              Text('Add cover',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),

        // ── Logo circle ─────────────────────────────────────────────────────
        Positioned(
          bottom: -_logoOverlap,
          left: 16,
          child: GestureDetector(
            onTap:
                _myRole == 'owner' ? () => _uploadMedia(isBanner: false) : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _logoD,
                  height: _logoD,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage:
                        logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                    child: logoUrl.isEmpty
                        ? const Icon(Icons.business,
                            color: _blue, size: 28)
                        : null,
                  ),
                ),
                if (_myRole == 'owner')
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultBanner() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_blue, _purple],
          ),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: _blue),
        ),
      );
    }

    final companyName = (_company?['name'] as String?) ?? '—';
    final inn         = _company?['inn'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Company Management"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Уведомления',
            onPressed: () {},
          ),
        ],
      ),
      drawer: const AppDrawer(activePage: DrawerPage.company),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Company banner + logo ──────────────────────────────────────────
          _buildCompanyHeader(),

          // Space for logo overflow (_logoOverlap) + 8px gap
          const SizedBox(height: _logoOverlap + 8),

          // ── Company name / INN ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (inn != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "ИНН: $inn",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Employees header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Employees",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (_canAdd())
                  ElevatedButton.icon(
                    onPressed: _showAddEmployeeDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Add"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Employee list ──────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _employees.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final emp       = _employees[index];
                final name      = _empName(emp);
                final avatarUrl = (emp['avatar'] as String?) ?? '';
                final canModify = _canModify(emp);

                return ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EmployeeProfileScreen(employee: emp),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: _blue),
                          )
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    emp['role_display'] ?? emp['role'] ?? 'Employee',
                  ),
                  trailing: canModify
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: _blue),
                              tooltip: "Редактировать",
                              onPressed: () => _showEditEmployeeDialog(emp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: "Удалить",
                              onPressed: () => _confirmDelete(emp),
                            ),
                          ],
                        )
                      : const Icon(Icons.chevron_right,
                          color: Color(0xFF94A3B8), size: 18),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
