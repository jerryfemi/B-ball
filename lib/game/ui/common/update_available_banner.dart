import 'package:flutter/material.dart';

import '../../../services/update/update_service.dart';

/// Floating toast/banner notifying players that a new game build is deployed.
/// Tapping 'Reload' pulls down the latest code immediately.
class UpdateAvailableBanner extends StatefulWidget {
  const UpdateAvailableBanner({super.key});

  @override
  State<UpdateAvailableBanner> createState() => _UpdateAvailableBannerState();
}

class _UpdateAvailableBannerState extends State<UpdateAvailableBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: const Color(0x5538BDF8),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330284C7),
                blurRadius: 16.0,
                spreadRadius: 2.0,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26.0,
                height: 26.0,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 16.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10.0),
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPDATE AVAILABLE',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    'New features & polish ready',
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14.0),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => UpdateService.instance.reload(),
                  borderRadius: BorderRadius.circular(16.0),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4438BDF8),
                          blurRadius: 6.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 13.0,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          'Reload',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16.0,
                  color: Color(0xFF94A3B8),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24.0,
                  minHeight: 24.0,
                ),
                tooltip: 'Dismiss',
                onPressed: () => UpdateService.instance.dismiss(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
