import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _blue = Color(0xFF2563EB);
  static const _bannerH = 190.0;
  static const _avatarR = 48.0;

  final _api = ApiService();

  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  DateTime? _birthday;

  XFile?     _avatarFile;
  Uint8List? _avatarBytes;
  XFile?     _bannerFile;
  Uint8List? _bannerBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final data = await _api.getUserProfile();
      _fill(data);
      if (mounted) {
        setState(() {
          _user = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(Map<String, dynamic> d) {
    _firstNameCtrl.text = d['first_name'] ?? '';
    _lastNameCtrl.text  = d['last_name']  ?? '';
    _emailCtrl.text     = d['email']      ?? '';
    _phoneCtrl.text     = d['phone']      ?? '';
    _bioCtrl.text       = d['bio']        ?? '';
    _birthday = d['birthday'] != null ? DateTime.tryParse(d['birthday']) : null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await _api.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName:  _lastNameCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        bio:       _bioCtrl.text.trim(),
        birthday: _birthday != null
            ? '${_birthday!.year}-'
                '${_birthday!.month.toString().padLeft(2, '0')}-'
                '${_birthday!.day.toString().padLeft(2, '0')}'
            : null,
        avatarFile: _avatarFile,
        bannerFile: _bannerFile,
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _user = updated;
          _editing = false;
          _avatarFile = null; _avatarBytes = null;
          _bannerFile = null; _bannerBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save changes'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    if (_user != null) _fill(_user!);
    setState(() {
      _editing = false;
      _avatarFile = null; _avatarBytes = null;
      _bannerFile = null; _bannerBytes = null;
    });
  }

  Future<void> _pickImage({required bool isAvatar}) async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      if (isAvatar) {
        _avatarFile  = img;
        _avatarBytes = bytes;
      } else {
        _bannerFile  = img;
        _bannerBytes = bytes;
      }
    });
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    return d == null
        ? iso
        : '${d.day.toString().padLeft(2, '0')}.'
            '${d.month.toString().padLeft(2, '0')}.'
            '${d.year}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year}';

  String _displayName(Map<String, dynamic> d) {
    final n = '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : (d['username'] ?? 'User');
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    final d         = _user!;
    final name      = _displayName(d);
    final role      = d['role_display'] ?? d['role'] ?? '';
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final avatarUrl = (d['avatar'] as String?) ?? '';
    final bannerUrl = (d['profile_banner'] as String?) ?? '';
    final bio       = (d['bio'] as String?) ?? '';
    final birthday  = (d['birthday'] as String?) ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Back button is shown automatically when pushed; keep it white for visibility
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            tooltip: 'Уведомления',
            onPressed: () {},
          ),
        ],
      ),
      drawer: const AppDrawer(activePage: DrawerPage.profile),
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(initial, avatarUrl, bannerUrl),
            // Space for the avatar that protrudes below banner
            const SizedBox(height: _avatarR + 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 5),
                            _roleBadge(role),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _editing ? _saveCancel() : _editBtn(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('Account Information'),
                  const SizedBox(height: 12),
                  _editing
                      ? _editForm()
                      : _viewCards(d, name, bio, birthday),
                  const SizedBox(height: 28),
                  _changePasswordBtn(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(String initial, String avatarUrl, String bannerUrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Banner
        GestureDetector(
          onTap: _editing ? () => _pickImage(isAvatar: false) : null,
          child: SizedBox(
            height: _bannerH,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _bannerWidget(bannerUrl),
                if (_editing)
                  Container(
                    color: Colors.black38,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Change cover',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Avatar
        Positioned(
          bottom: -_avatarR,
          left: 20,
          child: GestureDetector(
            onTap: _editing ? () => _pickImage(isAvatar: true) : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: (_avatarR + 3) * 2,
                  height: (_avatarR + 3) * 2,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Center(child: _avatarWidget(avatarUrl, initial)),
                ),
                if (_editing)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bannerWidget(String url) {
    if (_bannerBytes != null) {
      return Image.memory(_bannerBytes!, fit: BoxFit.cover);
    }
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultBanner(),
      );
    }
    return _defaultBanner();
  }

  Widget _defaultBanner() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          ),
        ),
      );

  Widget _avatarWidget(String url, String initial) {
    if (_avatarBytes != null) {
      return CircleAvatar(
        radius: _avatarR,
        backgroundImage: MemoryImage(_avatarBytes!),
      );
    }
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: _avatarR,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: _avatarR,
      backgroundColor: _blue,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 32,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Buttons ──────────────────────────────────────────────────────────────────

  Widget _roleBadge(String role) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _blue.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          role.toUpperCase(),
          style: const TextStyle(
            color: _blue,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _editBtn() => OutlinedButton.icon(
        onPressed: () => setState(() => _editing = true),
        icon: const Icon(Icons.edit_outlined, size: 15),
        label: const Text('Edit Profile'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: const BorderSide(color: _blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 13),
        ),
      );

  Widget _saveCancel() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _saving ? null : _cancelEdit,
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 15),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      );

  Widget _changePasswordBtn() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ChangePasswordScreen()),
          ),
          icon: const Icon(Icons.lock_outline, size: 17),
          label: const Text('Change Password'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  // ── View mode ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      );

  Widget _viewCards(
      Map<String, dynamic> d, String name, String bio, String birthday) {
    final phone = (d['phone'] as String?) ?? '';
    return Column(
      children: [
        _infoCard(Icons.person_outline, 'Full Name', name),
        _infoCard(Icons.email_outlined, 'Email', d['email']),
        if (phone.isNotEmpty)
          _infoCard(Icons.phone_outlined, 'Phone', phone),
        _infoCard(Icons.business_outlined, 'Company',
            d['company_name'] ?? 'N/A'),
        _infoCard(Icons.shield_outlined, 'Role',
            d['role_display'] ?? d['role']),
        _infoCard(Icons.calendar_today_outlined, 'Member Since',
            _fmt(d['date_joined']?.toString().split('T')[0])),
        if (birthday.isNotEmpty)
          _infoCard(Icons.cake_outlined, 'Birthday', _fmt(birthday)),
        if (bio.isNotEmpty) _bioCard(bio),
      ],
    );
  }

  Widget _infoCard(IconData icon, String label, String? value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _blue.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _blue, size: 19),
          ),
          title: Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          subtitle: Text(
            value ?? 'N/A',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      );

  Widget _bioCard(String bio) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _blue.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline, color: _blue, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bio',
                    style:
                        TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Edit mode ────────────────────────────────────────────────────────────────

  Widget _editForm() => Column(
        children: [
          _field(_firstNameCtrl, 'First Name', Icons.person_outline),
          _field(_lastNameCtrl,  'Last Name',  Icons.person_outline),
          _field(_emailCtrl, 'Email', Icons.email_outlined,
              type: TextInputType.emailAddress),
          _field(_phoneCtrl, 'Phone', Icons.phone_outlined,
              type: TextInputType.phone),
          _field(_bioCtrl, 'Bio', Icons.info_outline, lines: 4),
          _birthdayTile(),
        ],
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    int lines = 1,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: ctrl,
          keyboardType: type,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: _blue, size: 19),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _blue, width: 2),
            ),
          ),
        ),
      );

  Widget _birthdayTile() {
    final label = _birthday != null ? _fmtDate(_birthday!) : 'Not set';
    return GestureDetector(
      onTap: _pickBirthday,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: _blue, size: 19),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Birthday',
                  style:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
