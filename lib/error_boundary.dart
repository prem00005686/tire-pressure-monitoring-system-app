import 'package:flutter/material.dart';
import 'app_theme.dart';

class _ErrorBoundary extends StatefulWidget {
  final Widget child;
  const _ErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  __ErrorBoundaryState createState() => __ErrorBoundaryState();
}

class __ErrorBoundaryState extends State<_ErrorBoundary> {
  Object? _lastError;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      setState(() => _lastError = details.exception);
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_lastError != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text('A recoverable error occurred', style: TextStyle(color: AppTheme.onBackground)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() => _lastError = null);
                },
                child: const Text('Return Home'),
              )
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

// Expose as widget for main to use
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  const ErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) => _ErrorBoundary(child: child);
}
