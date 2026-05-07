import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/audit_log.dart';
import '../services/database_service.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('RECENT ACTIVITY', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
      ),
      body: FutureBuilder<List<AuditLog>>(
        future: DatabaseService().getAuditLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('NO ACTIVITY LOGGED', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 24)));
          }

          final logs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getActionColor(log.action).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getActionIcon(log.action), color: _getActionColor(log.action), size: 20),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(log.adminName.toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.orange, fontSize: 14)),
                              Text(DateFormat('dd MMM, hh:mm a').format(log.timestamp), style: const TextStyle(color: Colors.white24, fontSize: 9)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(log.details, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'EDIT_LOSS': return Colors.blueAccent;
      case 'ADD_FUND': return Colors.greenAccent;
      case 'DELETE_RECORD': return Colors.redAccent;
      default: return Colors.white38;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'EDIT_LOSS': return Icons.edit_note_rounded;
      case 'ADD_FUND': return Icons.account_balance_wallet_rounded;
      case 'DELETE_RECORD': return Icons.delete_forever_rounded;
      default: return Icons.info_outline_rounded;
    }
  }
}
