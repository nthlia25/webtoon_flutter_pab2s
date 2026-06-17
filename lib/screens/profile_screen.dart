import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webtoon_flutter_pab2/screens/favorite_screen.dart';
import 'package:webtoon_flutter_pab2/screens/history_screen.dart';
import 'package:webtoon_flutter_pab2/screens/signin_screen.dart';
import 'package:webtoon_flutter_pab2/theme.dart';
import 'package:webtoon_flutter_pab2/theme_manager.dart';
import 'package:webtoon_flutter_pab2/service/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  String _displayName = '';
  String _email = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    final User? user = _authService.currentUser;
    final isDark = themeNotifier.value == ThemeMode.dark;

    setState(() {
      _displayName = user?.displayName ?? _fallbackName(user?.email);
      _email = user?.email ?? '';
      _isDarkMode = isDark;
      _isLoading = false;
    });
  }

  String _fallbackName(String? email) {
    if (email == null || email.isEmpty) return 'Pengguna';
    return email.split('@').first;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final controller = TextEditingController(text: _displayName);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Profil'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nama tidak boleh kosong'),
                            ),
                          );
                          return;
                        }

                        setStateDialog(() => _isSaving = true);
                        await _saveProfile(newName);
                        setStateDialog(() => _isSaving = false);
                        Navigator.pop(context);
                      },
                child: _isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveProfile(String newName) async {
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not found');

      await user.updateDisplayName(newName);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'username': newName},
      );

      // reload user to reflect changes
      await user.reload();

      if (mounted) {
        setState(() {
          _displayName = newName;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui profil: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kSoftPink))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: kSoftPink.withOpacity(.15),
                    child: Text(
                      _initials(_displayName),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ).copyWith(color: kSoftPink),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: kSoftPink,
                      ),
                      title: const Text('Edit Profil'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showEditProfileDialog,
                    ),
                  ),

                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: SwitchListTile(
                      secondary: const Icon(
                        Icons.dark_mode_outlined,
                        color: kSoftPink,
                      ),
                      title: const Text('Dark Mode'),
                      value: _isDarkMode,
                      onChanged: (value) async {
                        await saveThemeMode(value);
                        if (mounted) {
                          setState(() {
                            _isDarkMode = value;
                          });
                        }
                      },
                    ),
                  ),

                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(
                        Icons.favorite_border,
                        color: kSoftPink,
                      ),
                      title: const Text('Favorit'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FavoriteScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.history, color: kSoftPink),
                      title: const Text('Riwayat'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Keluar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _confirmSignOut,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
