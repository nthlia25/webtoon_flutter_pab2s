import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webtoon_flutter_pab2/model/webtoon.dart';
import 'package:webtoon_flutter_pab2/screens/detail_screen.dart';
import 'package:webtoon_flutter_pab2/theme.dart';

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  Widget _buildCoverImage(String image, {double width = 60, double height = 70}) {
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
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Webtoon Favorit'), backgroundColor: Colors.white, foregroundColor: Colors.black),
        body: const Center(child: Text("Silakan login terlebih dahulu untuk melihat favorit Anda.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Webtoon Favorit', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kSoftPink));
          }
          
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return _buildEmptyState();
          }

          // Mengambil array "favorites" dari akun user di Firestore
          List<dynamic> favoriteIds = userSnapshot.data!.get('favorites') ?? [];

          if (favoriteIds.isEmpty) return _buildEmptyState();

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('webtoons').get(),
            builder: (context, webtoonsSnapshot) {
              if (webtoonsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kSoftPink));
              }
              if (!webtoonsSnapshot.hasData) return _buildEmptyState();

              final favoriteWebtoons = webtoonsSnapshot.data!.docs
                  .where((doc) => favoriteIds.contains(doc.id))
                  .map((doc) => Webtoon.fromJson(doc.data() as Map<String, dynamic>))
                  .toList();

              if (favoriteWebtoons.isEmpty) return _buildEmptyState();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: favoriteWebtoons.length,
                itemBuilder: (context, index) {
                  final webtoon = favoriteWebtoons[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                        child: _buildCoverImage(webtoon.image, height: 70, width: 60),
                      ),
                      title: Text(
                        webtoon.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            webtoon.genre,
                            style: const TextStyle(color: kSoftPink, fontWeight: FontWeight.w500, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                webtoon.rating.toString(),
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DetailScreen(webtoon: webtoon)),
                        );
                      },
                    ),
                  );
                },
              );
            },
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
          Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Belum ada komik favorit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
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