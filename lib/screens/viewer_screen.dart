import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

List<String> buildViewerPanelSources({
  required String? coverImage,
  required String title,
  required String episodeTitle,
}) {
  final fallbackSources = [
    'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=900&q=80',
  ];

  if (coverImage != null && coverImage.isNotEmpty) {
    final normalized = coverImage.trim();
    final isLikelyAsset =
        normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.webp');

    if (isLikelyAsset) {
      return List.generate(5, (_) => normalized);
    }

    try {
      base64Decode(normalized);
      return List.generate(5, (_) => normalized);
    } catch (_) {}
  }

  final seed = (title + episodeTitle).hashCode.abs();
  return List.generate(
    5,
    (index) => fallbackSources[(seed + index) % fallbackSources.length],
  );
}

class ViewerScreen extends StatefulWidget {
  final String title;
  final String episodeTitle;
  final List<String> episodes;
  final int initialEpisodeIndex;
  final String? coverImage;

  const ViewerScreen({
    super.key,
    required this.title,
    required this.episodeTitle,
    required this.episodes,
    required this.initialEpisodeIndex,
    this.coverImage,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final List<String> _comicPanels;
  late final ScrollController _scrollController;
  int _currentPanel = 1;
  bool _isSavingLocation = false;
  String? _savedLatitude;
  String? _savedLongitude;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateCurrentPanel);
    _comicPanels = _buildComicPanels();
    _saveHistory();
    _loadSavedLocation();
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
    return buildViewerPanelSources(
      coverImage: widget.coverImage,
      title: widget.title,
      episodeTitle: widget.episodeTitle,
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
        'latitude': _savedLatitude,
        'longitude': _savedLongitude,
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

  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final historyKey = '${uid}_readHistory';
      final List<String> raw = prefs.getStringList(historyKey) ?? [];

      for (final entry in raw) {
        try {
          final decoded = jsonDecode(entry);
          if (decoded is Map<String, dynamic> &&
              decoded['title'] == widget.title &&
              decoded['episode'] == widget.episodeTitle) {
            final latitude = decoded['latitude']?.toString();
            final longitude = decoded['longitude']?.toString();
            if (latitude != null && longitude != null) {
              setState(() {
                _savedLatitude = latitude;
                _savedLongitude = longitude;
              });
              return;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _updateReadingLocation() async {
    if (_isSavingLocation) return;

    setState(() => _isSavingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aktifkan layanan GPS untuk mengambil lokasi.'),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak, tidak bisa mengambil posisi.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _savedLatitude = position.latitude.toString();
        _savedLongitude = position.longitude.toString();
      });

      await _saveHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi bacaan berhasil diperbarui.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil lokasi saat ini.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingLocation = false);
      }
    }
  }

  Future<void> _openSavedLocationInMaps() async {
    if (_savedLatitude == null || _savedLongitude == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_savedLatitude},${_savedLongitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
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
          coverImage: widget.coverImage,
        ),
      ),
    );
  }

  Widget _buildPanelImage(String source) {
    final lower = source.toLowerCase();
    final isAsset =
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');

    if (isAsset) {
      return Image.asset(
        'assets/images/$source',
        fit: BoxFit.fitWidth,
        width: double.infinity,
      );
    }

    try {
      final bytes = base64Decode(source);
      return Image.memory(
        bytes,
        fit: BoxFit.fitWidth,
        width: double.infinity,
      );
    } catch (_) {
      if (source.startsWith('http://') || source.startsWith('https://')) {
        return Image.network(
          source,
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
        );
      }

      return Container(
        height: 280,
        color: Colors.grey[200],
        child: const Center(
          child: Text('Gambar tidak tersedia'),
        ),
      );
    }
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
          if (_savedLatitude != null && _savedLongitude != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFFFFF7FB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFEC4899),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lokasi terakhir: ${_savedLatitude!.substring(0, 8)}, ${_savedLongitude!.substring(0, 8)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openSavedLocationInMaps,
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('Maps'),
                      ),
                    ],
                  ),
                ),
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
                        child: _buildPanelImage(_comicPanels[index]),
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
                      onPressed: _isSavingLocation
                          ? null
                          : _updateReadingLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Lokasi Saya'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
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
