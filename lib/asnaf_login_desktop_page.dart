import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AsnafLoginDesktopPage extends StatefulWidget {
  const AsnafLoginDesktopPage({super.key});

  @override
  State<AsnafLoginDesktopPage> createState() => _AsnafLoginDesktopPageState();
}

class _AsnafLoginDesktopPageState extends State<AsnafLoginDesktopPage> {
  InAppWebViewController? _controller;
  bool _busy = false;
  String? _lastUrl;
  String? _error;

  Future<void> _extractToken() async {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final js = '''
(() => {
  const candidates = ['token', 'access_token', 'Authorization', 'authorization', 'jwt', 'authToken'];
  const storage = window.localStorage || {};
  let selected = '';
  for (const k of candidates) {
    const v = storage.getItem(k);
    if (v && v.trim()) { selected = v.trim(); break; }
  }
  if (!selected) {
    for (let i = 0; i < storage.length; i++) {
      const k = storage.key(i);
      const v = storage.getItem(k);
      if (!k || !v) continue;
      const lk = k.toLowerCase();
      if (lk.includes('token') || lk.includes('auth') || lk.includes('jwt')) {
        selected = v.trim();
        break;
      }
    }
  }
  if (selected.toLowerCase().startsWith('bearer ')) {
    selected = selected.substring(7).trim();
  }
  if (selected.toLowerCase().startsWith('jwt ')) {
    selected = selected.substring(4).trim();
  }
  return JSON.stringify({ token: selected });
})();
''';
      final raw = await c.evaluateJavascript(source: js);
      final text = raw?.toString() ?? '';
      final decoded = jsonDecode(text);
      final token = (decoded is Map ? decoded['token'] : null)?.toString().trim() ?? '';
      if (token.isEmpty) {
        setState(() => _error = 'توکن پیدا نشد. ابتدا داخل سایت لاگین کنید.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(token);
    } catch (e) {
      setState(() => _error = 'خطا در استخراج توکن: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ورود به اسناف و استخراج JWT'),
        actions: [
          IconButton(
            tooltip: 'استخراج توکن',
            onPressed: _busy ? null : _extractToken,
            icon: const Icon(Icons.key_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _lastUrl == null ? 'آماده ورود...' : 'URL: $_lastUrl',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _extractToken,
                  icon: const Icon(Icons.login),
                  label: const Text('استخراج JWT'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('https://iranianasnaf.ir/')),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStop: (controller, url) {
                setState(() => _lastUrl = url?.toString());
              },
            ),
          ),
        ],
      ),
    );
  }
}
