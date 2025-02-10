import 'package:flutter/material.dart';
import 'info_card.dart';

class InfoCardTestPage extends StatefulWidget {
  const InfoCardTestPage({super.key});

  @override
  State<InfoCardTestPage> createState() => _InfoCardTestPageState();
}

class _InfoCardTestPageState extends State<InfoCardTestPage> {
  bool _showCard = false;
  Offset _cardPosition = const Offset(100, 100);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Card Test'),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16/9,
                child: Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Text(
                      'Video Area\nTap anywhere to place card',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Card placement area
          GestureDetector(
            onTapUp: (details) {
              setState(() {
                _cardPosition = details.localPosition;
                _showCard = true;
              });
            },
          ),
          
          // Info Card
          if (_showCard)
            InfoCard(
              position: _cardPosition,
              title: 'Understanding useState Hook',
              description: 'The useState hook is one of the most important React hooks. It allows you to add state management to functional components.',
              bulletPoints: [
                'Returns array with state value and setter function',
                'Triggers re-render when state changes',
                'Can be used multiple times in one component',
              ],
              linkUrl: 'https://react.dev/reference/react/useState',
              linkText: 'Read Documentation',
              onClose: () => setState(() => _showCard = false),
            ),
            
          // Instructions
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap anywhere to move the card',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 