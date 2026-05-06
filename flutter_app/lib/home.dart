import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api/teryaqi_api.dart';
import 'config/api_config.dart';
import 'auth.dart';
import 'medication_edit.dart';
import 'dart:ui';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int? _patientId;
  String? _fullName;
  List<Map<String, dynamic>> _medicines = [];
  int _takenCount = 0;
  int _missedCount = 0;
  int _pendingCount = 0;
  bool _busy = false;
  bool _prefsLoaded = false;

  TeryaqiApi get _api => TeryaqiApi(ApiConfig.baseUrl);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getInt('teryaqi_patient_id');
    _fullName = p.getString('teryaqi_full_name');
    setState(() {
      _patientId = id;
      _prefsLoaded = true;
    });
    if (id != null) {
      await _refreshMedicines();
    }
  }

  Future<void> _logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('teryaqi_patient_id');
    await p.remove('teryaqi_full_name');
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
    }
  }

  Future<void> _refreshMedicines() async {
    if (_patientId == null) return;
    setState(() => _busy = true);
    try {
      final list = await _api.getMedications(_patientId!);
      final stats = await _api.getDailyStats(_patientId!);
      
      int taken = int.tryParse(stats['taken'].toString()) ?? 0;
      int missed = int.tryParse(stats['missed'].toString()) ?? 0;
      
      // Calculate Pending
      int pending = 0;
      final now = DateTime.now();
      const phpDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final currentDay = phpDays[now.weekday - 1];
      
      for (var med in list) {
        bool isToday = false;
        final endDateStr = med['end_date']?.toString();
        final scheduleDays = med['schedule_days']?.toString();
        
        if (endDateStr == null || endDateStr.isEmpty) {
          isToday = true;
        } else {
          final end = DateTime.tryParse(endDateStr.split(' ')[0]);
          if (end != null) {
            final endPlusOne = end.add(const Duration(days: 1));
            if (!now.isAfter(endPlusOne)) {
              isToday = true;
            }
          } else {
            isToday = true; // fallback
          }
        }
        
        if (isToday && scheduleDays != null && scheduleDays.isNotEmpty) {
          if (!scheduleDays.contains(currentDay)) {
            isToday = false;
          }
        }
        
        final isTakenToday = (med['is_taken_today'] == 1 || med['is_taken_today'] == "1");
        if (isToday && !isTakenToday) {
          pending++;
        }
      }

      if (mounted) {
        setState(() {
          _medicines = list;
          _takenCount = taken;
          _missedCount = missed;
          _pendingCount = pending;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmIntake(int patientMedicationId) async {
    setState(() => _busy = true);
    try {
      await _api.decrementStock(patientMedicationId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأكيد الجرعة بنجاح')));
      await _refreshMedicines();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAddMedicationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMedicationSheet(
        patientId: _patientId!,
        api: _api,
        onAdded: _refreshMedicines,
        onNavigateToAlerts: (Map<String, dynamic> med) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => MedicationEditScreen(medication: med)));
        },
      ),
    );
  }

  Future<void> _downloadPDF(String filterVal) async {
    final urlStr = '${ApiConfig.baseUrl}/api/medications/generate_pdf_report.php?patient_id=$_patientId&pm_id=$filterVal';
    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
      }
    }
  }

  void _openReportModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        String selectedFilter = 'all';
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('📄 إنشاء تقرير طبي', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نطاق التقرير', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('جميع الأدوية')),
                      ..._medicines.map((m) {
                        return DropdownMenuItem(
                          value: m['patient_medication_id'].toString(),
                          child: Text(m['medication_name']?.toString() ?? 'دواء'),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      if (v != null) setStateDialog(() => selectedFilter = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadPDF(selectedFilter);
                  },
                  child: const Text('تحميل التقرير (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF065F46),
          title: Text(
            _currentIndex == 0 ? 'مرحباً، ${_fullName?.split(' ')[0] ?? "مريض"}' : 
            _currentIndex == 1 ? 'مركز التنبيهات' : 'الاحترازات الطبية', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'تقرير طبي',
              onPressed: _openReportModal,
            ),
            IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
          ],
        ),
        body: SafeArea(
          child: _busy && _medicines.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _currentIndex == 0
                  ? _buildHomeTab()
                  : _currentIndex == 1
                      ? _buildAlertsTab()
                      : _buildPrecautionsTab(),
        ),
        floatingActionButton: _currentIndex == 0
            ? FloatingActionButton.extended(
                onPressed: _showAddMedicationSheet,
                backgroundColor: const Color(0xFF0D9488),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('إضافة دواء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            : null,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          selectedItemColor: const Color(0xFF065F46),
          selectedFontSize: 16,
          unselectedFontSize: 14,
          iconSize: 32,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_active), label: 'التنبيهات'),
            BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'الاحترازات'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _refreshMedicines,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 25),
          const Text('الأدوية الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
          const SizedBox(height: 15),
          if (_medicines.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('لا توجد أدوية مسجلة', style: TextStyle(color: Colors.grey))))
          else
            ..._medicines.map((m) => _buildMedCard(m)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _statCard('إجمالي الأدوية', '${_medicines.length}', Colors.blue, Icons.medication),
        _statCard('في الانتظار', '$_pendingCount', Colors.orange, Icons.access_time),
        _statCard('تم تناوله', '$_takenCount', Colors.green, Icons.check_circle),
        _statCard('فائت', '$_missedCount', Colors.red, Icons.cancel),
      ],
    );
  }

  Widget _statCard(String title, String value, MaterialColor color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color[400], size: 24),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Text(value, style: TextStyle(color: color[700], fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMedCard(Map<String, dynamic> m) {
    final name = m['medication_name']?.toString() ?? '';
    final dose = m['dosage']?.toString() ?? m['dosage_amount']?.toString() ?? '';
    final timeStr = m['intake_time']?.toString() ?? '';
    final time = timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;
    final pmIdRaw = m['patient_medication_id'];
    final pmId = pmIdRaw is int ? pmIdRaw : int.tryParse(pmIdRaw.toString()) ?? 0;
    final isTakenToday = (m['is_taken_today'] == 1 || m['is_taken_today'] == "1");

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => MedicationEditScreen(medication: m)));
          _refreshMedicines();
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: const Color(0xFF0D9488).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.medication, color: Color(0xFF0D9488)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$dose | الوقت: $time', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (!isTakenToday)
                ElevatedButton(
                  onPressed: () => _confirmIntake(pmId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('أخذت الآن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                  child: const Text('تم الأخذ', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrecautionsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _precBox('1. ضغط الدم', '• مدرات البول: صباحاً لتجنب الأرق.\n• تجنب الجريب فروت مع العلاج.', Colors.blue),
        _precBox('2. خمول الغدة', '• الثايروكسين: فجراً على الريق.\n• فصل الكالسيوم عنه 4 ساعات.', Colors.purple),
        _precBox('3. السكري', '• الميتفورمين: بعد الأكل مباشرة.\n• فحص السكر قبل جرعة الأنسولين.', Colors.teal),
        _precBox('4. سيولة الدم', '• الالتزام بنفس الوقت يومياً.\n• مراقبة أي نزيف أو كدمات مفاجئة.', Colors.redAccent),
        _precBox('5. الكوليسترول', '• الستاتينات: تؤخذ مساءً للحصول على أفضل فعالية.\n• تقليل الأطعمة الدسمة والدهون.', Colors.orange),
        _precBox('6. الربو', '• استخدام البخاخ الواقي بانتظام.\n• المضمضة بعد استخدام بخاخ الكورتيزون.\n• حمل بخاخ الطوارئ دائماً.', Colors.cyan),
        _precBox('7. هشاشة العظام', '• تناول الكالسيوم مع الطعام لامتصاص أفضل.\n• البقاء بوضعية مستقيمة 30 دقيقة بعد أخذ الدواء.', Colors.indigo),
        _precBox('8. نقص الحديد', '• تناوله مع مصدر لفيتامين C لزيادة الامتصاص.\n• تجنب شرب الشاي أو القهوة لساعتين بعد الجرعة.', Colors.brown),
      ],
    );
  }

  Widget _buildAlertsTab() {
    if (_medicines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_active, size: 100, color: Color(0xFF0D9488)),
              SizedBox(height: 25),
              Text('مركز التنبيهات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
              SizedBox(height: 15),
              Text('لا توجد أدوية مسجلة حالياً لضبط تنبيهاتها.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey, height: 1.5)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('اختر الدواء لضبط إعدادات التنبيه المتقدمة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
        const SizedBox(height: 20),
        ..._medicines.map((m) {
          final name = m['medication_name']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0D9488).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.alarm, color: Color(0xFF0D9488)),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: const Text('اضغط لضبط المخزون وأيام التنبيه', style: TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => MedicationEditScreen(medication: m)));
                _refreshMedicines();
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _precBox(String t, String d, Color c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border(right: BorderSide(color: c, width: 6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)),
          const SizedBox(height: 5),
          Text(d, style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _AddMedicationSheet extends StatefulWidget {
  final int patientId;
  final TeryaqiApi api;
  final VoidCallback onAdded;
  final Function(Map<String, dynamic>) onNavigateToAlerts;

  const _AddMedicationSheet({required this.patientId, required this.api, required this.onAdded, required this.onNavigateToAlerts});

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _localNoteCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _diseaseType;
  bool _busy = false;

  final List<String> _diseases = [
    'مرض ضغط الدم',
    'خمول الغدة الدرقية',
    'هشاشة العظام',
    'ارتفاع الكوليسترول',
    'أمراض سيولة الدم',
    'المرض السكري النوع الثاني',
    'أخرى / عام'
  ];

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final dose = _doseCtrl.text.trim();
    if (name.isEmpty || dose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم الدواء والجرعة')));
      return;
    }

    setState(() => _busy = true);
    try {
      final disease = _diseaseType ?? '';
      final notes = _notesCtrl.text.trim();
      final instructionsParts = [];
      if (disease.isNotEmpty) instructionsParts.add('الحالة: $disease');
      if (notes.isNotEmpty) instructionsParts.add(notes);
      final instructions = instructionsParts.join('\n');

      final medId = await widget.api.createMedication(name: name, description: instructions);
      final today = DateTime.now().toIso8601String().split('T').first;
      final pmId = await widget.api.addForPatient(
        patientId: widget.patientId,
        medicationId: medId,
        dosageAmount: dose,
        instructions: instructions,
        startDate: today,
      );
      final hh = _selectedTime.hour.toString().padLeft(2, '0');
      final mm = _selectedTime.minute.toString().padLeft(2, '0');
      await widget.api.addSchedule(patientMedicationId: pmId, intakeTime: '$hh:$mm');
      
      if (mounted) {
        Navigator.pop(context);
        widget.onAdded();
        widget.onNavigateToAlerts({
          'patient_medication_id': pmId,
          'medication_id': medId,
          'medication_name': name,
          'dosage': dose,
          'intake_time': '$hh:$mm',
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إضافة دواء جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF065F46)), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: _localNoteCtrl, decoration: InputDecoration(labelText: 'ملاحظة محلية (اختياري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                  const SizedBox(height: 15),
                  TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'اكتب اسم الدواء', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                  const SizedBox(height: 15),
                  TextField(controller: _doseCtrl, decoration: InputDecoration(labelText: 'الجرعة (مثال: حبة واحدة - 500 ملغ)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                  const SizedBox(height: 15),
                  ListTile(
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(15)),
                    title: const Text('وقت التنبيه'),
                    trailing: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (t != null) setState(() => _selectedTime = t);
                    },
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _diseaseType,
                    decoration: InputDecoration(
                      labelText: 'الحالة المرضية',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    items: _diseases.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _diseaseType = v),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _notesCtrl, 
                    maxLines: 3, 
                    decoration: InputDecoration(
                      labelText: 'اكتب تعليمات الطبيب أو ملاحظاتك هنا...', 
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                    )
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: _busy ? const CircularProgressIndicator(color: Colors.white) : const Text('إضافة الدواء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
