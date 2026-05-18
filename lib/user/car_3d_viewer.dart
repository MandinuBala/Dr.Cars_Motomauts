import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dr_cars_fyp/auth/auth_service.dart';

class Car3DViewerPage extends StatefulWidget {
  final String brand;
  final String model;
  const Car3DViewerPage({super.key, required this.brand, required this.model});

  @override
  State<Car3DViewerPage> createState() => _Car3DViewerPageState();
}

class _Car3DViewerPageState extends State<Car3DViewerPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  // Use environment config or const — never hardcode a local IP
  static const String _baseUrl = String.fromEnvironment(
    'MODEL_SERVER_URL',
    defaultValue: 'https://drcars-fyp-production.up.railway.app',
  );

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) => _injectVars(),
              onWebResourceError: (error) {
                if (mounted)
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                  });
              },
            ),
          )
          ..loadFlutterAsset('assets/html/car_viewer.html');
  }

  Future<void> _injectVars() async {
    try {
      // Sanitize inputs to prevent JS injection
      final brand = widget.brand.replaceAll('"', '');
      final model = widget.model.replaceAll('"', '');
      await _controller.runJavaScript('''
        try {
          window.BRAND = "$brand";
          window.MODEL = "$model";
          window.BASE_URL = "$_baseUrl";
          if (typeof initViewer === "function") initViewer();
        } catch(e) {
          console.error("initViewer failed:", e);
        }
      ''');
    } catch (e) {
      debugPrint('JS injection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.brand} · ${widget.model}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load 3D model',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else if (_isLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white54),
                    SizedBox(height: 16),
                    Text(
                      'LOADING 3D MODEL',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
