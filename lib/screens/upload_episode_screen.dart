import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadEpisodeScreen extends StatefulWidget {
  final String webtoonId;
  const UploadEpisodeScreen({super.key, required this.webtoonId});

  @override
  State<UploadEpisodeScreen> createState() => _UploadEpisodeScreenState();
}

class _UploadEpisodeScreenState extends State<UploadEpisodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _episodeNumberController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = false;
  List<Uint8List> _imagesBytes = []; 

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        List<Uint8List> bytesList = [];
        for (var file in pickedFiles) {
          bytesList.add(await file.readAsBytes());
        }
        setState(() {
          _imagesBytes.addAll(bytesList);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _submitEpisode() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagesBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal 1 gambar komik!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> base64Images = _imagesBytes.map((img) => base64Encode(img)).toList();
      final int epNumber = int.parse(_episodeNumberController.text.trim());
      
      final episodeData = {
        'episodeNumber': epNumber,
        'title': _titleController.text.trim(),
        'images': base64Images,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('webtoons')
          .doc(widget.webtoonId)
          .collection('episodes')
          .doc('ep_$epNumber')
          .set(episodeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Episode $epNumber berhasil diupload!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Episode Baru'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _episodeNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor Episode (misal: 1)', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Judul Episode', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Tidak boleh kosong' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pilih Panel Gambar Komik'),
              ),
              const SizedBox(height: 16),
              if (_imagesBytes.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagesBytes.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Image.memory(_imagesBytes[index], width: 90, height: 120, fit: BoxFit.cover),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEpisode,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Upload Episode', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}