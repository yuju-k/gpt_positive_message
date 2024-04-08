import 'package:flutter/material.dart';

class ModeOnOffWidget extends StatefulWidget {
  final bool originalMessageCheckMode;
  final bool isConvertMessageCheckMode;
  final Function(bool) onOriginalMessageCheckModeChanged;
  final Function(bool) onConvertMessageCheckModeChanged;

  const ModeOnOffWidget({
    super.key,
    required this.originalMessageCheckMode,
    required this.isConvertMessageCheckMode,
    required this.onOriginalMessageCheckModeChanged,
    required this.onConvertMessageCheckModeChanged,
  });

  @override
  _ModeOnOffWidgetState createState() => _ModeOnOffWidgetState();
}

class _ModeOnOffWidgetState extends State<ModeOnOffWidget> {
  late bool _originalMessageCheckMode;
  late bool _isConvertMessageCheckMode;

  @override
  void initState() {
    super.initState();
    _originalMessageCheckMode = widget.originalMessageCheckMode;
    _isConvertMessageCheckMode = widget.isConvertMessageCheckMode;
  }

  @override
  Widget build(BuildContext context) {
    // ... (모드 온오프 위젯 구현 생략)
  }
}
