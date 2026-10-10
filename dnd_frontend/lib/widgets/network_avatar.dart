import 'package:flutter/material.dart';

class NetworkAvatar extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final Widget placeholder;

  const NetworkAvatar({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';
    if (imageUrl.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(child: placeholder),
      );
    }
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
        ),
      ),
    );
  }
}