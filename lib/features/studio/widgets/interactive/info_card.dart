import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> bulletPoints;
  final String? linkUrl;
  final String? linkText;
  final VoidCallback onClose;
  final Offset position;

  const InfoCard({
    super.key,
    required this.title,
    required this.description,
    this.bulletPoints = const [],
    this.linkUrl,
    this.linkText,
    required this.onClose,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Card(
        color: Colors.black87,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 300,
            maxHeight: 400,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Description
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (bulletPoints.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // Bullet points
                      ...bulletPoints.map((point) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(color: Colors.white70)),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    if (linkUrl != null && linkText != null) ...[
                      const SizedBox(height: 12),
                      // Link
                      TextButton(
                        onPressed: () {
                          // TODO: Implement URL launching
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              linkText!,
                              style: const TextStyle(color: Colors.blue),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.open_in_new,
                                size: 16, color: Colors.blue),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Close button
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 