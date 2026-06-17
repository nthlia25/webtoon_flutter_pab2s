import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/screens/detail_screen.dart';
import 'package:webtoon_flutter_pab2/theme.dart';

List<Map<String, dynamic>> groupHistoryEntries(
  List<Map<String, String>> entries,
) {
  final grouped = <String, List<Map<String, String>>>{};

  for (final entry in entries) {
    final title = (entry['title'] ?? '').trim();
    final episode = (entry['episode'] ?? '').trim();
    final timestamp = (entry['timestamp'] ?? '').trim();
    final latitude = (entry['latitude'] ?? '').trim();
    final longitude = (entry['longitude'] ?? '').trim();

    if (title.isEmpty || episode.isEmpty) {
      continue;
    }

    final key = title.toLowerCase();
    grouped.putIfAbsent(key, () => []);

    final existingIndex = grouped[key]!.indexWhere(
      (item) => item['episode'] == episode && item['title'] == title,
    );

    final normalizedEntry = {
      'title': title,
      'episode': episode,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (existingIndex == -1) {
      grouped[key]!.add(normalizedEntry);
    } else if (timestamp.compareTo(
          grouped[key]![existingIndex]['timestamp'] ?? '',
        ) >
        0) {
      grouped[key]![existingIndex] = normalizedEntry;
    }
  }

  final groupedList = grouped.entries.map((entry) {
    final title = entry.value.first['title'] ?? '';
    final episodes = entry.value
      ..sort((a, b) {
        return (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? '');
      });

    return {
      'title': title,
      'lastTimestamp': episodes.first['timestamp'] ?? '',
      'episodes': episodes,
    };
  }).toList();

  groupedList.sort((a, b) {
    return (b['lastTimestamp'] as String).compareTo(
      a['lastTimestamp'] as String,
    );
  });

  return groupedList;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _historyData = [];
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

    final List<Map<String, String>> parsedHistory = [];

    for (String entry in rawHistory) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) {
          final title = decoded['title']?.toString() ?? '';
          final episode = decoded['episode']?.toString() ?? '';
          final timestamp = decoded['timestamp']?.toString() ?? '';
          final latitude = decoded['latitude']?.toString() ?? '';
          final longitude = decoded['longitude']?.toString() ?? '';

          if (title.isNotEmpty && episode.isNotEmpty) {
            parsedHistory.add({
              'title': title,
              'episode': episode,
              'timestamp': timestamp,
              'latitude': latitude,
              'longitude': longitude,
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
      _historyData = groupHistoryEntries(parsedHistory);
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

  Future<void> _openEpisodeLocation(
    String latitude,
    String longitude,
  ) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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
                final episodes =
                    (item['episodes'] as List<Map<String, String>>?) ?? [];

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
                        const SizedBox(height: 4),
                        for (final episode in episodes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${episode['episode']}: ${_formatTimestamp(episode['timestamp'])}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                if ((episode['latitude'] ?? '').isNotEmpty &&
                                    (episode['longitude'] ?? '').isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: kSoftPink,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${episode['latitude']?.substring(0, 8)}, ${episode['longitude']?.substring(0, 8)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await _openEpisodeLocation(
                                            episode['latitude'] ?? '',
                                            episode['longitude'] ?? '',
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                        ),
                                        child: const Text(
                                          'Maps',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: kSoftPink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  const Text(
                                    'Belum ada GPS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black45,
                                    ),
                                  ),
                              ],
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
                        final prefs = await SharedPreferences.getInstance();
                        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                        final List<String> uploaded =
                            prefs.getStringList('${uid}_uploaded_webtoons') ??
                            prefs.getStringList('uploaded_webtoons') ??
                            [];

                        final targetWebtoon = uploaded
                            .map((raw) => jsonDecode(raw))
                            .whereType<Map<String, dynamic>>()
                            .map((decoded) => Webtoon.fromJson(decoded))
                            .firstWhere(
                              (webtoon) =>
                                  webtoon.title.toLowerCase() ==
                                  (item['title'] ?? '').toLowerCase(),
                              orElse: () => Webtoon(
                                id: '',
                                title: '',
                                genre: '',
                                rating: '0.0',
                                image: '',
                                synopsis: '',
                                episodes: const [],
                              ),
                            );

                        if (targetWebtoon.id.isEmpty) {
                          throw Exception('Webtoon not found');
                        }

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DetailScreen(webtoon: targetWebtoon),
                          ),
                        );
                        _loadHistory();
                      } catch (e) {
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
