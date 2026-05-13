import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../login_screen.dart';
import '../screens/company_settings_screen.dart';
import '../screens/docs_list_screen.dart';
import '../screens/profile_screen.dart';
import '../services/api_service.dart';

enum DrawerPage { home, profile, company }

class AppDrawer extends StatefulWidget {
  final DrawerPage activePage;

  const AppDrawer({super.key, required this.activePage});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  static const _blue   = Color(0xFF2563EB);
  static const _purple = Color(0xFF7C3AED);

  final _storage = const FlutterSecureStorage();
  final _api     = ApiService();

  String _name      = '';
  String _role      = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final d     = await _api.getUserProfile();
      final first = (d['first_name'] ?? '') as String;
      final last  = (d['last_name']  ?? '') as String;
      final full  = '$first $last'.trim();
      if (!mounted) return;
      setState(() {
        _name      = full.isNotEmpty ? full : (d['username'] ?? '');
        _role      = (d['role_display'] ?? d['role'] ?? '') as String;
        _avatarUrl = (d['avatar'] as String?) ?? '';
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'U';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_blue, _purple],
              ),
            ),
            accountName: Text(
              _name.isEmpty ? '…' : _name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              _role.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage:
                  _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
              child: _avatarUrl.isEmpty
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          _tile(
            icon:   Icons.home_outlined,
            label:  'Home',
            active: widget.activePage == DrawerPage.home,
            onTap: () {
              Navigator.pop(context);
              if (widget.activePage != DrawerPage.home) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DocsListScreen()),
                  (r) => false,
                );
              }
            },
          ),
          _tile(
            icon:   Icons.person_outline,
            label:  'Profile',
            active: widget.activePage == DrawerPage.profile,
            onTap: () {
              Navigator.pop(context);
              if (widget.activePage != DrawerPage.profile) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }
            },
          ),
          _tile(
            icon:   Icons.business_outlined,
            label:  'Company',
            active: widget.activePage == DrawerPage.company,
            onTap: () {
              Navigator.pop(context);
              if (widget.activePage != DrawerPage.company) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CompanySettingsScreen()),
                );
              }
            },
          ),
          const Spacer(),
          const Divider(indent: 16, endIndent: 16),
          _tile(
            icon:   Icons.logout,
            label:  'Logout',
            active: false,
            color:  Colors.redAccent,
            onTap: () async {
              await _storage.deleteAll();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
                (r) => false,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color? color,
  }) {
    final col = active ? _blue : (color ?? const Color(0xFF374151));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: active
          ? BoxDecoration(
              color: _blue.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: ListTile(
        leading: Icon(icon, color: col, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: col,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}
