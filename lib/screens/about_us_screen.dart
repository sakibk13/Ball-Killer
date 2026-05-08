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
      child: Wrap(
        spacing: 15,
        runSpacing: 25,
        alignment: WrapAlignment.center,
        children: memories.map((m) => _buildHangingMemory(m)).toList(),
      ),
    );
  }

  Widget _buildHangingMemory(Memory m) {
    // Random rotation between -3 and 3 degrees
    final double rotation = (Random().nextDouble() * 0.1) - 0.05;
    
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.42,
        constraints: const BoxConstraints(maxWidth: 200),
        child: Column(
          children: [
            // The "string" or "clip"
            Container(
              width: 2,
              height: 20,
              color: Colors.white24,
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(4, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media Preview (Multiple photos)
                  if (m.mediaUrls.isNotEmpty)
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Stack(
                          children: [
                            Image.memory(base64Decode(m.mediaUrls.first), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                            if (m.mediaUrls.length > 1)
                              Positioned(
                                right: 5,
                                bottom: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                                  child: Text('+${m.mediaUrls.length - 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Note (Sticky note style)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(5),
                    child: Text(
                      m.note,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.caveat(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd').format(m.date), style: const TextStyle(color: Colors.black26, fontSize: 8)),
                      GestureDetector(
                        onTap: () => _showMemoryDetail(m),
                        child: const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 12),
                      ),
                      const Icon(Icons.push_pin, color: Colors.redAccent, size: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
