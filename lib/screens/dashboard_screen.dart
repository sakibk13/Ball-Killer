import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../providers/fund_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/fine_provider.dart';
import '../services/cloud_sync_service.dart';
import '../utils/string_utils.dart';
import '../utils/status_dialog.dart';
import '../utils/date_utils.dart';
import 'leaderboard_screen.dart';
import 'records_screen.dart';
import 'player_ball_loss_screen.dart';
import 'fine_screen.dart';
import 'fund_screen.dart';
import 'inventory_screen.dart';
import 'contribution_screen.dart';
import 'player_status_screen.dart';
import 'report_center_screen.dart';
import 'manage_players_screen.dart';
import 'audit_log_screen.dart';
import 'profile_screen.dart';
import 'admin_approvals_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  bool _isSyncing = false;

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
      
      _checkSyncStatus();
    });
  }

  void _checkSyncStatus() async {
    final lastSync = await CloudSyncService.getLastSyncTime();
    if (lastSync == null) return;

    final diff = DateTime.now().difference(lastSync);
    if (diff.inHours >= 12) {
       if (mounted) {
         showDialog(
           context: context,
           builder: (ctx) => BackdropFilter(
             filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
             child: AlertDialog(
               backgroundColor: const Color(0xFF020C3B),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: Colors.tealAccent, width: 0.5)),
               title: Text('CLOUD BACKUP DUE', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, letterSpacing: 1.5)),
               content: const Text('It has been over 12 hours since your last Google Sheets sync. Back up your data now?', style: TextStyle(color: Colors.white70)),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('LATER', style: TextStyle(color: Colors.white24))),
                 ElevatedButton(
                   onPressed: () {
                     Navigator.pop(ctx);
                     _syncData();
                   },
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                   child: Text('SYNC NOW', style: GoogleFonts.bebasNeue(color: const Color(0xFF020C3B), letterSpacing: 1)),
                 ),
               ],
             ),
           ),
         );
       }
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);

    final ballProvider = Provider.of<BallProvider>(context, listen: false);
    final invProvider = Provider.of<InventoryProvider>(context, listen: false);
    final fundProvider = Provider.of<FundProvider>(context, listen: false);
    final contProvider = Provider.of<ContributionProvider>(context, listen: false);
    final fineProvider = Provider.of<FineProvider>(context, listen: false);

    // ENSURE DATA IS LOADED
    await ballProvider.refresh();
    await invProvider.fetchInventory();
    await fundProvider.fetchFunds();
    await contProvider.fetchContributions();
    await fineProvider.fetchPayments();

    final String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    // 1. Gather ALL Monthly Leaderboards
    final Set<String> monthsWithData = {currentMonth};
    for (var r in ballProvider.allRecords) {
      if (r.monthYear.isNotEmpty) monthsWithData.add(DateUtilsHelper.normalizeMonthYear(r.monthYear));
    }

    Map<String, List<Map<String, dynamic>>> allMonthlyLeaderboards = {};
    for (var m in monthsWithData) {
      allMonthlyLeaderboards[m] = ballProvider.getPlayersWithTotals(monthYear: m);
    }

    final leaderboardOverall = ballProvider.getPlayersWithTotals(monthYear: 'Overall');

    // 2. Player Status Overall (Cumulative) - CONSISTENT LOGIC
    final playerStatusOverall = ballProvider.players.map((p) {
      final String playerId = p.id!;

      // A. LIFETIME BALLS & FINE (Using p.totalLost to respect manual edits)
      final int lifetimeBalls = p.totalLost;
      final double totalFineOverall = lifetimeBalls * 50.0;

      // B. LIFETIME PAYMENTS (Deductible cash only)
      final double totalPaidDirectLifetime = fineProvider.payments
          .where((pay) => pay.playerId == playerId)
          .fold(0.0, (sum, pay) => sum + pay.amountPaid);

      final double totalFineSpecificContribLifetime = contProvider.contributions
          .where((c) => c.playerId == playerId && !c.isOther)
          .fold(0.0, (sum, c) => sum + c.taka);

      final double totalPaidDeductible = totalPaidDirectLifetime + totalFineSpecificContribLifetime;

      // C. FINAL STATUS
      double due = 0;
      double credit = 0;
      if (totalPaidDeductible >= totalFineOverall) {
        credit = totalPaidDeductible - totalFineOverall;
      } else {
        due = totalFineOverall - totalPaidDeductible;
      }

      return {
        'name': p.name,
        'phone': p.phone,
        'total': lifetimeBalls,
        'totalFine': totalFineOverall,
        'paid': totalPaidDeductible,
        'due': due,
        'surplus': credit,
      };
    }).toList()..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    final result = await CloudSyncService.syncAllData(
      allMonthlyLeaderboards: allMonthlyLeaderboards,
      leaderboardOverall: leaderboardOverall,
      playerStatusOverall: playerStatusOverall,
      funds: fundProvider.funds,
      contributions: contProvider.contributions,
      fines: fineProvider.payments,
      stock: invProvider.inventoryList,
      users: ballProvider.players,
    );
    setState(() => _isSyncing = false);

    if (mounted) {
      final bool success = result['success'] == true;
      StatusDialog.show(
        context,
        title: success ? "SYNC SUCCESS" : "SYNC FAILED",
        message: success ? "Google Sheets updated with Monthly & Overall data." : (result['message'] ?? "Sync failed"),
        isSuccess: success,
      );
    }
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
              },
              color: Colors.tealAccent,
              child: FadeTransition(
                opacity: _fadeController,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildHeader(user, photoBytes, authProvider),
                          
                          const SizedBox(height: 25),
                          if (isLoading) _buildShimmerPersonalCard()
                          else if (personalStats != null && !authProvider.isGuest) _buildPersonalStatusCard(personalStats),
                          
                          if (topFineUser != null && !authProvider.isGuest) ...[
                            const SizedBox(height: 20),
                            _buildTopFineHighlight(topFineUser),
                          ],

                          const SizedBox(height: 35),
                          Row(
                            children: [
                              Container(width: 4, height: 18, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 10),
                              Text('COMMAND CENTER', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.5)),
                              const Spacer(),
                              if (isAdmin) _buildSmallSyncButton(),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildQuickActionsGrid(isAdmin, authProvider.isGuest, screenWidth),

                          const SizedBox(height: 35),
                          _buildSecondaryActionsGrid(isAdmin, authProvider.isGuest, screenWidth),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isSyncing)
            Container(
              color: Colors.black87,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2),
                      const SizedBox(height: 25),
                      Text('CLOUD DATABASE SYNC', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 22, letterSpacing: 2)),
                      Text('DO NOT CLOSE THE APPLICATION', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
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
              Text('GOOD DAY,', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(StringUtils.capitalize(user?.name ?? 'Player'), style: GoogleFonts.bebasNeue(fontSize: 36, color: Colors.white, letterSpacing: 1.5)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Hero(
            tag: 'profile_pic',
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.tealAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 15, spreadRadius: 1)],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF020C3B),
                backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                child: photoBytes == null ? const Icon(Icons.person_rounded, color: Colors.blueAccent, size: 30) : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        IconButton(
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout_rounded, color: Colors.white24, size: 20),
        ),
      ],
    );
  }

  Widget _buildPersonalStatusCard(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1235),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MY CAREER STATS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSimpleStat('LOST', '${stats['lost']}', const Color(0xFFFF5252)),
              _buildSimpleStat('DUE', '${(stats['due'] as double).toInt()}৳', (stats['due'] as double) > 0 ? Colors.orangeAccent : const Color(0xFF00E676)),
              _buildSimpleStat('CREDIT', '${(stats['credit'] as double).toInt()}৳', const Color(0xFF00E676)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(child: Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 20))),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 10, letterSpacing: 0.8)),
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
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4A0000), Color(0xFF8B0000)]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 15)],
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white10,
              backgroundImage: pBytes != null ? MemoryImage(pBytes) : null,
              child: pBytes == null ? const Icon(Icons.person, color: Colors.white24) : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PENDING FINE ALERT', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
                  Text(StringUtils.capitalize(topPlayer['name']), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('DUE AMOUNT', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 10)),
                Text('${(topPlayer['due'] as double).toInt()} ৳', style: GoogleFonts.bebasNeue(color: const Color(0xFFFF5252), fontSize: 24)),
              ],
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isAdmin, bool isGuest, double screenWidth) {
    int columns = screenWidth > 600 ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.6,
      children: [
        _buildActionGridItem('LEADERBOARD', Icons.workspace_premium_rounded, Colors.cyanAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
        _buildActionGridItem('TRACK OVERVIEW', Icons.assignment_late_outlined, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen()))),
        _buildActionGridItem('PLAYER FINES', Icons.money_off_rounded, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FineScreen()))),
        _buildActionGridItem('PLAYER STATUS', Icons.person_search_rounded, Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerStatusScreen()))),
      ],
    );
  }

  Widget _buildSecondaryActionsGrid(bool isAdmin, bool isGuest, double screenWidth) {
    int columns = screenWidth > 600 ? 4 : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text('FINANCIALS & INVENTORY', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 16, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.6,
          children: [
            _buildActionGridItem('FINANCIAL LOGS', Icons.payments_outlined, const Color(0xFF00E676), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContributionScreen()))),
            _buildActionGridItem('TREASURY LOG', Icons.account_balance_rounded, Colors.tealAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundScreen()))),
            _buildActionGridItem('STOCK LOG', Icons.inventory_2_outlined, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()))),
            _buildActionGridItem('REPORT CENTER', Icons.bar_chart_rounded, Colors.cyanAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportCenterScreen()))),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: 25),
          Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text('ADMIN PANEL', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 16, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.6,
            children: [
              _buildActionGridItem('RECORD LOSS', Icons.sports_cricket_rounded, Colors.tealAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerBallLossScreen()))),
              _buildActionGridItem('CLOUD SYNC', Icons.cloud_sync_rounded, Colors.white, () => _showSyncOptions()),
              _buildActionGridItem('MANAGE PLAYERS', Icons.group_outlined, Colors.pinkAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlayersScreen()))),
              _buildActionGridItem('PENDING APPROVALS', Icons.how_to_reg_rounded, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()))),
              _buildActionGridItem('SYSTEM AUDIT', Icons.security_rounded, Colors.white30, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen()))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionGridItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A1235), Color(0xFF020C3B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            FittedBox(child: Text(label, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 13, letterSpacing: 1.2))),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallSyncButton() {
    return IconButton(
      onPressed: () => _syncData(),
      icon: const Icon(Icons.sync_rounded, color: Colors.tealAccent, size: 20),
    );
  }

  void _showSyncOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF020C3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CLOUD CONTROL', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1.5)),
            const SizedBox(height: 25),
            _buildSyncOption('FORCE PUSH', 'Sync local data to Google Sheets', Icons.cloud_upload_rounded, Colors.tealAccent, () {
              Navigator.pop(context);
              _syncData();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 1)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
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
}
