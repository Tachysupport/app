import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'widgets/incoming_call_modal.dart';

void main() {
  runApp(const OverlayApp());
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  String callerName = 'Assistant';
  String callType = 'schedule';
  String audioBrief = '';

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        setState(() {
          callerName = data['callerName'] ?? 'Assistant';
          callType = data['callType'] ?? 'schedule';
          audioBrief = data['audioBrief'] ?? '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: IncomingCallModal(
        callerName: callerName,
        callType: callType,
        audioBrief: audioBrief,
        onEndCall: () async {
          await FlutterOverlayWindow.closeOverlay();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
