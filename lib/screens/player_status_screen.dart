import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../providers/contribution_provider.dart';
import '../providers/auth_provider.dart';
import '../models/fine_payment.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';
import '../utils/string_utils.dart';

class PlayerStatusScreen extends StatefulWidget {
  const PlayerStatusScreen({super.key});

  @override
  State<PlayerStatusScreen> createState() => _PlayerStatusScreenState();
}

class _PlayerStatusScreenState extends State<PlayerStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BallProvider>(context, listen: false).refresh();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ballProv = Provider.of<BallProvider>(context);
    final fineProv = Provider.of<FineProvider>(context);
    final contProv = Provider.of<ContributionProvider>(context);
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;

    if (ballProv.isLoading || fineProv.isLoading || contProv.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF051970),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }


    final players = ballProv.players;
    final List<Map<String, dynamic>> enriched = players.map((p) {
      final String playerId = p.id!;

      // 1. Calculate Lifetime Balls
      final int lifetimeBalls = ballProv.allRecords
          .where((r) => r.playerId == playerId)
          .fold(0, (sum, r) => sum + r.lostCount);
      
      final double totalFineOverall = lifetimeBalls * 50.0;

      // 2. Calculate Lifetime Payments (Deductible cash only)
      // Direct Fine Payments
      final double totalPaidDirectLifetime = fineProv.payments
          .where((pay) => pay.playerId == playerId)
          .fold(0.0, (sum, pay) => sum + pay.amountPaid);

      // Cash Contributions (Deductible)
      final double totalFineSpecificContribLifetime = contProv.contributions
          .where((c) => c.playerId == playerId && !c.isOther)
          .fold(0.0, (sum, c) => sum + c.taka);
      
      final double totalPaidDeductible = totalPaidDirectLifetime + totalFineSpecificContribLifetime;

      // 3. Final Status
      double due = 0; double credit = 0;
      if (totalPaidDeductible >= totalFineOverall) {
        credit = totalPaidDeductible - totalFineOverall;
      } else {
        due = totalFineOverall - totalPaidDeductible;
      }

      return {
        'id': playerId,
        'name': StringUtils.capitalize(p.name),
        'photoUrl': p.photoUrl,
        'total': lifetimeBalls,
        'totalFine': totalFineOverall,
        'paid': totalPaidDeductible, // Standardized "Given" amount
        'due': due,
        'surplus': credit,
      };
    }).toList()..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('MASTER PLAYER STATUS', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.tealAccent),
            onPressed: () async {
              try {
                await ExportService.exportPlayerStatusReport(players: enriched);
                if (mounted) {
                  StatusDialog.show(context, title: "SUCCESS", message: "Master Status PDF Generated!", isSuccess: true);
                }
              } catch (e) {
                if (mounted) {
                  StatusDialog.show(context, title: "ERROR", message: "Failed: $e", isSuccess: false);
                }
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderRow(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: enriched.length,
              itemBuilder: (context, index) {
                final p = enriched[index];
                return _buildPlayerRow(p, index, isAdmin);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerDetails(Map<String, dynamic> player) {
    final fineProv = Provider.of<FineProvider>(context, listen: false);
    final contProv = Provider.of<ContributionProvider>(context, listen: false);
    
    final payments = fineProv.payments.where((p) => p.playerId == player['id']).toList();
    final contributions = contProv.contributions.where((c) => c.playerId == player['id']).toList();
    
    final List<dynamic> history = [...payments, ...contributions];
    history.sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF020C3B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: player['photoUrl'] != '' ? MemoryImage(base64Decode(player['photoUrl'])) : null,
                  child: player['photoUrl'] == '' ? Text(player['name'][0], style: const TextStyle(fontSize: 24)) : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(StringUtils.capitalize(player['name'].toString()), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
                      Text('Transaction History', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white38)),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallStat('DUE', '${player['due'].toInt()} ৳', Colors.redAccent),
                _buildSmallStat('CREDIT', '${player['surplus'].toInt()} ৳', Colors.greenAccent),
                _buildSmallStat('TOTAL PAID', '${player['paid'].toInt()} ৳', Colors.blueAccent),
              ],
            ),
            const SizedBox(height: 25),
            Text('PAYMENT & CONTRIBUTION LOG', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 16, letterSpacing: 1)),
            const Divider(color: Colors.white10, height: 20),
            Expanded(
              child: history.isEmpty 
                ? Center(child: Text('No transaction history found', style: GoogleFonts.poppins(color: Colors.white24)))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, i) {
                      final item = history[i];
                      final isFine = item is FinePayment;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isFine ? 'FINE PAYMENT' : 'CONTRIBUTION', style: GoogleFonts.bebasNeue(color: isFine ? Colors.tealAccent : Colors.blueAccent, fontSize: 14)),
                                Text(DateFormat('dd MMM, yyyy').format(item.date), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                            Text('${(isFine ? item.amountPaid : item.taka).toInt()} ৳', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLostDialog(Map<String, dynamic> player) {
    final controller = TextEditingController(text: player['total'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('EDIT BALL LOSS', style: GoogleFonts.bebasNeue(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player: ${StringUtils.capitalize(player['name'])}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Total Balls Lost',
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
            onPressed: () async {
              final newValue = int.tryParse(controller.text);
              if (newValue != null) {
                final adminName = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
                final success = await Provider.of<BallProvider>(context, listen: false).overridePlayerTotalLost(player['id'], newValue, adminName);
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully')));
                }
              }
            },
            child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 18)),
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 10)),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF020C3B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          _tableHeader('RK', 30),
          _tableHeader('PIC', 35),
          Expanded(child: _tableHeader('NAME', 0)),
          _tableHeader('LOST', 45),
          _tableHeader('TOTAL', 50),
          _tableHeader('GIVEN', 50),
          _tableHeader('DUE', 50),
          _tableHeader('CREDIT', 50),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, double width) {
    return SizedBox(
      width: width == 0 ? null : width,
      child: Text(
        text, 
        textAlign: width == 0 ? TextAlign.left : TextAlign.center,
        style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 10, letterSpacing: 1)
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> p, int index, bool isAdmin) {
    String displayName = p['name'];
    if (displayName.contains(' ')) {
      final parts = displayName.split(' ');
      displayName = '${parts[0]}\n${parts.sublist(1).join(' ')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white.withOpacity(0.02) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('${index + 1}', textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: Colors.white24))),
          SizedBox(width: 35, child: Center(
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white10,
              backgroundImage: p['photoUrl'] != null && p['photoUrl'] != '' ? MemoryImage(base64Decode(p['photoUrl'])) : null,
              child: p['photoUrl'] == '' ? Text(p['name'][0], style: const TextStyle(fontSize: 8)) : null,
            ),
          )),
          Expanded(
            child: InkWell(
              onTap: () => _showPlayerDetails(p),
              child: Text(displayName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.1)),
            ),
          ),
          SizedBox(
            width: 45, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${p['total']}', textAlign: TextAlign.center, style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14)),
                if (isAdmin)
                  GestureDetector(
                    onTap: () => _showEditLostDialog(p),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.edit, color: Colors.tealAccent, size: 12),
                    ),
                  ),
              ],
            )
          ),
          SizedBox(width: 50, child: Text('${(p['totalFine'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: Colors.yellowAccent, fontSize: 14))),
          SizedBox(width: 50, child: Text('${(p['paid'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: Colors.greenAccent, fontSize: 14))),
          SizedBox(width: 50, child: Text('${(p['due'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: (p['due'] as double) > 0 ? Colors.redAccent : Colors.greenAccent, fontSize: 14))),
          SizedBox(width: 50, child: Text('${(p['surplus'] as double).toInt()}', textAlign: TextAlign.right, style: GoogleFonts.bebasNeue(color: (p['surplus'] as double) > 0 ? Colors.blueAccent : Colors.white10, fontSize: 14))),
        ],
      ),
    );
  }
}
