import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  String _searchQuery = "";

  Widget _buildCoverImage(String image, {double width = 50, double height = 50}) {
    if (image.isEmpty) return Container(width: width, height: height, color: Colors.grey[200]);

    final lower = image.toLowerCase();
    final bool isAsset = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');

    if (isAsset) {
      return Image.asset('assets/images/$image', width: width, height: height, fit: BoxFit.cover);
    }

    try {
      final bytes = base64Decode(image);
      return Image.memory(bytes, width: width, height: height, fit: BoxFit.cover);
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
        title: const Text('Cari Webtoon', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Kotak Kolom Pencarian
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
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Masukkan judul webtoon...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _searchController.text.isNotEmpty,
                    child: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = "";
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // 2. Tampilan Hasil Pencarian Real-Time dari Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('webtoons').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kSoftPink));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildNotFoundState();
                  }

                  // Melakukan filtering data webtoons jika judul mengandung query
                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    final title = doc['title'].toString().toLowerCase();
                    return _searchQuery.isEmpty ? false : title.contains(_searchQuery);
                  }).toList();

                  // Jika user belum mengetik apapun
                  if (_searchQuery.isEmpty) {
                    return Center(child: Text("Ketik judul komik untuk mencari.", style: TextStyle(color: Colors.grey.shade500)));
                  }

                  // Jika data tidak ditemukan
                  if (filteredDocs.isEmpty) {
                    return _buildNotFoundState();
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final docData = filteredDocs[index].data() as Map<String, dynamic>;
                      final webtoon = Webtoon.fromJson(docData);

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
                            child: _buildCoverImage(webtoon.image, width: 50, height: 50),
                          ),
                          title: Text(
                            webtoon.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            webtoon.genre,
                            style: const TextStyle(color: kSoftPink, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailScreen(webtoon: webtoon),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Judul tidak ditemukan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
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