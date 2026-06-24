import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'motornauts/app_config.dart';
import 'motornauts/link_parser.dart';
import 'motornauts/motornauts_client.dart';
import 'screens/customer_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MotornautsApp(config: MotornautsConfig.fromEnvironment()));
}

class MotornautsApp extends StatefulWidget {
  const MotornautsApp({
    required this.config,
    this.client,
    this.enableLinkHandling = true,
    super.key,
  });

  final MotornautsConfig config;
  final MotornautsGateway? client;
  final bool enableLinkHandling;

  @override
  State<MotornautsApp> createState() => _MotornautsAppState();
}

class _MotornautsAppState extends State<MotornautsApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final MotornautsGateway _client =
      widget.client ?? MotornautsClient(config: widget.config);
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.enableLinkHandling) {
      _initLinks();
    }
  }

  Future<void> _initLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (!mounted || initial == null) {
        return;
      }
      _openLink(initial);
    } catch (_) {
      return;
    }

    _linkSubscription = appLinks.uriLinkStream.listen(_openLink);
  }

  void _openLink(Uri uri) {
    final parsed = parseMotornautsLink(uri);
    if (parsed == null) {
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => LinkDestinationScreen(client: _client, link: parsed),
      ),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Motornauts',
      theme: buildMotornautsTheme(Brightness.light),
      darkTheme: buildMotornautsTheme(Brightness.dark),
      home: BootstrapScreen(client: _client),
    );
  }
}
