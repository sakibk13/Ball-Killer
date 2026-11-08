import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/auth_provider.dart';
import 'admin_payment_settings_screen.dart';

class PaymentNoticeScreen extends StatelessWidget {
  const PaymentNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roomProv = Provider.of<RoomProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final room = roomProv.currentRoom;
    final isAdmin = authProv.isAdmin;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF051970),
        appBar: AppBar(
          title: Text(
            'OFFICIAL PAYMENT NOTICE',
            style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.4, fontSize: 20),
          ),
          backgroundColor: const Color(0xFF020C3B),
          elevation: 0,
          actions: [
            if (isAdmin)
              IconButton(
                tooltip: 'Edit Payment Details',
                icon: const Icon(Icons.settings_suggest_rounded, color: Colors.tealAccent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPaymentSettingsScreen()),
                  );
                },
              ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            indicatorColor: Colors.tealAccent,
            indicatorWeight: 3,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.bebasNeue(letterSpacing: 1.2, fontSize: 14),
            tabs: const [
              Tab(text: 'bKash (QR & NUMBERS)', icon: Icon(Icons.qr_code_scanner_rounded, size: 20)),
              Tab(text: 'BANK TRANSFER', icon: Icon(Icons.account_balance_rounded, size: 20)),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              children: [
                // Room & Reference Banner
                _buildTopNoticeBanner(context, room.code, room.noticeText, room.referenceNote),

                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: bKash (2 Numbers + 2 QRs)
                      _buildBkashTab(context, room),

                      // TAB 2: Bank Transfer Details
                      _buildBankTab(context, room),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: isAdmin
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFF020C3B),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.tune_rounded, color: Color(0xFF020C3B)),
                    label: Text(
                      'CONFIGURE PAYMENT SETTINGS FOR ROOM ${room.code}',
                      style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B), fontSize: 15, letterSpacing: 1),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminPaymentSettingsScreen()),
                      );
                    },
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // --- TOP NOTICE & REFERENCE BANNER ---
  Widget _buildTopNoticeBanner(BuildContext context, String roomCode, String notice, String refNote) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF030E40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Colors.tealAccent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SUDDEN PLAN CRICKET CLUB',
                    style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 14, letterSpacing: 1),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                ),
                child: Text(
                  'ROOM: $roomCode',
                  style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 11, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notice,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.35), width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    refNote,
                    style: GoogleFonts.poppins(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: BKASH (2 SEPARATE CARDS WITH NUMBERS & QR) ---
  Widget _buildBkashTab(BuildContext context, dynamic room) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // bKash 1 Card
          _buildBkashCard(
            context: context,
            title: room.bkash1Name.isNotEmpty
                ? room.bkash1Name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
                : 'bKash Personal',
            number: room.bkash1Number,
            qrSource: room.bkash1Qr,
            badgeColor: const Color(0xFFE91E63),
            cardIndex: 1,
          ),
          const SizedBox(height: 16),

          // bKash 2 Card
          _buildBkashCard(
            context: context,
            title: room.bkash2Name.isNotEmpty
                ? room.bkash2Name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim()
                : 'bKash Personal',
            number: room.bkash2Number,
            qrSource: room.bkash2Qr,
            badgeColor: const Color(0xFF9C27B0),
            cardIndex: 2,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBkashCard({
    required BuildContext context,
    required String title,
    required String number,
    required String qrSource,
    required Color badgeColor,
    required int cardIndex,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Image.asset('assets/bkash.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.payment, color: Color(0xFFE91E63), size: 18)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 1),
                      ),
                      Text(
                        'Send Money / Scan QR',
                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  'OPTION $cardIndex',
                  style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 11, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Content: QR Code Left + Number / Copy Right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // QR Code
              GestureDetector(
                onTap: () => _showEnlargedQrDialog(context, qrSource, title, number),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white30, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildQrImageWidget(qrSource),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen_rounded, color: Colors.tealAccent, size: 10),
                          const SizedBox(width: 2),
                          Text('TAP TO ENLARGE', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Details & Action
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'bKash Number',
                      style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 11, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        number,
                        style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 24,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        foregroundColor: Colors.tealAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.tealAccent.withOpacity(0.4)),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(
                        'COPY NUMBER',
                        style: GoogleFonts.bebasNeue(fontSize: 12, letterSpacing: 0.8),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: number));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('bKash Number $number copied to clipboard!'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF020C3B),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 12),
                        const SizedBox(width: 4),
                        Text('Reference: Put Your Name', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 2: BANK TRANSFER DETAILS ---
  Widget _buildBankTab(BuildContext context, dynamic room) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF020C3B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bank Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: _buildBankLogoWidget(room.bankLogo),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.bankName,
                              style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1),
                            ),
                            Text(
                              'Instant NPSB • BEFTN • RTGS Supported',
                              style: GoogleFonts.poppins(color: Colors.tealAccent, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                      ),
                      child: Text(
                        'OFFICIAL ACCOUNT',
                        style: GoogleFonts.bebasNeue(color: Colors.lightBlueAccent, fontSize: 10, letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),

                // Bank Details Rows
                _buildBankInfoTile(
                  context: context,
                  label: 'ACCOUNT NAME',
                  value: room.bankAccountName,
                  canCopy: true,
                ),
                const SizedBox(height: 12),
                _buildBankInfoTile(
                  context: context,
                  label: 'ACCOUNT NUMBER',
                  value: room.bankAccountNumber,
                  canCopy: true,
                  isBold: true,
                ),
                const SizedBox(height: 12),
                _buildBankInfoTile(
                  context: context,
                  label: 'ROUTING NUMBER',
                  value: room.routingNumber,
                  canCopy: true,
                ),
                const SizedBox(height: 12),
                _buildBankInfoTile(
                  context: context,
                  label: 'BRANCH',
                  value: (room.bankBranch != null && room.bankBranch.toString().isNotEmpty && room.bankBranch != 'Principal Branch')
                      ? room.bankBranch
                      : 'Gulshan Principal Branch',
                  canCopy: false,
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can transfer from any mobile banking app or internet banking using BEFTN/NPSB. Include player name in narration.',
                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10.5, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBankInfoTile({
    required BuildContext context,
    required String label,
    required String value,
    required bool canCopy,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 11, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            SelectableText(
              value,
              style: GoogleFonts.poppins(
                color: isBold ? Colors.white : Colors.white70,
                fontSize: isBold ? 16 : 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
        if (canCopy)
          IconButton(
            tooltip: 'Copy $label',
            icon: const Icon(Icons.copy_rounded, color: Colors.tealAccent, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$value copied to clipboard!'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF020C3B),
                ),
              );
            },
          ),
      ],
    );
  }

  // --- IMAGE BUILDER HELPERS ---
  Widget _buildQrImageWidget(String source) {
    if (source.startsWith('data:image') || (!source.startsWith('assets') && source.length > 100)) {
      try {
        final pureBase64 = source.contains(',') ? source.split(',').last : source;
        return Image.memory(base64Decode(pureBase64), fit: BoxFit.contain);
      } catch (_) {}
    }
    return Image.asset(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.qr_code_2_rounded, size: 60, color: Colors.black54),
      ),
    );
  }

  Widget _buildBankLogoWidget(String source) {
    if (source.startsWith('data:image') || (!source.startsWith('assets') && source.length > 100)) {
      try {
        final pureBase64 = source.contains(',') ? source.split(',').last : source;
        return Image.memory(base64Decode(pureBase64), fit: BoxFit.contain);
      } catch (_) {}
    }
    return Image.asset(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance, color: Color(0xFF051970), size: 22),
    );
  }

  // --- FULL SCREEN QR MODAL ---
  void _showEnlargedQrDialog(BuildContext context, String qrSource, String title, String number) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
                      Text(number, style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14)),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: 260,
                height: 260,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.tealAccent.withOpacity(0.2), blurRadius: 16)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildQrImageWidget(qrSource),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Text(
                  'Scan using bKash App • Write Player Name in Reference',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
