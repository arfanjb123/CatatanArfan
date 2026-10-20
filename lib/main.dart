import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _wa = ['com.whatsapp', 'com.whatsapp.w4b'];

// Dipanggil setiap ada notifikasi, juga saat aplikasi tertutup.
@pragma('vm:entry-point')
void notifCallback(NotificationEvent e) async {
  if (!_wa.contains(e.packageName)) return;
  final p = await SharedPreferences.getInstance();
  await p.reload();
  final f = (p.getString('filter') ?? '').trim().toLowerCase();
  final title = (e.title ?? '').toLowerCase();
  final text = e.text ?? '';
  if (f.isEmpty || text.isEmpty || !title.contains(f)) return;
  final box = p.getStringList('inbox') ?? <String>[];
  box.add(jsonEncode({'x': text, 'k': DateTime.now().millisecondsSinceEpoch}));
  await p.setStringList('inbox', box);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await NotificationsListener.initialize(callbackHandle: notifCallback);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Home()));
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  late final WebViewController c;
  Timer? _t;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Kelas', onMessageReceived: _pesan)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _ready = true;
          _cek();
          _flush();
        },
        onNavigationRequest: (r) {
          if (r.url.startsWith('http')) {
            launchUrl(Uri.parse(r.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadFlutterAsset('assets/index.html');
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _flush());
  }

  @override
  void dispose() {
    _t?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _cek();
      _flush();
    }
  }

  Future<void> _pesan(JavaScriptMessage m) async {
    final d = jsonDecode(m.message);
    if (d['a'] == 'aktif') {
      final p = await SharedPreferences.getInstance();
      await p.setString('filter', (d['f'] ?? '').toString());
      if (!await _cek()) await NotificationsListener.openPermissionSettings();
    }
  }

  Future<bool> _cek() async {
    final ok = await NotificationsListener.hasPermission ?? false;
    if (ok && !(await NotificationsListener.isRunning ?? false)) {
      await NotificationsListener.startService(foreground: false);
    }
    if (_ready) await c.runJavaScript('window.statusIzin&&window.statusIzin($ok)');
    return ok;
  }

  Future<void> _flush() async {
    if (!_ready) return;
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final box = p.getStringList('inbox') ?? <String>[];
    if (box.isEmpty) return;
    await p.setStringList('inbox', <String>[]);
    final js = jsonEncode(box.map(jsonDecode).toList());
    await c.runJavaScript('window.masukInfo&&window.masukInfo($js)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: WebViewWidget(controller: c),
    );
  }
}
