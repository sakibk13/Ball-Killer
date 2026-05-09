import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/about_us_provider.dart';
import '../providers/auth_provider.dart';
import '../models/memory.dart';
import 'admin_about_us_screen.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AboutUsProvider>(context, listen: false).fetchMemories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final aboutUs = Provider.of<AboutUsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('OUR MEMORIES', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_a_photo, color: Colors.tealAccent),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAboutUsScreen())),
            ),
        ],
      ),
      body: aboutUs.isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
        : aboutUs.memories.isEmpty
          ? _buildEmptyState()
          : _buildMemoriesWall(aboutUs.memories),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.1), size: 100),
          const SizedBox(height: 20),
          Text('NO MEMORIES YET', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 24)),
          Text('Admin will hang some memories here soon!', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMemoriesWall(List<Memory> memories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
      child: Column(
        children: memories.map((m) => _buildHangingMemory(m)).toList(),
      ),
    );
  }

  Widget _buildHangingMemory(Memory m) {
    final double rotation = (Random().nextDouble() * 0.04) - 0.02;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth > 600 ? 450 : screenWidth * 0.92;
    
    return Center(
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: cardWidth,
          margin: const EdgeInsets.only(bottom: 50),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Main Polaroid Card
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(8, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 1,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Multi-Image Display
                    if (m.mediaUrls.isNotEmpty)
                      _buildImageGrid(m.mediaUrls),
                    
                    const SizedBox(height: 20),
                    
                    // Note (Kalam font - cleaner handwritten style)
                    Text(
                      m.note,
                      style: GoogleFonts.kalam(
                        color: const Color(0xFF2C3E50), 
                        fontSize: 20, 
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // Footer Detail
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CAPTURED BY ${m.adminName.toUpperCase()}', 
                              style: GoogleFonts.bebasNeue(color: Colors.grey[400], fontSize: 10, letterSpacing: 1.5)
                            ),
                            Text(
                              DateFormat('MMMM dd, yyyy').format(m.date).toUpperCase(), 
                              style: GoogleFonts.bebasNeue(color: Colors.grey[300], fontSize: 9, letterSpacing: 1)
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showMemoryDetail(m),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF051970).withOpacity(0.05), 
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: Icon(Icons.fullscreen_rounded, color: const Color(0xFF051970).withOpacity(0.3), size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 3D Red Pin
              Positioned(
                top: -15,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(2, 2)),
                    ],
                    gradient: RadialGradient(
                      colors: [Colors.red[400]!, Colors.red[900]!],
                      center: const Alignment(-0.3, -0.3),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> urls) {
    if (urls.length == 1) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[100]!, width: 1),
        ),
        child: Image.memory(base64Decode(urls.first), fit: BoxFit.cover, width: double.infinity),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: urls.length,
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[100]!, width: 1),
          ),
          child: Image.memory(base64Decode(urls[i]), fit: BoxFit.cover),
        );
      },
    );
  }

  void _showMemoryDetail(Memory m) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF020C3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('MEMORY DETAIL', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 24)),
              const SizedBox(height: 15),
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: m.mediaUrls.length,
                  itemBuilder: (context, i) {
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: DecorationImage(image: MemoryImage(base64Decode(m.mediaUrls[i])), fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
              Text(m.note, style: GoogleFonts.poppins(color: Colors.white70)),
              const SizedBox(height: 20),
              if (Provider.of<AuthProvider>(context, listen: false).isAdmin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAboutUsScreen(memory: m)));
                      },
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      label: const Text('EDIT', style: TextStyle(color: Colors.blueAccent)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Provider.of<AboutUsProvider>(context, listen: false).deleteMemory(m.id!);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      label: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
