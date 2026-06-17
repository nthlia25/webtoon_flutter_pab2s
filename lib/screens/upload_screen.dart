import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final uuid = Uuid();

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
  // Removed unused _selectedImage field; using _imageBytes and _imageFileName instead.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<String> _saveImageLocally(Uint8List imageBytes) async {
    try {
      // Encode bytes to base64 untuk penyimpanan di SharedPreferences
      return base64Encode(imageBytes);
    } catch (e) {
      throw Exception('Error saving image: $e');
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_imageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih gambar webtoon terlebih dahulu')),
        );
        return;
      }

      if (_selectedGenre == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih genre terlebih dahulu')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Save image as base64
        final imageBase64 = await _saveImageLocally(_imageBytes!);

        // Create webtoon object
        final newWebtoon = {
          'id': uuid.v4(),
          'title': _titleController.text,
          'genre': _selectedGenre,
          'rating': _ratingController.text.isEmpty
              ? '0.0'
              : _ratingController.text,
          'image': imageBase64,
          'imageFileName': _imageFileName,
          'synopsis': _synopsisController.text,
          'episodes': [],
          'uploadedAt': DateTime.now().toIso8601String(),
        };

        // Save to SharedPreferences per logged-in user
        final prefs = await SharedPreferences.getInstance();
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
        final uploadedKey = '${uid}_uploaded_webtoons';
        List<String> webtoonsList = prefs.getStringList(uploadedKey) ?? [];
        webtoonsList.add(jsonEncode(newWebtoon));
        await prefs.setStringList(uploadedKey, webtoonsList);

        // Optional fallback key for older versions / non-authenticated use
        final legacyList = prefs.getStringList('uploaded_webtoons') ?? [];
        if (!legacyList.contains(jsonEncode(newWebtoon))) {
          legacyList.add(jsonEncode(newWebtoon));
          await prefs.setStringList('uploaded_webtoons', legacyList);
        }

        // Call callback
        widget.onWebtoonAdded(newWebtoon);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Webtoon berhasil ditambahkan!'),
              backgroundColor: Colors.pink,
            ),
          );

          // Clear form
          _titleController.clear();
          _synopsisController.clear();
          _ratingController.clear();
          setState(() {
            _imageBytes = null;
            _imageFileName = null;
            _selectedGenre = null;
          });
          // Close upload screen and return to previous screen
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
                // Image Picker Section
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
                              const Icon(
                                Icons.image_search,
                                size: 48,
                                color: Colors.pink,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap untuk memilih gambar',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title Field
                Text(
                  'Judul Webtoon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan judul webtoon',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.title, color: Colors.pink),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Judul tidak boleh kosong';
                    }
                    if (value.length < 3) {
                      return 'Judul minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Genre Dropdown
                Text(
                  'Genre',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedGenre,
                  decoration: InputDecoration(
                    hintText: 'Pilih genre',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.category, color: Colors.pink),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: genres.map((String genre) {
                    return DropdownMenuItem<String>(
                      value: genre,
                      child: Text(genre),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGenre = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Genre harus dipilih';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Rating Field (Optional)
                Text(
                  'Rating (Opsional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ratingController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Masukkan rating (0.0 - 10.0)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.star, color: Colors.pink),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final rating = double.tryParse(value);
                      if (rating == null || rating < 0 || rating > 10) {
                        return 'Rating harus antara 0.0 - 10.0';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Synopsis Field
                Text(
                  'Sinopsis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _synopsisController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Masukkan sinopsis webtoon',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sinopsis tidak boleh kosong';
                    }
                    if (value.length < 10) {
                      return 'Sinopsis minimal 10 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Upload Webtoon',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
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
