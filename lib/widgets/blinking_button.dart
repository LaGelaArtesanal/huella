import 'package:flutter/material.dart';
import 'dart:async';

class BlinkingButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color blinkColor;
  final Color textColor;
  final IconData? icon;

  const BlinkingButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.blinkColor = Colors.red,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  State<BlinkingButton> createState() => _BlinkingButtonState();
}

class _BlinkingButtonState extends State<BlinkingButton> {
  bool _isVisible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startBlinking() {
    _timer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        setState(() {
          _isVisible = !_isVisible;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 600),
      child: ElevatedButton.icon(
        onPressed: widget.onPressed,
        // ✅ CORREGIDO: Convertir IconData a Widget correctamente
        icon: widget.icon != null ? Icon(widget.icon) : const Icon(Icons.notifications_active),
        label: Text(widget.text, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.blinkColor,
          foregroundColor: widget.textColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}