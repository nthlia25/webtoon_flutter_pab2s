import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/theme.dart';
import 'viewer_screen.dart';

class DetailScreen extends StatefulWidget {
  final Webtoon webtoon;

  const DetailScreen({super.key, required this.webtoon});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIsFavorite();
  }

  String _userStorageKey(String key) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${uid}_$key';
  }

  // Memeriksa apakah webtoon ini sudah ditandai favorit di memori lokal
  Future<void> _checkIsFavorite() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final favoriteKey = _userStorageKey('webtoon_${widget.webtoon.id}');
    setState(() {
      _isFavorite = prefs.containsKey(favoriteKey);
    });
  }

  Widget _buildCoverImage(
    String image, {
    double width = double.infinity,
    double height = 250,
  }) {
    if (image.isEmpty) {
      return Container(width: width, height: height, color: Colors.grey[200]);
    }

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
    } catch (e) {
      return Container(width: width, height: height, color: Colors.grey[200]);
    }
  }

  // Fungsi menambah/menghapus dari daftar favorit lokal
  Future<void> _toggleFavorite() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final favoriteKey = _userStorageKey('webtoon_${widget.webtoon.id}');
    final favoriteListKey = _userStorageKey('favoriteWebtoons');

    setState(() {
      _isFavorite = !_isFavorite;
    });

    if (_isFavorite) {
      await prefs.setString(favoriteKey, widget.webtoon.title);

      List<String> favoriteWebtoonIds =
          prefs.getStringList(favoriteListKey) ?? [];
      if (!favoriteWebtoonIds.contains(widget.webtoon.id.toString())) {
        favoriteWebtoonIds.add(widget.webtoon.id.toString());
      }
      await prefs.setStringList(favoriteListKey, favoriteWebtoonIds);
    } else {
      await prefs.remove(favoriteKey);

      List<String> favoriteWebtoonIds =
          prefs.getStringList(favoriteListKey) ?? [];
      favoriteWebtoonIds.remove(widget.webtoon.id.toString());
      await prefs.setStringList(favoriteListKey, favoriteWebtoonIds);
    }
  }

  Future<void> _saveHistory(String title, String episode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList('readHistory') ?? [];

      final timestamp = DateTime.now().toIso8601String();
      final entry = jsonEncode({
        'title': title,
        'episode': episode,
        'timestamp': timestamp,
      });

      raw.removeWhere((item) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            return decoded['title'] == title &&
                decoded['episode'] == episode;
          }
        } catch (_) {}

        final splitData = item.split('|');
        return splitData.length >= 2 &&
            splitData[0] == title &&
            splitData[1] == episode;
      });

      raw.insert(0, entry);
      if (raw.length > 200) raw.removeRange(200, raw.length);

      await prefs.setStringList('readHistory', raw);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.webtoon.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Gambar Cover Utama Menggunakan Stack + Tombol Favorit di Sudut
            Stack(
              children: [
                _buildCoverImage(widget.webtoon.image),
                // Gradasi gelap di bawah cover agar tombol favorit kontras terlihat
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ),
                ),
              ],
            ),

            // 2. Deskripsi Konten (Sinopsis, Genre, Rating)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.webtoon.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Baris Genre & Rating
                  Row(
                    children: [
                      const Icon(Icons.bookmark, color: kSoftPink, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Genre: ${widget.webtoon.genre}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Rating: ${widget.webtoon.rating}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Detail Sinopsis
                  const Text(
                    'Sinopsis:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.webtoon.synopsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1),

            // 3. Daftar Episode Komik
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Daftar Episode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.webtoon.episodes.length,
              itemBuilder: (context, index) {
                final String episodeName = widget.webtoon.episodes[index];
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await _saveHistory(
                        widget.webtoon.title,
                        episodeName,
                      );

                      if (!mounted) return;

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewerScreen(
                            title: widget.webtoon.title,
                            episodeTitle: episodeName,
                            episodes: widget.webtoon.episodes,
                            initialEpisodeIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kSoftPink.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kSoftPink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                episodeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Baca sekarang',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
