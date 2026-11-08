import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../providers/fund_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/unintentional_provider.dart';
import '../utils/string_utils.dart';
import '../utils/status_dialog.dart';
import 'leaderboard_screen.dart';
import 'records_screen.dart';
import 'player_ball_loss_screen.dart';
import 'unintentional_loss_screen.dart';
import 'loss_comparison_screen.dart';
import 'fine_screen.dart';
import 'fund_screen.dart';
import 'inventory_screen.dart';
import 'contribution_screen.dart';
import 'player_status_screen.dart';
import 'report_center_screen.dart';
import 'manage_players_screen.dart';
import '../providers/room_provider.dart';
import 'super_admin_screen.dart';
import 'profile_screen.dart';
import 'about_us_screen.dart';
import 'payment_notice_screen.dart';
import 'admin_payment_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).init();
      Provider.of<InventoryProvider>(context, listen: false).fetchInventory();
      Provider.of<FundProvider>(context, listen: false).fetchFunds();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<UnintentionalProvider>(context, listen: false).init();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ballProvider = Provider.of<BallProvider>(context);
    final invProvider = Provider.of<InventoryProvider>(context);
    final fundProvider = Provider.of<FundProvider>(context);
    final contProvider = Provider.of<ContributionProvider>(context);
    final fineProvider = Provider.of<FineProvider>(context);

    final user = authProvider.currentUser;
    final isAdmin = authProvider.isAdmin;
    final isLoading = ballProvider.isLoading || invProvider.isLoading;
    final double screenWidth = MediaQuery.of(context).size.width;

    Uint8List? photoBytes;
    if (user?.photoUrl != null && user!.photoUrl.isNotEmpty) {
      try { photoBytes = base64Decode(user.photoUrl); } catch (_) {}
    }

    // CONSISTENT CALCULATION FOR PERSONAL STATS
    Map<String, dynamic>? personalStats;
    if (user != null) {
       final playersList = ballProvider.players;
       final player = playersList.isEmpty ? null : playersList.firstWhere((p) => p.phone == user.phone, orElse: () => playersList.first);

       if (player != null) {
         final String pId = player.id!;
         final int lostOverall = player.totalLost; // Respect manual overrides
         final double totalOwed = lostOverall * 50.0;

         final double paidDirect = fineProvider.payments.where((p) => p.playerId == pId).fold(0.0, (sum, p) => sum + p.amountPaid);
         final double paidContrib = contProvider.contributions.where((c) => c.playerId == pId && !c.isOther).fold(0.0, (sum, c) => sum + c.taka);
         final double paidOverall = paidDirect + paidContrib;

         double due = 0; double credit = 0;
         if (paidOverall >= totalOwed) { credit = paidOverall - totalOwed; } else { due = totalOwed - paidOverall; }

         personalStats = { 'lost': lostOverall, 'due': due, 'credit': credit };
       }
    }

    // CONSISTENT CALCULATION FOR TOP FINE USER
    Map<String, dynamic>? topFineUser;
    if (ballProvider.players.isNotEmpty) {
      final statusList = ballProvider.players.map((p) {
        final String pId = p.id!;
        final int balls = p.totalLost; // Respect manual overrides
        final double paid = fineProvider.payments.where((pay) => pay.playerId == pId).fold(0.0, (s, pay) => s + pay.amountPaid) +
                           contProvider.contributions.where((c) => c.playerId == pId && !c.isOther).fold(0.0, (s, c) => s + c.taka);
        final double dueVal = (balls * 50.0) - paid;
        return {'name': p.name, 'due': dueVal, 'photoUrl': p.photoUrl};
      }).toList();
      statusList.sort((a, b) => (b['due'] as double).compareTo(a['due'] as double));
      if ((statusList.first['due'] as double) > 0) topFineUser = statusList.first;
    }    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await ballProvider.refresh();
                await invProvider.fetchInventory();
                await fundProvider.fetchFunds();
                if (context.mounted) {
                  await Provider.of<UnintentionalProvider>(context, listen: false).refresh();
                }
              },
              color: Colors.tealAccent,
              child: FadeTransition(
                opacity: _fadeController,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: screenWidth > 900 ? 1100 : 800),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildHeader(user, photoBytes, authProvider),
                          
                          const SizedBox(height: 18),
                          if (isLoading) _buildShimmerPersonalCard()
                          else if (personalStats != null && !authProvider.isGuest) _buildPersonalStatusCard(personalStats),
                          
                          if (topFineUser != null && !authProvider.isGuest) ...[
                            const SizedBox(height: 14),
                            _buildTopFineHighlight(topFineUser),
                          ],

                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 10),
                              Text('COMMAND CENTER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 17, letterSpacing: 1.4)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildQuickActionsGrid(isAdmin, authProvider.isGuest, screenWidth),

                          const SizedBox(height: 24),
                          _buildSecondaryActionsGrid(isAdmin, authProvider.isGuest, screenWidth, authProvider),
                          
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic user, Uint8List? photoBytes, AuthProvider auth) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(StringUtils.capitalize(user?.name ?? 'Player'), style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.white, letterSpacing: 1.2)),
                  const SizedBox(width: 8),
                  Consumer<RoomProvider>(
                    builder: (ctx, roomProv, _) => GestureDetector(
                      onTap: () => _showRoomOptionsModal(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.tealAccent.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_rounded, color: Colors.tealAccent, size: 12),
                            const SizedBox(width: 4),
                            Text(roomProv.currentRoomCode, style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 13, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Hero(
            tag: 'profile_pic',
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.tealAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.tealAccent.withOpacity(0.25), blurRadius: 10, spreadRadius: 1)],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF020C3B),
                backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                child: photoBytes == null ? const Icon(Icons.person_rounded, color: Colors.tealAccent, size: 26) : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentNoticeScreen())),
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent, size: 20),
          tooltip: 'Payment Notice & QR',
        ),
        IconButton(
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout_rounded, color: Colors.white38, size: 20),
          tooltip: 'Logout',
        ),
      ],
    );
  }

  Widget _buildPersonalStatusCard(Map<String, dynamic> stats) {
    final double dueAmount = (stats['due'] as double);
    final double creditAmount = (stats['credit'] as double);
    final int lostCount = (stats['lost'] as int);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B4B), Color(0xFF061033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
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
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text('MY CAREER STATS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 1.3)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.tealAccent, size: 12),
                    const SizedBox(width: 4),
                    Text('CAREER', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 10, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactStatItem('LOST', '$lostCount', Icons.sports_cricket_rounded, const Color(0xFFFF5252)),
              ),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.08)),
              Expanded(
                child: _buildCompactStatItem('DUE', '${dueAmount.toInt()}৳', Icons.receipt_long_rounded, dueAmount > 0 ? Colors.orangeAccent : const Color(0xFF00E676)),
              ),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.08)),
              Expanded(
                child: _buildCompactStatItem('CREDIT', '${creditAmount.toInt()}৳', Icons.account_balance_wallet_rounded, const Color(0xFF00E676)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 18, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 10, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildTopFineHighlight(Map<String, dynamic> topPlayer) {
    Uint8List? pBytes;
    if (topPlayer['photoUrl'] != null && topPlayer['photoUrl'] != '') {
      try { pBytes = base64Decode(topPlayer['photoUrl']); } catch (_) {}
    }
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FineScreen())),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B080C), Color(0xFF6B0E14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.redAccent.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.black26,
                backgroundImage: pBytes != null ? MemoryImage(pBytes) : null,
                child: pBytes == null ? const Icon(Icons.person, color: Colors.white54, size: 22) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 13),
                      const SizedBox(width: 4),
                      Text('PENDING FINE ALERT', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 11, letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(StringUtils.capitalize(topPlayer['name']), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('DUE AMOUNT', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 10, letterSpacing: 0.8)),
                Text('${(topPlayer['due'] as double).toInt()} ৳', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isAdmin, bool isGuest, double screenWidth) {
    int columns = screenWidth > 950 ? 4 : (screenWidth > 600 ? 3 : 2);
    double ratio = screenWidth > 950 ? 2.6 : (screenWidth > 600 ? 2.4 : 2.2);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: ratio,
      children: [
        _buildActionGridItem('PLAYER FINES', Icons.money_off_rounded, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FineScreen()))),
        _buildActionGridItem('UNINTENTIONAL', Icons.help_outline_rounded, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnintentionalLossScreen()))),
        _buildActionGridItem('LOSS ANALYTICS', Icons.analytics_rounded, Colors.tealAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LossComparisonScreen()))),
        _buildActionGridItem('TRACK OVERVIEW', Icons.assignment_late_outlined, Colors.amberAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen()))),
        _buildActionGridItem('LEADERBOARD', Icons.workspace_premium_rounded, Colors.cyanAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
        _buildActionGridItem('PLAYER STATUS', Icons.person_search_rounded, Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerStatusScreen()))),
        _buildActionGridItem('RECORD LOSS', Icons.sports_cricket_rounded, const Color(0xFF00E676), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerBallLossScreen()))),
        _buildActionGridItem('ABOUT US', Icons.auto_awesome_rounded, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen()))),
      ],
    );
  }

  Widget _buildSecondaryActionsGrid(bool isAdmin, bool isGuest, double screenWidth, AuthProvider auth) {
    int columns = screenWidth > 950 ? 4 : (screenWidth > 600 ? 3 : 2);
    double ratio = screenWidth > 950 ? 2.6 : (screenWidth > 600 ? 2.4 : 2.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('FINANCIALS & INVENTORY', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 15, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: ratio,
          children: [
            _buildActionGridItem('FINANCIAL LOGS', Icons.payments_outlined, const Color(0xFF00E676), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContributionScreen()))),
            _buildActionGridItem('TREASURY LOG', Icons.account_balance_rounded, Colors.tealAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundScreen()))),
            _buildActionGridItem('STOCK LOG', Icons.inventory_2_outlined, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()))),
            _buildActionGridItem('REPORT CENTER', Icons.bar_chart_rounded, Colors.cyanAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportCenterScreen()))),
            _buildActionGridItem('PAYMENT NOTICE', Icons.qr_code_scanner_rounded, const Color(0xFFE91E63), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentNoticeScreen()))),
            _buildActionGridItem('EXCEL EXPORT', Icons.table_chart_rounded, const Color(0xFF00E676), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportCenterScreen()))),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text('ADMIN PANEL', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 15, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
            children: [
              _buildActionGridItem('RECORD LOSS', Icons.sports_cricket_rounded, Colors.tealAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerBallLossScreen()))),
              _buildActionGridItem('UNINTENTIONAL', Icons.help_outline_rounded, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnintentionalLossScreen()))),
              _buildActionGridItem('MANAGE PLAYERS', Icons.group_outlined, Colors.pinkAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlayersScreen()))),
              _buildActionGridItem('PAYMENT SETUP', Icons.tune_rounded, Colors.cyanAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPaymentSettingsScreen()))),
              if (auth.isSuperAdmin)
                _buildActionGridItem('SUPER ADMIN', Icons.admin_panel_settings_rounded, Colors.amberAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminScreen()))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionGridItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0C1640), Color(0xFF040A26)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2), width: 0.8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 1.0,
                  height: 1.1,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.4), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerPersonalCard() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.05),
      highlightColor: Colors.white.withOpacity(0.1),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  void _showRoomOptionsModal(BuildContext context) {
    final roomProv = Provider.of<RoomProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF020C3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE ROOM', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 24, letterSpacing: 1.2)),
                    Text(roomProv.currentRoomName, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                  child: Text(roomProv.currentRoomCode, style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 18, letterSpacing: 1.5)),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Divider(color: Colors.white10),
            const SizedBox(height: 15),
            Text('SWITCH / JOIN ROOM', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: codeCtrl,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: '6-CHAR CODE',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (code.length < 3) return;
                    bool joined = await roomProv.joinRoom(code);
                    if (joined && mounted) {
                      Navigator.pop(ctx);
                      Provider.of<BallProvider>(context, listen: false).init(force: true);
                      StatusDialog.show(context, title: "ROOM SWITCHED", message: "Active Room set to: $code", isSuccess: true);
                    } else if (mounted) {
                      StatusDialog.show(context, title: "NOT FOUND", message: "Room '$code' not found.", isSuccess: false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), minimumSize: const Size(80, 48)),
                  child: Text('JOIN', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 15),
            Text('CREATE NEW ROOM (BECOME ROOM ADMIN)', style: GoogleFonts.bebasNeue(color: Colors.amberAccent, fontSize: 18, letterSpacing: 1)),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Room Name (e.g. Sudden Plan Cricket Team)',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final code = codeCtrl.text.trim().toUpperCase();
                  if (name.isEmpty || code.length != 6) {
                    StatusDialog.show(context, title: "INVALID INPUT", message: "Enter Room Name & 6-char Code.", isSuccess: false);
                    return;
                  }

                  final adminPhone = authProv.currentUser?.phone ?? 'admin_phone';
                  bool created = await roomProv.createRoom(code: code, name: name, adminPhone: adminPhone);

                  if (created && mounted) {
                    Navigator.pop(ctx);
                    Provider.of<BallProvider>(context, listen: false).init(force: true);
                    StatusDialog.show(context, title: "ROOM CREATED", message: "Created & Switched to Room $code! You are Room Admin.", isSuccess: true);
                  } else if (mounted) {
                    StatusDialog.show(context, title: "EXISTS", message: "Room Code '$code' already exists.", isSuccess: false);
                  }
                },
                icon: const Icon(Icons.add_business_rounded, color: Colors.white),
                label: Text('CREATE ROOM & SWITCH', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 1.2)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
