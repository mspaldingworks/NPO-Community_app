import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LglFormScreen extends StatefulWidget {
  const LglFormScreen({super.key});

  @override
  State<LglFormScreen> createState() => _LglFormScreenState();
}

class _LglFormScreenState extends State<LglFormScreen> {
  late final WebViewController _controller;
  late final Future<void> Function() _loadContent;
  bool _isLoading = true;
  bool _hasError = false;
  bool _submissionHandled = false;

  static const String lglUrl =
      'https://secure.lglforms.com/form_engine/s/JkulULHA0HCSezvMXHlzxg';
  static const String? embedHtml = null;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final handled = _handlePotentialSuccess(
              request.url,
              isMainFrame: request.isMainFrame,
            );
            if (handled) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (_submissionHandled || !mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            if (_submissionHandled || !mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (_submissionHandled || !mounted) {
              return;
            }
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Load error. Check connection.'),
              ),
            );
          },
        ),
      );

    _loadContent = embedHtml != null
        ? () => _controller.loadHtmlString(embedHtml!)
        : () => _controller.loadRequest(Uri.parse(lglUrl));

    _loadContent();
  }

  bool _handlePotentialSuccess(String url, {required bool isMainFrame}) {
    if (_submissionHandled || !isMainFrame || url.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? url.toLowerCase();
    final isThankYou = path.contains('thank-you') || path.contains('thankyou');
    if (!isThankYou) {
      return false;
    }

    _submissionHandled = true;
    if (!mounted) {
      return true;
    }

    context.pop(true);
    return true;
  }

  void _retry() {
    if (_submissionHandled) {
      return;
    }
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _loadContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form')),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Something went wrong while loading the form.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            WebViewWidget(controller: _controller),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
