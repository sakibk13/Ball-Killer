import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/status_dialog.dart';

class AdminPaymentSettingsScreen extends StatefulWidget {
  const AdminPaymentSettingsScreen({super.key});

  @override
  State<AdminPaymentSettingsScreen> createState() => _AdminPaymentSettingsScreenState();
}

class _AdminPaymentSettingsScreenState extends State<AdminPaymentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bkash1NameCtrl;
  late TextEditingController _bkash1NumberCtrl;
  String _bkash1QrSource = 'assets/1.jpeg';

  late TextEditingController _bkash2NameCtrl;
  late TextEditingController _bkash2NumberCtrl;
  String _bkash2QrSource = 'assets/2.jpeg';

  late TextEditingController _bankNameCtrl;
  late TextEditingController _bankAccNameCtrl;
  late TextEditingController _bankAccNumberCtrl;
  late TextEditingController _routingNumberCtrl;
  late TextEditingController _bankBranchCtrl;

  late TextEditingController _noticeTextCtrl;
  late TextEditingController _refNoteCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final room = Provider.of<RoomProvider>(context, listen: false).currentRoom;

    _bkash1NameCtrl = TextEditingController(text: room.bkash1Name);
    _bkash1NumberCtrl = TextEditingController(text: room.bkash1Number);
    _bkash1QrSource = room.bkash1Qr;

    _bkash2NameCtrl = TextEditingController(text: room.bkash2Name);
    _bkash2NumberCtrl = TextEditingController(text: room.bkash2Number);
    _bkash2QrSource = room.bkash2Qr;

    _bankNameCtrl = TextEditingController(text: room.bankName);
    _bankAccNameCtrl = TextEditingController(text: room.bankAccountName);
    _bankAccNumberCtrl = TextEditingController(text: room.bankAccountNumber);
    _routingNumberCtrl = TextEditingController(text: room.routingNumber);
    _bankBranchCtrl = TextEditingController(text: room.bankBranch);

    _noticeTextCtrl = TextEditingController(text: room.noticeText);
    _refNoteCtrl = TextEditingController(text: room.referenceNote);
  }

  @override
  void dispose() {
    _bkash1NameCtrl.dispose();
    _bkash1NumberCtrl.dispose();
    _bkash2NameCtrl.dispose();
    _bkash2NumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccNameCtrl.dispose();
    _bankAccNumberCtrl.dispose();
    _routingNumberCtrl.dispose();
    _bankBranchCtrl.dispose();
    _noticeTextCtrl.dispose();
    _refNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickQrCode(int qrIndex) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        if (qrIndex == 1) {
          _bkash1QrSource = base64String;
        } else {
          _bkash2QrSource = base64String;
        }
      });
    }
  }

  void _resetToDefaultQrs() {
    setState(() {
      _bkash1QrSource = 'assets/1.jpeg';
      _bkash2QrSource = 'assets/2.jpeg';
      _bkash1NameCtrl.text = 'bKash Personal';
      _bkash1NumberCtrl.text = '01724293453';
      _bkash2NameCtrl.text = 'bKash Personal';
      _bkash2NumberCtrl.text = '01832465446';
      _bankNameCtrl.text = 'BRAC Bank PLC';
      _bankAccNameCtrl.text = 'SAKIB KHAN';
      _bankAccNumberCtrl.text = '1062020640001';
      _routingNumberCtrl.text = '060261726';
      _bankBranchCtrl.text = 'Gulshan Principal Branch';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to SPK13 default bKash and Bank details.')),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    final room = roomProv.currentRoom;

    final success = await roomProv.updateRoomPaymentDetails(
      roomId: room.id,
      bkash1Number: _bkash1NumberCtrl.text.trim(),
      bkash1Name: _bkash1NameCtrl.text.trim(),
      bkash1Qr: _bkash1QrSource,
      bkash2Number: _bkash2NumberCtrl.text.trim(),
      bkash2Name: _bkash2NameCtrl.text.trim(),
      bkash2Qr: _bkash2QrSource,
      bankName: _bankNameCtrl.text.trim(),
      bankAccountName: _bankAccNameCtrl.text.trim(),
      bankAccountNumber: _bankAccNumberCtrl.text.trim(),
      routingNumber: _routingNumberCtrl.text.trim(),
      bankBranch: _bankBranchCtrl.text.trim(),
      bankLogo: 'assets/brack_bank.jpg',
      noticeText: _noticeTextCtrl.text.trim(),
      referenceNote: _refNoteCtrl.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        StatusDialog.show(
          context,
          title: "SETTINGS SAVED",
          message: "Payment configuration updated for Room ${room.code}!",
          isSuccess: true,
        );
      } else {
        StatusDialog.show(
          context,
          title: "SAVE FAILED",
          message: "Could not update payment configuration.",
          isSuccess: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = Provider.of<RoomProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final roomCode = roomProv.currentRoomCode;

    if (!authProv.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF051970),
        appBar: AppBar(title: const Text('Access Denied'), backgroundColor: const Color(0xFF020C3B)),
        body: const Center(child: Text('Only Admins can access Payment Settings', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text(
          'PAYMENT SETTINGS • ROOM $roomCode',
          style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restore_rounded, color: Colors.tealAccent, size: 16),
            label: Text('RESET SPK13', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 12)),
            onPressed: _resetToDefaultQrs,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: bKash 1
                  _buildSectionCard(
                    title: 'BKASH OPTION 1 (PRIMARY)',
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFFE91E63),
                    children: [
                      _buildTextField(_bkash1NameCtrl, 'Label / Title', 'e.g. bKash Personal (Sakib)'),
                      const SizedBox(height: 12),
                      _buildTextField(_bkash1NumberCtrl, 'bKash Mobile Number', 'e.g. 01724293453', isPhone: true),
                      const SizedBox(height: 14),
                      _buildQrPickerWidget(
                        label: 'QR Code for Option 1 (01724293453)',
                        qrSource: _bkash1QrSource,
                        onPick: () => _pickQrCode(1),
                        onReset: () => setState(() => _bkash1QrSource = 'assets/1.jpeg'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Section 2: bKash 2
                  _buildSectionCard(
                    title: 'BKASH OPTION 2 (SECONDARY)',
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    children: [
                      _buildTextField(_bkash2NameCtrl, 'Label / Title', 'e.g. bKash Personal (Admin)'),
                      const SizedBox(height: 12),
                      _buildTextField(_bkash2NumberCtrl, 'bKash Mobile Number', 'e.g. 01832465446', isPhone: true),
                      const SizedBox(height: 14),
                      _buildQrPickerWidget(
                        label: 'QR Code for Option 2 (01832465446)',
                        qrSource: _bkash2QrSource,
                        onPick: () => _pickQrCode(2),
                        onReset: () => setState(() => _bkash2QrSource = 'assets/2.jpeg'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Section 3: Bank Transfer Details
                  _buildSectionCard(
                    title: 'BANK ACCOUNT DETAILS',
                    icon: Icons.account_balance_rounded,
                    iconColor: Colors.blueAccent,
                    children: [
                      _buildTextField(_bankNameCtrl, 'Bank Name', 'e.g. BRAC Bank PLC'),
                      const SizedBox(height: 12),
                      _buildTextField(_bankAccNameCtrl, 'Account Holder Name', 'e.g. SAKIB KHAN'),
                      const SizedBox(height: 12),
                      _buildTextField(_bankAccNumberCtrl, 'Account Number', 'e.g. 1062020640001'),
                      const SizedBox(height: 12),
                      _buildTextField(_routingNumberCtrl, 'Routing Number', 'e.g. 060261726'),
                      const SizedBox(height: 12),
                      _buildTextField(_bankBranchCtrl, 'Branch', 'e.g. Principal Branch'),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Section 4: Notice & Reference Instructions
                  _buildSectionCard(
                    title: 'CLUB NOTICE & REFERENCE INSTRUCTIONS',
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.amberAccent,
                    children: [
                      _buildTextField(_noticeTextCtrl, 'General Notice Note', 'Message to players about clearing dues', maxLines: 2),
                      const SizedBox(height: 12),
                      _buildTextField(_refNoteCtrl, 'Reference/Remark Requirement', 'Instruction to write player name in reference', maxLines: 2),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF020C3B), strokeWidth: 2))
                          : const Icon(Icons.save_rounded, color: Color(0xFF020C3B)),
                      label: Text(
                        _isSaving ? 'SAVING...' : 'SAVE CONFIGURATION FOR ROOM $roomCode',
                        style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B), fontSize: 16, letterSpacing: 1),
                      ),
                      onPressed: _isSaving ? null : _saveSettings,
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 15, letterSpacing: 1),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isPhone = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.bebasNeue(color: Colors.white54, fontSize: 13, letterSpacing: 0.8),
        hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 11),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.tealAccent)),
      ),
      validator: (val) => val == null || val.trim().isEmpty ? 'Required field' : null,
    );
  }

  Widget _buildQrPickerWidget({
    required String label,
    required String qrSource,
    required VoidCallback onPick,
    required VoidCallback onReset,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildQrPreview(qrSource),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 14, color: Color(0xFF020C3B)),
                      label: Text('UPLOAD QR', style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B), fontSize: 11)),
                      onPressed: onPick,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onReset,
                      child: Text('RESET DEFAULT', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPreview(String source) {
    if (source.startsWith('data:image') || (!source.startsWith('assets') && source.length > 100)) {
      try {
        final pure = source.contains(',') ? source.split(',').last : source;
        return Image.memory(base64Decode(pure), fit: BoxFit.contain);
      } catch (_) {}
    }
    return Image.asset(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.qr_code, color: Colors.black)),
    );
  }
}
