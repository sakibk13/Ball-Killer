import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BallKillerLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const BallKillerLogo({super.key, this.size = 140, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/icon/logo3.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Icon(
                Icons.sports_cricket,
                size: size * 0.6,
                color: Colors.orange,
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'BALL KILLER',
            style: GoogleFonts.bebasNeue(
              fontSize: size * 0.3,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ],
    );
  }
}