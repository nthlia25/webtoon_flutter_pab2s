import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewerScreen extends StatefulWidget {
  final String title;
  final String episodeTitle;
  final List<String> episodes;
  final int initialEpisodeIndex;

  const ViewerScreen({
    super.key,
    required this.title,
    required this.episodeTitle,
    required this.episodes,
    required this.initialEpisodeIndex,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final List<String> _comicPanels;
  late final ScrollController _scrollController;
  int _currentPanel = 1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateCurrentPanel);
    _comicPanels = _buildComicPanels();
    _saveHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateCurrentPanel);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateCurrentPanel() {
    final estimatedIndex = (_scrollController.offset / 420).round();
    final nextPanel = (estimatedIndex + 1).clamp(1, _comicPanels.length);
    if (nextPanel != _currentPanel) {
      setState(() => _currentPanel = nextPanel);
    }
  }

  List<String> _buildComicPanels() {
    final panelImages = [
      'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80',
    ];

    final seed = (widget.title + widget.episodeTitle).hashCode.abs();
    return List.generate(
      5,
      (index) => panelImages[(seed + index) % panelImages.length],
    );
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final historyKey = '${uid}_readHistory';
      final List<String> raw = prefs.getStringList(historyKey) ?? [];

      final timestamp = DateTime.now().toIso8601String();
      final entry = jsonEncode({
        'title': widget.title,
        'episode': widget.episodeTitle,
        'timestamp': timestamp,
      });

      raw.removeWhere((e) {
        try {
          final decoded = jsonDecode(e);
          if (decoded is Map<String, dynamic>) {
            return decoded['title'] == widget.title &&
                decoded['episode'] == widget.episodeTitle;
          }
        } catch (_) {}

        final splitData = e.split('|');
        return splitData.length >= 2 &&
            splitData[0] == widget.title &&
            splitData[1] == widget.episodeTitle;
      });

      raw.insert(0, entry);
      if (raw.length > 200) raw.removeRange(200, raw.length);

      await prefs.setStringList(historyKey, raw);
    } catch (_) {}
  }

  Future<void> _navigateToEpisode(int direction) async {
    final nextIndex = widget.initialEpisodeIndex + direction;
    if (nextIndex < 0 || nextIndex >= widget.episodes.length) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ViewerScreen(
          title: widget.title,
          episodeTitle: widget.episodes[nextIndex],
          episodes: widget.episodes,
          initialEpisodeIndex: nextIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoPrev = widget.initialEpisodeIndex > 0;
    final canGoNext = widget.initialEpisodeIndex < widget.episodes.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F1F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.episodeTitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.more_horiz, color: Colors.black54),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.title} • ${widget.episodeTitle}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_currentPanel/${_comicPanels.length}',
                    style: const TextStyle(
                      color: Color(0xFFEC4899),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              itemCount: _comicPanels.length,
              itemBuilder: (context, index) {
                final panelNumber = index + 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: Text(
                          'Panel $panelNumber',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(18),
                        ),
                        child: Image.network(
                          _comicPanels[index],
                          fit: BoxFit.fitWidth,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              height: 300,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFFEC4899),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 280,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Text('Gambar tidak tersedia'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFFF6F1F5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canGoPrev ? () => _navigateToEpisode(-1) : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                      label: const Text('Sebelumnya'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canGoNext ? () => _navigateToEpisode(1) : null,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Berikutnya'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
