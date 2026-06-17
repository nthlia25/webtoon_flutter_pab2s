import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/screens/detail_screen.dart';
import 'package:webtoon_flutter_pab2/theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Webtoon> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // Mendengarkan setiap ada perubahan ketikan di kolom pencarian
    _searchController.addListener(_searchWebtoons);
  }

  // Fungsi pencarian data lokal secara real-time dari webtoon yang sudah diupload
  void _searchWebtoons() async {
    final query = _searchController.text.toLowerCase();

    List<Webtoon> all = [];

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

    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      // Menyaring webtoons yang judulnya mengandung teks dari kolom pencarian
      _searchResults = all.where((webtoon) {
        return webtoon.title.toLowerCase().contains(query);
      }).toList();
    });
  }

  Widget _buildCoverImage(
    String image, {
    double width = 50,
    double height = 50,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Cari Webtoon',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Kotak Kolom Pencarian (Search Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300, width: 1.0),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan judul webtoon...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  // Tombol 'X' untuk menghapus teks, hanya muncul jika ada teks tertulis
                  Visibility(
                    visible: _searchController.text.isNotEmpty,
                    child: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16.0),

            // 2. Tampilan Hasil Pencarian
            Expanded(
              child: _searchResults.isEmpty && _searchController.text.isNotEmpty
                  ? _buildNotFoundState() // Jika tidak ketemu
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final Webtoon webtoon = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(6),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _buildCoverImage(
                                webtoon.image,
                                width: 50,
                                height: 50,
                              ),
                            ),
                            title: Text(
                              webtoon.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              webtoon.genre,
                              style: const TextStyle(
                                color: kSoftPink,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DetailScreen(webtoon: webtoon),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Tampilan jika komik yang dicari tidak ditemukan
  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Judul tidak ditemukan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba periksa kembali kata kunci Anda.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
