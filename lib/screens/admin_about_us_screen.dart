import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/memory.dart';
import '../providers/about_us_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/status_dialog.dart';

class AdminAboutUsScreen extends StatefulWidget {
  final Memory? memory;
  const AdminAboutUsScreen({super.key, this.memory});

  @override
  State<AdminAboutUsScreen> createState() => _AdminAboutUsScreenState();
}

class _AdminAboutUsScreenState extends State<AdminAboutUsScreen> {
  late TextEditingController _noteController;
  final List<File> _selectedFiles = [];
  final List<String> _fileTypes = [];
  final List<String> _existingUrls = [];
  final List<String> _existingTypes = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.memory?.note ?? '');
    if (widget.memory != null) {
      _existingUrls.addAll(widget.memory!.mediaUrls);
      _existingTypes.addAll(widget.memory!.mediaTypes);
    }
  }

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
        title: Text(widget.memory == null ? 'ADD NEW MEMORY' : 'EDIT MEMORY', style: GoogleFonts.bebasNeue(color: Colors.white)),
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
            if (_existingUrls.isNotEmpty) ...[
              const SizedBox(height: 30),
              Text('EXISTING MEDIA', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 18)),
              const SizedBox(height: 15),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingUrls.length,
                  itemBuilder: (context, i) {
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                            image: _existingTypes[i] == 'image' 
                              ? DecorationImage(image: NetworkImage(_existingUrls[i]), fit: BoxFit.cover)
                              : null,
                          ),
                          child: _existingTypes[i] == 'video'
                            ? const Center(child: Icon(Icons.videocam, color: Colors.tealAccent))
                            : null,
                        ),
                        Positioned(
                          right: 10,
                          top: 5,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _existingUrls.removeAt(i);
                              _existingTypes.removeAt(i);
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 10),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 30),
            Text('ADD NEW MEDIA', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 18)),
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
                  if (_noteController.text.isEmpty && _selectedFiles.isEmpty && _existingUrls.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a note or some media')));
                    return;
                  }

                  String? error;
                  if (widget.memory == null) {
                    error = await aboutUs.addMemory(
                      note: _noteController.text,
                      files: _selectedFiles,
                      types: _fileTypes,
                      adminName: auth.currentUser?.name ?? 'Admin',
                    );
                  } else {
                    error = await aboutUs.updateMemory(
                      id: widget.memory!.id!,
                      note: _noteController.text,
                      existingUrls: _existingUrls,
                      existingTypes: _existingTypes,
                      newFiles: _selectedFiles,
                      newTypes: _fileTypes,
                      adminName: auth.currentUser?.name ?? 'Admin',
                    );
                  }
                  
                  if (mounted) {
                    if (error == null) {
                      StatusDialog.show(context, title: "SUCCESS", message: widget.memory == null ? "Memory hung on the wall!" : "Memory updated!", isSuccess: true);
                      Future.delayed(const Duration(seconds: 1), () {
                        if (mounted) Navigator.pop(context);
                      });
                    } else {
                      StatusDialog.show(context, title: "UPLOAD ERROR", message: error, isSuccess: false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: aboutUs.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(widget.memory == null ? 'HANG ON THE WALL' : 'UPDATE MEMORY', style: GoogleFonts.bebasNeue(color: const Color(0xFF051970), fontSize: 20)),
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
