import 'package:flutter/material.dart';
import 'package:khata_app/theme/app_theme.dart';

/// Floating microphone button used to trigger voice commands.
///
/// Displays a pulsing animation while listening and respects the
/// [isListening] state supplied by the caller.
class MicButton extends StatefulWidget {
  const MicButton({
    required this.isListening,
    required this.onTap,
    this.size = 64,
    super.key,
  });

  /// True when the speech service is actively listening.
  final bool isListening;

  /// Called when the user taps the microphone.
  ///
  /// When null, the button appears dimmed and non-interactive (e.g. while
  /// the backend is processing a previous command).
  final VoidCallback? onTap;

  /// Diameter of the button.
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size * _pulseAnimation.value,
          height: widget.size * _pulseAnimation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isListening
                ? AppTheme.error
                : AppTheme.greenAccent,
            boxShadow: [
              BoxShadow(
                color: (widget.isListening
                        ? AppTheme.error
                        : AppTheme.greenAccent)
                    .withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              widget.isListening ? Icons.mic : Icons.mic_none,
              color: AppTheme.white,
              size: widget.size * 0.45,
            ),
          ),
        ),
      ),
    );
  }
}
