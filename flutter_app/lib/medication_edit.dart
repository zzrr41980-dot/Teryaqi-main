import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'api/teryaqi_api.dart';
import 'config/api_config.dart';
import 'services/notification_service.dart';

class MedicationEditScreen extends StatefulWidget {
  final Map<String, dynamic> medication;
  const MedicationEditScreen({super.key, required this.medication});

  @override
  State<MedicationEditScreen> createState() => _MedicationEditScreenState();
}

class _MedicationEditScreenState extends State<MedicationEditScreen> {
  late TextEditingController _doctorCtrl;
  late TextEditingController _clinicCtrl;

  DateTime? _endDate;
  final List<String> _daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final Map<String, String> _dayNamesAr = {
    'Sun': 'الأحد', 'Mon': 'الإثنين', 'Tue': 'الثلاثاء', 'Wed': 'الأربعاء',
    'Thu': 'الخميس', 'Fri': 'الجمعة', 'Sat': 'السبت'
  };
  final Set<String> _selectedDays = {};

  int _capacity = 0;
  int _currentStock = 0;
  
  TimeOfDay _alarmTime = const TimeOfDay(hour: 10, minute: 0);
  bool _voiceAlert = true;
  bool _remind15 = false;
  bool _remind30 = false;

  int _dosageValue = 1;
  String? _medCategory;

  bool _busy = false;

  TeryaqiApi get _api => TeryaqiApi(ApiConfig.baseUrl);

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _doctorCtrl = TextEditingController(text: m['doctor_name']?.toString() ?? '');
    _clinicCtrl = TextEditingController(text: m['clinic_name']?.toString() ?? '');
    
    _capacity = int.tryParse(m['total_capacity']?.toString() ?? '0') ?? 0;
    _currentStock = int.tryParse(m['current_stock']?.toString() ?? '0') ?? 0;

    final endDateStr = m['end_date']?.toString();
    if (endDateStr != null && endDateStr.isNotEmpty) {
      _endDate = DateTime.tryParse(endDateStr);
    }

    final sDays = m['schedule_days']?.toString() ?? '';
    if (sDays.isNotEmpty) {
      _selectedDays.addAll(sDays.split(',').map((e) => e.trim().replaceAll('"', '')));
    }

    final intake = m['intake_time']?.toString() ?? '';
    if (intake.isNotEmpty && intake.contains(':')) {
      final parts = intake.split(':');
      _alarmTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 10, minute: int.tryParse(parts[1]) ?? 0);
    }

    final dStr = m['dosage']?.toString() ?? m['dosage_amount']?.toString() ?? '1';
    _dosageValue = int.tryParse(dStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    if (_dosageValue < 1) _dosageValue = 1;
  }

  String _getDosageLabel() {
    if (_dosageValue == 1) return 'حبة';
    if (_dosageValue == 2) return 'حبتان';
    if (_dosageValue >= 3 && _dosageValue <= 10) return '$_dosageValue حبات';
    return '$_dosageValue حبة';
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final pmIdRaw = widget.medication['patient_medication_id'];
      final pmId = pmIdRaw is int ? pmIdRaw : int.parse(pmIdRaw.toString());
      
      // Update config API call
      // Note: We use updateConfig but might need to modify teryaqi_api.dart to support end_date if it wasn't there.
      // For now we map it exactly as required by UI parity.
      await _api.updateConfig(
        pmId: pmId,
        doctorName: _doctorCtrl.text.trim(),
        clinicName: _clinicCtrl.text.trim(),
        dosage: _dosageValue.toString(),
        treatmentDuration: _endDate != null ? _endDate!.toIso8601String().split('T').first : '',
        totalCapacity: _capacity.toString(),
        currentStock: _currentStock.toString(),
        daysOfWeekJson: '[${_selectedDays.map((d) => '"$d"').join(',')}]'
      );
      
      final updatedPayload = {
        'patient_medication_id': pmId,
        'medication_name': widget.medication['medication_name'],
        'dosage': _dosageValue.toString(),
        'intake_time': '${_alarmTime.hour.toString().padLeft(2, '0')}:${_alarmTime.minute.toString().padLeft(2, '0')}:00',
        'schedule_days': '[${_selectedDays.map((d) => '"$d"').join(',')}]',
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T').first,
      };

      await NotificationService().scheduleMedicationAlarm(updatedPayload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات المنبه بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF065F46).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF0D9488).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: const Color(0xFF0D9488), size: 24),
                ),
                const SizedBox(width: 15),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
              ],
            ),
            const SizedBox(height: 25),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF065F46)),
          title: const Text('إعدادات التنبيه المتقدمة', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // Schedule Card
                      _buildSectionCard(
                        title: 'الجدولة الزمنية',
                        icon: Icons.calendar_month_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تاريخ نهاية العلاج (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
                                if (d != null) setState(() => _endDate = d);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : 'تحديد التاريخ', style: TextStyle(fontSize: 16, color: _endDate != null ? Colors.black : Colors.grey)),
                                    const Icon(Icons.date_range, color: Color(0xFF0D9488)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            const Text('أيام الأسبوع', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 15),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _daysOfWeek.map((day) {
                                  final isSelected = _selectedDays.contains(day);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) _selectedDays.remove(day);
                                        else _selectedDays.add(day);
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(left: 10),
                                      width: 55,
                                      height: 55,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF0D9488) : Colors.grey[100],
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0D9488).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
                                      ),
                                      child: Center(
                                        child: Text(_dayNamesAr[day]!, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stock Management Card
                      _buildSectionCard(
                        title: 'إدارة المخزون',
                        icon: Icons.inventory_2_rounded,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('سعة العلبة الكلية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                      const SizedBox(height: 10),
                                      Container(
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16)),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, color: Colors.redAccent), 
                                              onPressed: () => setState(() { 
                                                if (_capacity > 0) {
                                                  _capacity--;
                                                  if (_currentStock > _capacity) _currentStock = _capacity;
                                                }
                                              })
                                            ),
                                            Expanded(child: Text('$_capacity', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                            IconButton(
                                              icon: const Icon(Icons.add, color: Color(0xFF0D9488)), 
                                              onPressed: () => setState(() { 
                                                _capacity++;
                                                if (_currentStock == 0 || _currentStock == _capacity - 1) {
                                                  _currentStock = _capacity;
                                                }
                                              })
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('الكمية المتبقية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 11),
                                        decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16)),
                                        child: Center(
                                          child: Text('$_currentStock', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            LinearProgressIndicator(
                              value: _capacity > 0 ? (_currentStock / _capacity).clamp(0.0, 1.0) : 0,
                              backgroundColor: Colors.grey[200],
                              color: (_currentStock / (_capacity == 0 ? 1 : _capacity)) < 0.2 ? Colors.redAccent : const Color(0xFF0D9488),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ),

                      // Alarm Settings Card
                      _buildSectionCard(
                        title: 'إعدادات المنبه',
                        icon: Icons.alarm_rounded,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () async {
                                final t = await showTimePicker(context: context, initialTime: _alarmTime);
                                if (t != null) setState(() => _alarmTime = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('وقت الجرعة الأساسي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    Text(_alarmTime.format(context), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            SwitchListTile(
                              title: const Text('إشعار صوتي واهتزاز', style: TextStyle(fontWeight: FontWeight.bold)),
                              activeColor: const Color(0xFF0D9488),
                              value: _voiceAlert,
                              onChanged: (v) => setState(() => _voiceAlert = v),
                            ),
                            const SizedBox(height: 15),
                            const Align(alignment: Alignment.centerRight, child: Text('تذكير إضافي قبل الموعد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _remind15 = !_remind15),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      decoration: BoxDecoration(
                                        color: _remind15 ? const Color(0xFF0D9488).withOpacity(0.1) : Colors.transparent,
                                        border: Border.all(color: _remind15 ? const Color(0xFF0D9488) : Colors.grey[300]!, width: 2),
                                        borderRadius: BorderRadius.circular(16)
                                      ),
                                      child: Center(child: Text('بـ 15 دقيقة', style: TextStyle(color: _remind15 ? const Color(0xFF0D9488) : Colors.grey, fontWeight: FontWeight.bold))),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _remind30 = !_remind30),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      decoration: BoxDecoration(
                                        color: _remind30 ? const Color(0xFF0D9488).withOpacity(0.1) : Colors.transparent,
                                        border: Border.all(color: _remind30 ? const Color(0xFF0D9488) : Colors.grey[300]!, width: 2),
                                        borderRadius: BorderRadius.circular(16)
                                      ),
                                      child: Center(child: Text('بـ 30 دقيقة', style: TextStyle(color: _remind30 ? const Color(0xFF0D9488) : Colors.grey, fontWeight: FontWeight.bold))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Prescription Details Card
                      _buildSectionCard(
                        title: 'تفاصيل الوصفة',
                        icon: Icons.receipt_long_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الجرعة المقررة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                children: [
                                  IconButton(icon: const Icon(Icons.remove, color: Colors.redAccent), onPressed: () => setState(() { if (_dosageValue > 1) _dosageValue--; })),
                                  Expanded(child: Text(_getDosageLabel(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                  IconButton(icon: const Icon(Icons.add, color: Color(0xFF0D9488)), onPressed: () => setState(() => _dosageValue++)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _medCategory,
                              decoration: InputDecoration(labelText: 'تصنيف الدواء', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                              items: ['مضاد حيوي', 'مسكن', 'فيتامينات', 'ضغط / سكري'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                              onChanged: (v) => setState(() => _medCategory = v),
                            ),
                            const SizedBox(height: 20),
                            TextField(controller: _doctorCtrl, decoration: InputDecoration(labelText: 'اسم الطبيب المعالج', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                            const SizedBox(height: 20),
                            TextField(controller: _clinicCtrl, decoration: InputDecoration(labelText: 'العيادة / المركز', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              // Fixed Bottom Bar for Save
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                ),
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _busy ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ التنبيه والإعدادات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
