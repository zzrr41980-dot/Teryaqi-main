import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart'; // تأكدي من النقطة والشرطة هنا

class MedicationWebView extends StatefulWidget {
  const MedicationWebView({super.key});

  @override
  State<MedicationWebView> createState() => _MedicationWebViewState();
}

class _MedicationWebViewState extends State<MedicationWebView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('http://10.0.2.2/Teryaqi-main/medications_list.html'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("قائمة الأدوية"), // بدون كلمة const هنا
        backgroundColor: Color(0xFF0D9488), // بدون كلمة const هنا
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}