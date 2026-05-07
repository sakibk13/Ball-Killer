import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player.dart';

class PlayerTable extends StatelessWidget {
  final List<Player> players;

  const PlayerTable({
    super.key,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No players found',
            style: GoogleFonts.poppins(color: Colors.white38),
          ),
        ),
      );
    }

    return Column(
      children: players.asMap().entries.map((entry) {
        int index = entry.key;
        Player player = entry.value;
        bool isTop3 = index < 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isTop3 
                ? Colors.orange.withOpacity(0.1) 
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTop3 ? Colors.orange.withOpacity(0.3) : Colors.white10,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildRankBadge(index + 1),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Player ID: ${player.phone.substring(player.phone.length - 4)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${player.totalLost}',
                    style: GoogleFonts.bebasNeue(
                      color: Colors.orange,
                      fontSize: 22,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'LOST',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) return const Icon(Icons.emoji_events, color: Colors.amber, size: 28);
    if (rank == 2) return const Icon(Icons.emoji_events, color: Colors.grey, size: 26);
    if (rank == 3) return const Icon(Icons.emoji_events, color: Colors.brown, size: 24);
    
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white12,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        '$rank',
        style: GoogleFonts.bebasNeue(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),
    );
  }
}
