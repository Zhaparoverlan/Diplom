import 'package:flutter/material.dart';

/// Read-only view of another employee's public profile data.
/// All data is passed in from the company employee list — no extra API call needed
/// since UserProfileSerializer already returns all fields (bio, phone, birthday, avatar…).
class EmployeeProfileScreen extends StatelessWidget {
  final Map<String, dynamic> employee;

  const EmployeeProfileScreen({super.key, required this.employee});

  static const _blue    = Color(0xFF2563EB);
  static const _purple  = Color(0xFF7C3AED);
  static const _bannerH = 160.0;
  static const _avatarR = 42.0;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _name() {
    final full = (employee['full_name'] as String?) ?? '';
    if (full.isNotEmpty) return full;
    final n = '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : (employee['username'] ?? 'Employee');
  }

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name        = _name();
    final initial     = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarUrl   = (employee['avatar']          as String?) ?? '';
    final bannerUrl   = (employee['profile_banner']  as String?) ?? '';
    final role        = (employee['role_display']    as String?)
                        ?? (employee['role']         as String?) ?? '';
    final email       = (employee['email']           as String?) ?? '';
    final phone       = (employee['phone']           as String?) ?? '';
    final bio         = (employee['bio']             as String?) ?? '';
    final birthday    = (employee['birthday']        as String?) ?? '';
    final companyName = (employee['company_name']    as String?) ?? '';
    final dateJoined  = (employee['date_joined']     as String?) ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Employee Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            tooltip: 'Уведомления',
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(initial, avatarUrl, bannerUrl),
            const SizedBox(height: _avatarR + 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
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
                  const SizedBox(height: 6),
                  if (role.isNotEmpty) _roleBadge(role),
                  const SizedBox(height: 24),
                  const Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (email.isNotEmpty)
                    _infoCard(Icons.email_outlined, 'Email', email),
                  if (phone.isNotEmpty)
                    _infoCard(Icons.phone_outlined, 'Phone', phone),
                  if (role.isNotEmpty)
                    _infoCard(Icons.shield_outlined, 'Role', role),
                  if (companyName.isNotEmpty)
                    _infoCard(Icons.business_outlined, 'Company', companyName),
                  if (dateJoined.isNotEmpty)
                    _infoCard(
                      Icons.calendar_today_outlined,
                      'Member Since',
                      _fmt(dateJoined.split('T')[0]),
                    ),
                  if (birthday.isNotEmpty)
                    _infoCard(Icons.cake_outlined, 'Birthday', _fmt(birthday)),
                  if (bio.isNotEmpty) _bioCard(bio),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(String initial, String avatarUrl, String bannerUrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: _bannerH,
          width: double.infinity,
          child: bannerUrl.isNotEmpty
              ? Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _defaultBanner(),
                )
              : _defaultBanner(),
        ),
        Positioned(
          bottom: -_avatarR,
          left: 20,
          child: Container(
            width: (_avatarR + 3) * 2,
            height: (_avatarR + 3) * 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Center(
              child: avatarUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: _avatarR,
                      backgroundImage: NetworkImage(avatarUrl),
                      onBackgroundImageError: (_, __) {},
                    )
                  : CircleAvatar(
                      radius: _avatarR,
                      backgroundColor: _blue,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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

  // ── Cards ──────────────────────────────────────────────────────────────────

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

  Widget _infoCard(IconData icon, String label, String value) => Container(
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
            value,
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
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
}
