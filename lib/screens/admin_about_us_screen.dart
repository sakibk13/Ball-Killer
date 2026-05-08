import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/about_us_provider.dart';
import '../providers/auth_provider.dart';

class AdminAboutUsScreen extends StatefulWidget {
  const AdminAboutUsScreen({super.key});

  @override
  State<AdminAboutUsScreen> createState() => _AdminAboutUsScreenState();
}

class _AdminAboutUsScreenState extends State<AdminAboutUsScreen> {
  final _noteController = TextEditingController();
  final List<File> _selectedFiles = [];
  final List<String> _fileTypes = [];
  final _picker = ImagePicker();

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var file in pickedFiles) {
          _selectedFiles.add(File(file.path));
          _fileTypes.add('image');
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedFiles.add(File(pickedFile.path));
        _fileTypes.add('video');
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _fileTypes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aboutUs = Provider.of<AboutUsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('ADD NEW MEMORY', style: GoogleFonts.bebasNeue(color: Colors.white)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOTE / CAPTION', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write something memorable...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 30),
            Text('ATTACH MEDIA', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 18)),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildAddButton(Icons.add_photo_alternate, 'PHOTOS', _pickImages),
                const SizedBox(width: 15),
                _buildAddButton(Icons.video_call, 'VIDEO', _pickVideo),
              ],
            ),
            const SizedBox(height: 25),
            if (_selectedFiles.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, i) {
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                            image: _fileTypes[i] == 'image' 
                              ? DecorationImage(image: FileImage(_selectedFiles[i]), fit: BoxFit.cover)
                              : null,
                          ),
                          child: _fileTypes[i] == 'video'
                            ? const Center(child: Icon(Icons.videocam, color: Colors.tealAccent))
                            : null,
                        ),
                        Positioned(
                          right: 10,
                          top: 5,
                          child: GestureDetector(
                            onTap: () => _removeFile(i),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: aboutUs.isLoading ? null : () async {
                  if (_noteController.text.isEmpty && _selectedFiles.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a note or some media')));
                    return;
                  }
                  final success = await aboutUs.addMemory(
                    note: _noteController.text,
                    files: _selectedFiles,
                    types: _fileTypes,
                    adminName: auth.currentUser?.name ?? 'Admin',
                  );
                  if (success && mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: aboutUs.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('HANG ON THE WALL', style: GoogleFonts.bebasNeue(color: const Color(0xFF051970), fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.tealAccent, size: 30),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.bebasNeue(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
