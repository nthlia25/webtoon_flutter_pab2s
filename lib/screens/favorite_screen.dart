import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/screens/detail_screen.dart';
import 'package:webtoon_flutter_pab2/theme.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen>
    with WidgetsBindingObserver {
  List<Webtoon> _favoriteWebtoons = [];
  bool _isLoading = true;
  late DateTime _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastRefreshTime = DateTime.now();
    _loadFavoriteWebtoons();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastRefreshTime = DateTime.now();
      _loadFavoriteWebtoons();
    }
  }

  Widget _buildCoverImage(
    String image, {
    double width = 60,
    double height = 70,
  }) {
    if (image.isEmpty)
      return Container(width: width, height: height, color: Colors.grey[200]);

    final lower = image.toLowerCase();
    final bool isAsset =
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');

    if (isAsset) {
      return Image.asset(
        'assets/images/$image',
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }

    try {
      final bytes = base64Decode(image);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } catch (_) {
      return Container(width: width, height: height, color: Colors.grey[200]);
    }
  }

  // Mengambil daftar ID favorit dari SharedPreferences lalu mencocokkannya dengan Dummy Data
  Future<void> _loadFavoriteWebtoons() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    // Mengambil list ID yang pernah disimpan (jika tidak ada, return list kosong [])
    final List<String> favoriteIds =
        prefs.getStringList('${uid}_favoriteWebtoons') ??
        prefs.getStringList('favoriteWebtoons') ??
        [];

    // Build a map of available webtoons: dummy + uploaded
    final Map<String, Webtoon> pool = {for (var w in dummyWebtoons) w.id: w};

    final List<String> uploaded =
        prefs.getStringList('${uid}_uploaded_webtoons') ??
        prefs.getStringList('uploaded_webtoons') ??
        [];
    for (final raw in uploaded) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        final Webtoon w = Webtoon.fromJson(decoded);
        pool[w.id] = w;
      } catch (_) {}
    }

    final List<Webtoon> results = [];
    for (final id in favoriteIds) {
      if (pool.containsKey(id)) results.add(pool[id]!);
    }

    setState(() {
      _favoriteWebtoons = results;
      _isLoading = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh when screen becomes visible (e.g., tab switch)
    // Refresh if 2+ seconds since last refresh
    if (DateTime.now().difference(_lastRefreshTime).inSeconds >= 2) {
      _loadFavoriteWebtoons();
      _lastRefreshTime = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Webtoon Favorit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavoriteWebtoons,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kSoftPink))
          : _favoriteWebtoons.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _favoriteWebtoons.length,
              itemBuilder: (context, index) {
                final webtoon = _favoriteWebtoons[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildCoverImage(
                        webtoon.image,
                        height: 70,
                        width: 60,
                      ),
                    ),
                    title: Text(
                      webtoon.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          webtoon.genre,
                          style: const TextStyle(
                            color: kSoftPink,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              webtoon.rating,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
                    onTap: () async {
                      // Navigasi ke DetailScreen
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailScreen(webtoon: webtoon),
                        ),
                      );
                      // Ketika user kembali dari halaman detail, refresh list favoritnya
                      // (siapa tahu user menghapus status favorit di halaman detail)
                      setState(() {
                        _isLoading = true;
                      });
                      _loadFavoriteWebtoons();
                    },
                  ),
                );
              },
            ),
    );
  }

  // Tampilan estetik jika user belum menambahkan komik favorit sama sekali
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada komik favorit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ketuk ikon hati pada halaman detail komik.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
