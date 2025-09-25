import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/tts_service.dart';

class IncomingCallModal extends StatefulWidget {
  final String callerName;
  final String callType; // 'schedule' or 'event'
  final String audioBrief;
  final VoidCallback? onEndCall;

  const IncomingCallModal({
    super.key,
    required this.callerName,
    required this.callType,
    required this.audioBrief,
    this.onEndCall,
  });

  @override
  State<IncomingCallModal> createState() => _IncomingCallModalState();
}

class _IncomingCallModalState extends State<IncomingCallModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPlaying = false;
  bool _hasError = false;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _controller.forward();
    // Delay audio start slightly to allow animation to begin
    Future.delayed(const Duration(milliseconds: 300), _playAudio);
  }

  Future<void> _playAudio() async {
    if (!_mounted) return;

    try {
      setState(() {
        _isPlaying = true;
        _hasError = false;
      });

      // Check if we have a briefing to play
      if (widget.audioBrief.trim().isEmpty) {
        setState(() {
          _isPlaying = false;
          _hasError = true;
        });
        return;
      }

      await TtsService.speak(widget.audioBrief);

      if (!_mounted) return;
      setState(() => _isPlaying = false);
    } catch (e) {
      if (!_mounted) return;
      setState(() {
        _isPlaying = false;
        _hasError = true;
      });
    }
  }

  Future<void> _endCall() async {
    try {
      // Stop any ongoing TTS
      await TtsService.stop();

      // Trigger the callback if provided
      widget.onEndCall?.call();

      // Only pop if we're still mounted
      if (_mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Ensure we at least close the modal even if cleanup fails
      if (_mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _mounted = false;
    // Ensure TTS is stopped before disposing animation
    TtsService.stop().then((_) {
      _controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent accidental dismissal with back button
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.85),
        body: SafeArea(
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutBack,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated ringing effect
                  if (_isPlaying)
                    SizedBox(
                      height: 180,
                      child: Lottie.asset(
                        'assets/animations/ringing.json',
                        repeat: true,
                      ),
                    )
                  else
                    const SizedBox(height: 180),
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: _hasError
                        ? Colors.redAccent
                        : Colors.blueAccent,
                    child: Icon(
                      _hasError ? Icons.error_outline : Icons.person,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.callType == 'schedule'
                        ? 'Daily Schedule Call'
                        : 'Event Call',
                    style: const TextStyle(fontSize: 18, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _getStatusWidget(),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        icon: const Icon(Icons.call_end, color: Colors.white),
                        label: const Text(
                          'End Call',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                        onPressed: _endCall,
                      ),
                      if (_hasError) ...[
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            'Retry',
                            style: TextStyle(fontSize: 20, color: Colors.white),
                          ),
                          onPressed: _playAudio,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getStatusWidget() {
    if (_hasError) {
      return const Text(
        'Failed to play audio briefing',
        style: TextStyle(color: Colors.redAccent, fontSize: 16),
      );
    }
    if (_isPlaying) {
      return const Text(
        'Playing audio briefing...',
        style: TextStyle(color: Colors.greenAccent, fontSize: 16),
      );
    }
    return const Text(
      'Audio briefing ended.',
      style: TextStyle(color: Colors.white70, fontSize: 16),
    );
  }
}
