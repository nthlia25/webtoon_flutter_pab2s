import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/theme.dart';
import 'package:webtoon_flutter_pab2/screens/detail_screen.dart';
import 'package:webtoon_flutter_pab2/screens/search_screen.dart';
import 'package:webtoon_flutter_pab2/screens/upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Webtoon> _trendingWebtoons = [];
  List<Webtoon> _romanceWebtoons = [];
  List<Webtoon> _fantasyWebtoons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWebtoons();
  }

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

  Future<void> _loadWebtoons() async {
    await Future.delayed(const Duration(milliseconds: 300));

    List<Webtoon> all = List<Webtoon>.from(dummyWebtoons);

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final List<String> uploaded =
          prefs.getStringList('${uid}_uploaded_webtoons') ??
          prefs.getStringList('uploaded_webtoons') ??
          [];
      for (final raw in uploaded) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(raw);
          final Webtoon w = Webtoon.fromJson(decoded);
          all.add(w);
        } catch (_) {}
      }
    } catch (_) {}

    setState(() {
      _trendingWebtoons = all;

      _romanceWebtoons = all
          .where((w) => w.genre.toLowerCase() == 'romance')
          .toList();

      _fantasyWebtoons = all
          .where((w) => w.genre.toLowerCase() == 'fantasy')
          .toList();

      _isLoading = false;
    });
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
                      _loadWebtoons();
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
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadScreen(
                onWebtoonAdded: (map) {
                  _loadWebtoons();
                },
              ),
            ),
          );
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kSoftPink))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildWebtoonList('Trending Hari Ini', _trendingWebtoons),
                  _buildWebtoonList('Genre Romance', _romanceWebtoons),
                  _buildWebtoonList('Genre Fantasy', _fantasyWebtoons),
                ],
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
                            width: 150,
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
