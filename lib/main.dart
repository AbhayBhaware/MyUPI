import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyUPI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'MyUPI'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static const _channel =
      MethodChannel('com.example.myupi/notification_access');

  /// Whether notification access has been granted.
  /// Starts as null (unknown) so we don't show the dialog prematurely.
  bool? _notificationAccessEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check once at startup, after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when the user returns to the app (e.g., after visiting Settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccess();
    }
  }

  /// Calls the native MethodChannel and shows the dialog if access is off.
  Future<void> _checkAccess() async {
    try {
      final bool enabled =
          await _channel.invokeMethod<bool>('isNotificationAccessEnabled') ??
              false;
      if (!mounted) return;
      setState(() => _notificationAccessEnabled = enabled);
      if (!enabled) {
        _showPermissionDialog();
      }
    } on PlatformException catch (e) {
      debugPrint('MyUPI: isNotificationAccessEnabled error: $e');
    }
  }

  /// Opens Android Notification Access settings via the native channel.
  Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod('openNotificationAccessSettings');
    } on PlatformException catch (e) {
      debugPrint('MyUPI: openNotificationAccessSettings error: $e');
    }
  }

  /// Shows a one-time dialog explaining why notification access is needed.
  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined,
            size: 40, color: Colors.deepPurple),
        title: const Text('Notification Access Required'),
        content: const Text(
          'MyUPI needs notification access to detect UPI payment notifications '
          'and announce received payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payments_outlined, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 16),
            const Text(
              'MyUPI Soundbox',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Status indicator
            _buildAccessStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessStatus() {
    if (_notificationAccessEnabled == null) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: CircularProgressIndicator(),
      );
    }
    if (_notificationAccessEnabled!) {
      return const Chip(
        avatar: Icon(Icons.check_circle, color: Colors.green),
        label: Text('Notification Access: Enabled'),
      );
    }
    return Column(
      children: [
        const Chip(
          avatar: Icon(Icons.error_outline, color: Colors.red),
          label: Text('Notification Access: Disabled'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openSettings,
          icon: const Icon(Icons.settings),
          label: const Text('Open Notification Settings'),
        ),
      ],
    );
  }
}
