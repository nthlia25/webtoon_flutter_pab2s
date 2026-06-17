import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/screens/detail_screen.dart';
import 'package:webtoon_flutter_pab2/theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  List<Map<String, String>> _historyData = [];
  bool _isLoading = true;

  void reloadHistory() {
    if (mounted) {
      _loadHistory();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadHistory();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true) {
      _loadHistory();
    }
  }

  // Memuat data riwayat dari memori lokal hp
  String _userStorageKey(String key) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${uid}_$key';
  }

  Future<void> _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> rawHistory =
        prefs.getStringList(_userStorageKey('readHistory')) ?? [];

    if (rawHistory.isEmpty) {
      rawHistory = prefs.getStringList('readHistory') ?? [];
    }

    List<Map<String, String>> parsedHistory = [];

    for (String entry in rawHistory) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) {
          final title = decoded['title']?.toString() ?? '';
          final episode = decoded['episode']?.toString() ?? '';
          final timestamp = decoded['timestamp']?.toString() ?? '';

          if (title.isNotEmpty && episode.isNotEmpty) {
            parsedHistory.add({
              'title': title,
              'episode': episode,
              'timestamp': timestamp,
            });
          }
          continue;
        }
      } catch (_) {}

      // Fallback untuk riwayat lama yang masih berupa "Judul|Episode"
      final splitData = entry.split('|');
      if (splitData.length >= 2) {
        parsedHistory.add({
          'title': splitData[0],
          'episode': splitData[1],
          'timestamp': splitData.length > 2 ? splitData[2] : '',
        });
      }
    }

    setState(() {
      _historyData = parsedHistory;
      _isLoading = false;
    });
  }

  // Fungsi opsional untuk menghapus semua riwayat bacaan
  Future<void> _clearAllHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userHistoryKey = _userStorageKey('readHistory');
    await prefs.remove(userHistoryKey);
    await prefs.remove('readHistory');
    setState(() {
      _historyData.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua riwayat berhasil dihapus')),
      );
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return 'Waktu tidak tersedia';
    }

    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Riwayat Membaca',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          if (_historyData.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              tooltip: 'Hapus Semua',
              onPressed: () {
                // Konfirmasi sebelum menghapus semua
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Riwayat?'),
                    content: const Text(
                      'Apakah Anda yakin ingin menghapus seluruh riwayat membaca?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearAllHistory();
                        },
                        child: const Text(
                          'Hapus',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kSoftPink))
          : _historyData.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _historyData.length,
              itemBuilder: (context, index) {
                final item = _historyData[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kSoftPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history_toggle_off_rounded,
                        color: kSoftPink,
                      ),
                    ),
                    title: Text(
                      item['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terakhir dibaca: ${item['episode']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Waktu: ${_formatTimestamp(item['timestamp'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () async {
                      // Mencari objek Webtoon asli berdasarkan judul agar bisa diarahkan ke DetailScreen
                      try {
                        final Webtoon targetWebtoon = dummyWebtoons.firstWhere(
                          (w) =>
                              w.title.toLowerCase() ==
                              item['title']?.toLowerCase(),
                        );

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetailScreen(webtoon: targetWebtoon),
                          ),
                        );
                        // Refresh data saat kembali (siapa tahu urutan riwayat berubah)
                        _loadHistory();
                      } catch (e) {
                        // Jika data dummy tidak ditemukan
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Detail komik tidak ditemukan.'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Belum ada riwayat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Komik yang Anda baca akan muncul di sini.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
