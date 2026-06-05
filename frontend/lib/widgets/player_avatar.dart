import 'package:flutter/material.dart';

class PlayerAvatar extends StatelessWidget {
  final String name;
  final int cardCount;
  final Color teamColor; // Changed from isTeammate
  final bool isMyTurn;

  const PlayerAvatar({
    required this.name,
    required this.cardCount,
    required this.teamColor, // Changed from isTeammate
    this.isMyTurn = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, 
      children: [
        Container(
          decoration: isMyTurn ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.amber, blurRadius: 10, spreadRadius: 2)
            ]
          ) : null,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: teamColor, // Applied the absolute team color here
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[900],
              child: const Icon(Icons.person, size: 35, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Text('$cardCount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(width: 4), 
                  const RotatedBox(quarterTurns: 2, child: Icon(Icons.style, size: 16, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}