import 'package:flutter/widgets.dart';

class AppLifecycleListener extends StatefulWidget {
  final Widget child;
  final VoidCallback onAppResumed;

  const AppLifecycleListener({
    super.key,
    required this.child,
    required this.onAppResumed,
  });

  @override
  State<AppLifecycleListener> createState() => _AppLifecycleListenerState();
}

class _AppLifecycleListenerState extends State<AppLifecycleListener> with WidgetsBindingObserver {
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
