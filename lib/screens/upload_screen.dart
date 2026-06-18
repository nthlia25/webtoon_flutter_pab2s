import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

// PASTIKAN IMPORT FILE INI SESUAI:
import 'upload_episode_screen.dart'; 

const _uuidGenerator = Uuid();

class UploadScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onWebtoonAdded;

  const UploadScreen({super.key, required this.onWebtoonAdded});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _synopsisController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedGenre;
  bool _isLoading = false;

  final List<String> genres = [
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

  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _isGettingLocation = false;
  String? _uploadLatitude;
  String? _uploadLongitude;

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFileName = pickedFile.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String> _encodeImageToBase64(Uint8List imageBytes) async {
    try {
      return base64Encode(imageBytes);
    } catch (e) {
      throw Exception('Error encoding image: $e');
    }
  }

  Future<void> _getUploadLocation() async {
    if (_isGettingLocation) return;

    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aktifkan layanan GPS untuk mengambil lokasi upload.'),
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
              content: Text('Izin lokasi ditolak.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _uploadLatitude = position.latitude.toString();
        _uploadLongitude = position.longitude.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi upload berhasil didapatkan.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil lokasi upload.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _openUploadLocationInMaps() async {
    if (_uploadLatitude == null || _uploadLongitude == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_uploadLatitude,$_uploadLongitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih gambar webtoon terlebih dahulu')));
      return;
    }

    if (_selectedGenre == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih genre terlebih dahulu')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Silakan login terlebih dahulu');
      }

      final imageBase64 = await _encodeImageToBase64(_imageBytes!);
      final webtoonId = _uuidGenerator.v4();

      final data = {
        'id': webtoonId,
        'userId': user.uid,
        'title': _titleController.text.trim(),
        'genre': _selectedGenre,
        'rating': _ratingController.text.isEmpty ? 0.0 : double.parse(_ratingController.text.trim()),
        'image': imageBase64,
        'imageFileName': _imageFileName,
        'synopsis': _synopsisController.text.trim(),
        'episodes': <String>[],
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadLatitude': _uploadLatitude == null ? null : double.parse(_uploadLatitude!),
        'uploadLongitude': _uploadLongitude == null ? null : double.parse(_uploadLongitude!)
      };

      await FirebaseFirestore.instance.collection('webtoons').doc(webtoonId).set(data);

      widget.onWebtoonAdded(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data Webtoon tersimpan, silakan unggah Episode 1!'),
          backgroundColor: Colors.green,
        ));

        // Pindah ke halaman Upload Episode dengan membawa webtoonId
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UploadEpisodeScreen(webtoonId: webtoonId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Webtoon Baru'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.pink, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[100],
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image_search, size: 48, color: Colors.pink),
                              const SizedBox(height: 12),
                              Text('Tap untuk memilih gambar sampul', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Judul Webtoon', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan judul webtoon',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.title, color: Colors.pink),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Judul tidak boleh kosong';
                    if (value.length < 3) return 'Judul minimal 3 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text('Genre', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGenre,
                  decoration: InputDecoration(
                    hintText: 'Pilih genre',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.category, color: Colors.pink),
                  ),
                  items: genres.map((genre) => DropdownMenuItem(value: genre, child: Text(genre))).toList(),
                  onChanged: (val) => setState(() => _selectedGenre = val),
                  validator: (value) => (value == null || value.isEmpty) ? 'Genre harus dipilih' : null,
                ),
                const SizedBox(height: 16),
                Text('Rating (Opsional)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ratingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Masukkan rating (0.0 - 10.0)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.star, color: Colors.pink),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final rating = double.tryParse(value);
                      if (rating == null || rating < 0 || rating > 10) return 'Rating harus antara 0.0 - 10.0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text('Sinopsis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _synopsisController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Masukkan sinopsis webtoon',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Sinopsis tidak boleh kosong';
                    if (value.length < 10) return 'Sinopsis minimal 10 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lokasi Upload',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_uploadLatitude != null && _uploadLongitude != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.pink,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lat: $_uploadLatitude\nLng: $_uploadLongitude',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _openUploadLocationInMaps,
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text('Maps'),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Belum ada lokasi yang diambil.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isGettingLocation ? null : _getUploadLocation,
                            icon: const Icon(Icons.my_location),
                            label: Text(
                              _isGettingLocation
                                  ? 'Mengambil lokasi...'
                                  : 'Ambil Lokasi Saya',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // --- PERUBAHAN TEKS TOMBOL AGAR LEBIH JELAS ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : const Text('Simpan & Lanjut Isi Episode 1', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                // ----------------------------------------------
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _synopsisController.dispose();
    _ratingController.dispose();
    super.dispose();
  }
}