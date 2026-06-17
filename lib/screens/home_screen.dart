import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/theme.dart';
import 'package:webtoon_flutter_pab2/screens/detail_screen.dart';
import 'package:webtoon_flutter_pab2/screens/search_screen.dart';
import 'package:webtoon_flutter_pab2/screens/upload_screen.dart';

// Fungsi helper untuk menyamakan format teks genre saat pencocokan/filter
String normalizeGenre(String value) {
  return value.trim().toLowerCase();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Webtoon> _trendingWebtoons = [];
  final List<String> _genreLabels = const [
    'Romance',
    'Fantasy',
    'Action',
    'Comedy',
    'Drama',
    'Horror',
    'Sci-Fi',
    'Thriller',
    'Slice of Life',
    'Mystery',
  ];
  Map<String, List<Webtoon>> _genreWebtoons = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWebtoons();
  }

  // Fungsi pembantu untuk memuat gambar, baik dari asset local maupun Base64 dari Firestore
  Widget _buildCoverImage(
    String image, {
    double width = 150,
    double height = 150,
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
      // Decode Base64 string yang diambil dari Firestore field 'image'
      final bytes = base64Decode(image);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } catch (e) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }

  // Mengambil data real-time / langsung dari Cloud Firestore collection 'webtoons'
  Future<void> _loadWebtoons() async {
    setState(() {
      _isLoading = true;
    });

    List<Webtoon> all = [];

    try {
      // Fetch dokumen dari collection 'webtoons'
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('webtoons')
          .get();

      for (final doc in querySnapshot.docs) {
        try {
          final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Mapping data dokumen Firestore ke Model Webtoon secara aman
          final Webtoon w = Webtoon.fromJson({
            'id': data['id'] ?? doc.id,
            'title': data['title'] ?? '',
            'genre': data['genre'] ?? '',
            'rating': data['rating']?.toString() ?? '0.0', // Antisipasi jika rating bertipe num/double di Firestore
            'image': data['image'] ?? '',
            'synopsis': data['synopsis'] ?? '',
            'episodes': data['episodes'] != null 
                ? List<String>.from(data['episodes']) 
                : <String>[],
          });
          all.add(w);
        } catch (e) {
          debugPrint('Gagal parse dokumen ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error mengambil data dari Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data dari cloud: $e')),
        );
      }
    }

    // Filter webtoon berdasarkan masing-masing genre secara otomatis
    final genreWebtoons = {
      for (final genre in _genreLabels)
        genre: all
            .where(
              (webtoon) =>
                  normalizeGenre(webtoon.genre) == normalizeGenre(genre),
            )
            .toList(),
    };

    if (mounted) {
      setState(() {
        _trendingWebtoons = all; // Menjadikan semua item terunggah sebagai trending list sementara
        _genreWebtoons = genreWebtoons;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'PINK TOON',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ).copyWith(color: kSoftPink),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload, color: Colors.black),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadScreen(
                    onWebtoonAdded: (map) {
                      _loadWebtoons(); // Refresh otomatis setelah upload berhasil
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kSoftPink,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadScreen(
                onWebtoonAdded: (map) {
                  _loadWebtoons(); // Refresh otomatis setelah upload berhasil
                },
              ),
            ),
          );
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kSoftPink))
          : RefreshIndicator(
              color: kSoftPink,
              onRefresh: _loadWebtoons, // Memungkinkan user menarik layar ke bawah untuk refresh manual
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildWebtoonList('Trending Hari Ini', _trendingWebtoons),
                    for (final genre in _genreLabels)
                      if ((_genreWebtoons[genre] ?? []).isNotEmpty)
                        _buildWebtoonList(
                          'Genre $genre',
                          _genreWebtoons[genre] ?? [],
                        ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWebtoonList(String title, List<Webtoon> webtoons) {
    if (webtoons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: webtoons.length,
            itemBuilder: (BuildContext context, int index) {
              final Webtoon webtoon = webtoons[index];
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailScreen(webtoon: webtoon),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: _buildCoverImage(
                            webtoon.image,
                            width: 120,
                            height: 150,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          webtoon.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star, color: kSoftPink, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              webtoon.rating,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}