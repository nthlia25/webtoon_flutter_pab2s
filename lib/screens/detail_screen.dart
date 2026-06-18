import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/theme.dart';
import 'viewer_screen.dart';

// PASTIKAN IMPORT FILE INI SESUAI DENGAN LOKASI FILE ANDA:
import 'upload_episode_screen.dart'; 

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

  Future<void> _checkIsFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        List<dynamic> favorites = doc.data()?['favorites'] ?? [];
        if (mounted) {
          setState(() {
            _isFavorite = favorites.contains(widget.webtoon.id.toString());
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking favorite: $e");
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu untuk menyukai komik ini.')),
      );
      return;
    }

    setState(() {
      _isFavorite = !_isFavorite;
    });

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      if (_isFavorite) {
        await userRef.set({
          'favorites': FieldValue.arrayUnion([widget.webtoon.id.toString()])
        }, SetOptions(merge: true));
      } else {
        await userRef.update({
          'favorites': FieldValue.arrayRemove([widget.webtoon.id.toString()])
        });
      }
    } catch (e) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui favorit: $e')));
      }
    }
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
    final bool isAsset = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');

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
            return decoded['title'] == title && decoded['episode'] == episode;
          }
        } catch (_) {}

        final splitData = item.split('|');
        return splitData.length >= 2 && splitData[0] == title && splitData[1] == episode;
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
      // --- TOMBOL TAMBAH EPISODE (HANYA MUNCUL UNTUK PEMILIK KOMIK) ---
      floatingActionButton: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('webtoons').doc(widget.webtoon.id.toString()).get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final webtoonOwnerId = data['userId'];
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;

            // Jika yang login adalah pembuat komik ini, tampilkan tombolnya
            if (currentUserId != null && currentUserId == webtoonOwnerId) {
              return FloatingActionButton.extended(
                onPressed: () {
                  // Arahkan ke halaman upload episode
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UploadEpisodeScreen(webtoonId: widget.webtoon.id.toString()),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Tambah Episode', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              );
            }
          }
          return const SizedBox.shrink(); // Sembunyikan jika bukan pemilik komik
        },
      ),
      // ---------------------------------------------------------------
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildCoverImage(widget.webtoon.image),
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

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Daftar Episode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('webtoons')
                  .doc(widget.webtoon.id.toString())
                  .collection('episodes')
                  .orderBy('episodeNumber')
                  .snapshots(),
              builder: (context, snapshot) {
                List<String> episodesList = List<String>.from(widget.webtoon.episodes);

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  episodesList.clear();
                  for (var doc in snapshot.data!.docs) {
                    episodesList.add(doc['title'].toString());
                  }
                }

                if (episodesList.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    child: Text('Belum ada episode yang tersedia.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: episodesList.length,
                  itemBuilder: (context, index) {
                    final String episodeName = episodesList[index];
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
                                episodes: episodesList,
                                initialEpisodeIndex: index,
                                coverImage: widget.webtoon.image,
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
                );
              },
            ),
            const SizedBox(height: 80), // Beri jarak agar list tidak tertutup tombol mengambang
          ],
        ),
      ),
    );
  }
}