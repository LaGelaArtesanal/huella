import 'package:flutter/material.dart';
import 'dart:async';

class BlinkingCard extends StatefulWidget {
  final bool shouldBlink;
  final Widget child;

  const BlinkingCard({
    super.key,
    required this.shouldBlink,
    required this.child,
  });

  @override
  State<BlinkingCard> createState() => _BlinkingCardState();
}

class _BlinkingCardState extends State<BlinkingCard> {
  bool _isHighlighted = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.shouldBlink) _startBlinking();
  }

  @override
  void didUpdateWidget(BlinkingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldBlink != oldWidget.shouldBlink) {
      if (widget.shouldBlink) {
        _startBlinking();
      } else {
        _timer?.cancel();
        _isHighlighted = false;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startBlinking() {
    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() => _isHighlighted = !_isHighlighted);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _isHighlighted && widget.shouldBlink ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isHighlighted && widget.shouldBlink ? Colors.red : Colors.grey.shade200,
          width: _isHighlighted && widget.shouldBlink ? 2 : 1,
        ),
        boxShadow: _isHighlighted && widget.shouldBlink
            ? [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)]
            : [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: widget.child,
    );
  }
}