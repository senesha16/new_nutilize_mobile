import 'dart:async';

import 'package:flutter/material.dart';

void showTopMessage(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopMessageBanner(
      message: message,
      icon: icon,
      duration: duration,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _TopMessageBanner extends StatefulWidget {
  const _TopMessageBanner({
    required this.message,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_TopMessageBanner> createState() => _TopMessageBannerState();
}

class _TopMessageBannerState extends State<_TopMessageBanner> {
  Timer? _dismissTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
    _dismissTimer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: SafeArea(
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EDFF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      widget.icon,
                      color: const Color(0xFF35489A),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF24304C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onDismiss,
                    tooltip: 'Dismiss notification',
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF7A8199),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
