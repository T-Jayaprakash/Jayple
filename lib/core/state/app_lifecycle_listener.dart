import 'package:flutter/widgets.dart';

class AppResumeListener extends StatefulWidget {
  final Widget child;
  final VoidCallback onAppResumed;

  const AppResumeListener({
    super.key,
    required this.child,
    required this.onAppResumed,
  });

  @override
  State<AppResumeListener> createState() => _AppResumeListenerState();
}

class _AppResumeListenerState extends State<AppResumeListener> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only detect when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      widget.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
