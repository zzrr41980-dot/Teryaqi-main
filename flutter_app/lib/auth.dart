import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/teryaqi_api.dart';
import 'config/api_config.dart';
import 'home.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  void _showSettingsDialog() {
    final ctrl = TextEditingController(text: ApiConfig.savedIp);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعدادات الاتصال', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'رقم الخادم (IP)', 
              hintText: 'مثال: 192.168.1.5',
              border: OutlineInputBorder()
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                await ApiConfig.setHostIp(ctrl.text);
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _showSettingsDialog),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF065F46), Color(0xFF0D9488)],
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1000),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, val, child) {
                return Opacity(
                  opacity: val,
                  child: Transform.translate(
                    offset: Offset(0, 40 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logotregy.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 30),
                  const Text('تِرياقي', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  const Text('نظام مراقبة الدواء الذكي', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF065F46),
                        elevation: 8,
                        shadowColor: Colors.black45,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('إنشاء حساب مجاني', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;

  TeryaqiApi get _api => TeryaqiApi(ApiConfig.baseUrl);

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال البريد وكلمة المرور')));
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await _api.login(email, pass);
      final pidRaw = data['patient_id'];
      final pid = pidRaw is int ? pidRaw : int.parse(pidRaw.toString());
      final p = await SharedPreferences.getInstance();
      await p.setInt('teryaqi_patient_id', pid);
      if (data['full_name'] != null) {
        await p.setString('teryaqi_full_name', data['full_name'].toString());
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (r) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF0D9488)],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - val)),
                      child: child,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/logotregy.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          const Text('تسجيل الدخول', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 40),
                          _buildField('البريد الإلكتروني', _emailCtrl, false),
                          const SizedBox(height: 15),
                          _buildField('كلمة المرور', _passwordCtrl, true),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _busy ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D9488),
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _busy ? const CircularProgressIndicator(color: Color(0xFF0D9488)) : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool obscure) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _gender;
  bool _busy = false;

  TeryaqiApi get _api => TeryaqiApi(ApiConfig.baseUrl);

  Future<void> _register() async {
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الجنس')));
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await _api.register(
        fullName: _nameCtrl.text.trim(),
        nationalId: _idCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        gender: _gender!,
      );
      final pidRaw = data['patient_id'];
      final pid = pidRaw is int ? pidRaw : int.parse(pidRaw.toString());
      final p = await SharedPreferences.getInstance();
      await p.setInt('teryaqi_patient_id', pid);
      await p.setString('teryaqi_full_name', _nameCtrl.text.trim());
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (r) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF0D9488)],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - val)),
                      child: child,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          const Text('إنشاء حساب', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 30),
                          _buildField('الاسم الكامل', _nameCtrl, false),
                          const SizedBox(height: 15),
                          _buildField('رقم الهوية', _idCtrl, false),
                          const SizedBox(height: 15),
                          _buildField('البريد الإلكتروني', _emailCtrl, false),
                          const SizedBox(height: 15),
                          _buildField('كلمة المرور', _passwordCtrl, true),
                          const SizedBox(height: 15),
                          DropdownButtonFormField<String>(
                            value: _gender,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            ),
                            hint: const Text('الجنس', style: TextStyle(color: Colors.grey)),
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('ذكر')),
                              DropdownMenuItem(value: 'Female', child: Text('أنثى')),
                            ],
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _busy ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D9488),
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _busy ? const CircularProgressIndicator(color: Color(0xFF0D9488)) : const Text('تسجيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool obscure) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}
