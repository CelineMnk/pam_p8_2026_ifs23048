// lib/features/profile/profile_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/app_snackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchMe();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.person_outline), text: 'Akun'),
                Tab(icon: Icon(Icons.lock_outline),   text: 'Kata Sandi'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _AccountTab(),
            _PasswordTab(),
          ],
        ),
      ),
    );
  }
}

// ── Header dengan foto profil ──────────────────────────────────────────────────

class _ProfileHeader extends StatefulWidget {
  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);

    final auth  = context.read<AuthProvider>();
    final token = auth.authToken;
    if (token == null) return;

    dynamic result;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      result = await auth.updatePhoto(
        authToken: token, imageBytes: bytes,
        imageFilename: picked.name,
      );
    } else {
      result = await auth.updatePhoto(
        authToken: token, imageFile: File(picked.path),
      );
    }

    if (mounted) {
      setState(() => _uploading = false);
      AppSnackbar.show(context, result.message,
          isSuccess: result.success);
      if (result.success) auth.fetchMe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          final user = auth.user;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _uploading ? null : _pickAndUpload,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white24,
                      backgroundImage: user?.urlPhoto != null
                          ? NetworkImage(user!.urlPhoto!) : null,
                      child: user?.urlPhoto == null
                          ? Text(
                        (user?.name.isNotEmpty == true)
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : null,
                    ),
                    if (_uploading)
                      const CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.black38,
                        child: CircularProgressIndicator(
                            color: Colors.white),
                      ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: colorScheme.primary, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 14, color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(user?.name ?? '',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  )),
              Text('@${user?.username ?? ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ── Tab Akun ──────────────────────────────────────────────────────────────────

class _AccountTab extends StatefulWidget {
  const _AccountTab();

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<_AccountTab> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _loading       = false;
  bool _initialized   = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _initFields(AuthProvider auth) {
    if (_initialized) return;
    _nameCtrl.text     = auth.user?.name ?? '';
    _usernameCtrl.text = auth.user?.username ?? '';
    _initialized       = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth  = context.read<AuthProvider>();
    final token = auth.authToken;
    if (token == null) return;

    final result = await auth.updateMe(
      authToken: token,
      name:      _nameCtrl.text.trim(),
      username:  _usernameCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _loading = false);
      AppSnackbar.show(context, result.message,
          isSuccess: result.success);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        _initFields(auth);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informasi Akun',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                _Label('Nama Lengkap'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _profileFieldDeco(context,
                    hint: 'Masukkan nama lengkap',
                    icon: Icons.person_outline,
                  ),
                  validator: (v) =>
                  v?.trim().isEmpty == true
                      ? 'Nama tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),

                _Label('Username'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: _profileFieldDeco(context,
                    hint: 'Masukkan username',
                    icon: Icons.alternate_email_rounded,
                  ),
                  validator: (v) =>
                  v?.trim().isEmpty == true
                      ? 'Username tidak boleh kosong' : null,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_loading
                        ? 'Menyimpan...' : 'Simpan Perubahan'),
                    style: FilledButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 16),

                Text('Lainnya',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.red),
                    label: const Text('Keluar',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Tab Kata Sandi ─────────────────────────────────────────────────────────────

class _PasswordTab extends StatefulWidget {
  const _PasswordTab();

  @override
  State<_PasswordTab> createState() => _PasswordTabState();
}

class _PasswordTabState extends State<_PasswordTab> {
  final _formKey       = GlobalKey<FormState>();
  final _currentCtrl   = TextEditingController();
  final _newCtrl       = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  bool _loading        = false;
  bool _showCurrent    = false;
  bool _showNew        = false;
  bool _showConfirm    = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final auth  = context.read<AuthProvider>();
    final token = auth.authToken;
    if (token == null) return;

    final result = await auth.updatePassword(
      authToken:       token,
      currentPassword: _currentCtrl.text,
      newPassword:     _newCtrl.text,
    );

    if (mounted) {
      setState(() => _loading = false);
      AppSnackbar.show(context, result.message,
          isSuccess: result.success);
      if (result.success) {
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ubah Kata Sandi',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Buat kata sandi yang kuat dan unik.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            _Label('Kata Sandi Saat Ini'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _currentCtrl,
              obscureText: !_showCurrent,
              decoration: _profileFieldDeco(context,
                hint: 'Masukkan kata sandi saat ini',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(_showCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _showCurrent = !_showCurrent),
                ),
              ),
              validator: (v) =>
              v?.isEmpty == true
                  ? 'Kata sandi tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),

            _Label('Kata Sandi Baru'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newCtrl,
              obscureText: !_showNew,
              decoration: _profileFieldDeco(context,
                hint: 'Masukkan kata sandi baru',
                icon: Icons.lock_reset_outlined,
                suffix: IconButton(
                  icon: Icon(_showNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _showNew = !_showNew),
                ),
              ),
              validator: (v) {
                if (v?.isEmpty == true)
                  return 'Kata sandi tidak boleh kosong';
                if ((v?.length ?? 0) < 8)
                  return 'Minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _Label('Konfirmasi Kata Sandi Baru'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: _profileFieldDeco(context,
                hint: 'Konfirmasi kata sandi baru',
                icon: Icons.lock_clock_outlined,
                suffix: IconButton(
                  icon: Icon(_showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              validator: (v) {
                if (v?.isEmpty == true)
                  return 'Konfirmasi tidak boleh kosong';
                if (v != _newCtrl.text)
                  return 'Kata sandi tidak cocok';
                return null;
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _changePassword,
                icon: _loading
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Icon(Icons.lock_reset_rounded),
                label: Text(
                    _loading ? 'Mengubah...' : 'Ubah Kata Sandi'),
                style: FilledButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widget & fungsi ─────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge
        ?.copyWith(fontWeight: FontWeight.w600),
  );
}

InputDecoration _profileFieldDeco(
    BuildContext context, {
      required String hint,
      required IconData icon,
      Widget? suffix,
    }) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: colorScheme.primary),
    suffixIcon: suffix,
    filled: true,
    fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}