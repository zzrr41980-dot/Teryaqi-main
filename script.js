// ═══════════════════════════════════════════════════════
// تِرياقي — Dashboard Logic
// Depends on: api-config.js, auth.js (loaded before this)
// ═══════════════════════════════════════════════════════

/* ── Medication API Calls ──────────────────────────── */

async function apiListMedications(patientId) {
  const res = await fetch(apiUrl('/api/medications/get_for_patient.php?patient_id=' + encodeURIComponent(patientId)));
  const data = await parseJson(res);
  if (!res.ok) throw new Error(data.message || 'تعذر جلب الأدوية');
  return Array.isArray(data) ? data : [];
}

/* ── Capacity Stepper ──────────────────────────────── */

window.adjustCapacity = function (delta) {
  const display = document.getElementById('capacity-display');
  const hidden = document.getElementById('total-capacity');
  if (!display || !hidden) return;
  let val = parseInt(display.value || display.textContent, 10) || 0;
  val = Math.max(0, val + delta);
  if (display.tagName === 'INPUT') display.value = val;
  else display.textContent = val;
  hidden.value = val;
};

window.updateDosageLabel = function (value) {
  if (value === 1) return "حبة";
  if (value === 2) return "2 حبة";
  if (value >= 3 && value <= 10) return value + " حبات";
  return value + " حبة";
};

window.adjustDosage = function (delta) {
  const hidden = document.getElementById('dosage-value');
  const display = document.getElementById('dosage-display');
  if (!hidden || !display) return;

  let val = parseInt(hidden.value, 10) || 1;
  val = Math.max(1, val + delta);

  hidden.value = val;
  display.innerText = updateDosageLabel(val);
};
async function apiCreateMedication(name, dosageForm, strength, description) {
  const res = await fetch(apiUrl('/api/medications/create_medications.php'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      medication_name: name,
      dosage_form: dosageForm,
      strength: strength || '',
      description: description || '',
    }),
  });
  const data = await parseJson(res);
  if (!res.ok) throw new Error(data.message || 'تعذر إنشاء الدواء');
  return data.medication_id;
}

async function apiAddForPatient(patientId, medicationId, dosageAmount, instructions, startDate) {
  const res = await fetch(apiUrl('/api/medications/add_for_patient.php'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      patient_id: patientId,
      medication_id: medicationId,
      dosage_amount: dosageAmount,
      start_date: startDate || undefined,
      instructions: instructions || '',
    }),
  });
  const data = await parseJson(res);
  if (!res.ok) throw new Error(data.message || 'تعذر ربط الدواء بالمريض');
  return data.patient_medication_id;
}

async function apiAddSchedule(patientMedicationId, intakeTime) {
  const t = intakeTime.length === 5 ? intakeTime + ':00' : intakeTime;
  const res = await fetch(apiUrl('/api/medications/add_schedule.php'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      patient_medication_id: patientMedicationId,
      intake_time: t,
      frequency_per_day: 1,
    }),
  });
  const data = await parseJson(res);
  if (!res.ok) throw new Error(data.message || 'تعذر حفظ وقت الجرعة');
  return data;
}

/* ── Dashboard KPI ─────────────────────────────────── */

async function fetchDailyStatistics(patientId) {
  try {
    const res = await fetch(apiUrl('/api/medications/get_daily_stats.php?patient_id=' + patientId));
    if (!res.ok) return;
    const data = await parseJson(res);

    const taken = parseInt(data.taken) || 0;
    const missed = parseInt(data.missed) || 0;

    const takenEl = document.getElementById('taken-count');
    const missedEl = document.getElementById('missed-count');
    const pendingEl = document.getElementById('pending-count');

    if (takenEl) takenEl.innerText = taken;
    if (missedEl) missedEl.innerText = missed;

    if (pendingEl) {
      const todayAbbr = new Date().toLocaleDateString('en-US', { weekday: 'short' });
      let pendingCount = 0;

      medicines.forEach(med => {
        let isToday = false;

        if (!med.schedule_days) {
          isToday = true;
        } else {
          const daysArr = med.schedule_days.split(',');
          if (daysArr.includes(todayAbbr)) {
            isToday = true;
          }
        }

        if (med.end_date) {
          const end = new Date(med.end_date);
          const today = new Date();
          end.setHours(0, 0, 0, 0);
          today.setHours(0, 0, 0, 0);
          if (today > end) {
            isToday = false;
          }
        }

        if (isToday && med.is_taken_today == 0) {
          pendingCount++;
        }
      });

      pendingEl.innerText = pendingCount;
    }
  } catch (e) {
    console.error('Failed to load temporal statistics', e);
  }
}

/* ── Medicine State ────────────────────────────────── */

let medicines = [];

function formatTimeDisplay(t) {
  if (!t) return '—';
  const s = String(t);
  return s.length >= 5 ? s.slice(0, 5) : s;
}

function updateStats() {
  const total = medicines.length;
  const totalEl = document.getElementById('total-medicines');
  if (totalEl) totalEl.textContent = total;

  const pid = getPatientId();
  if (pid) fetchDailyStatistics(pid);
}

function renderMedicines() {
  const container = document.getElementById('medicines-list');

  if (!medicines.length) {
    container.innerHTML =
      '<div id="empty-state" class="text-center py-20 flex flex-col items-center gap-4">' +
      '<div class="text-6xl opacity-20">📋</div>' +
      '<p class="text-gray-400 font-medium">لا توجد أدوية مسجلة حالياً</p>' +
      '</div>';
    return;
  }

  container.innerHTML = medicines
    .map(function (med) {
      const disease = (med.instructions || '').split('\n')[0] || '';
      const notes = med.instructions || '';
      return (
        '<div onclick="window.location.href=\'medications_list.html?pmId=' + med.patient_medication_id + '&name=' + encodeURIComponent(med.medication_name) + '\'" class="p-4 mb-3 rounded-2xl bg-white shadow-sm border-r-8 border-emerald-500 flex flex-col gap-2 cursor-pointer hover:bg-emerald-50 transition">' +
        '<div class="flex justify-between items-start">' +
        '<div>' +
        '<h3 class="font-bold text-gray-800">' + (med.medication_name || '') + '</h3>' +
        '<p class="text-[10px] text-gray-500">' + (med.dosage_amount || med.dosage || '') + (med.strength ? ' — ' + med.strength : '') + '</p>' +
        '</div>' +
        '<div class="text-left font-bold text-emerald-600 text-sm">' + formatTimeDisplay(med.intake_time) + '</div>' +
        '</div>' +
        (disease
          ? '<span class="text-[9px] w-fit px-2 py-0.5 rounded-full bg-blue-50 text-blue-600 font-bold">' + disease + '</span>'
          : '') +
        '<div class="bg-gray-50 p-2 rounded-lg border-t mt-1">' +
        '<p class="text-[10px] text-emerald-800 leading-relaxed font-bold italic">📝 ملاحظات: ' + (notes || 'لا توجد') + '</p>' +
        '</div>' +
        '</div>'
      );
    })
    .join('');
}

function showError(msg) {
  const el = document.getElementById('api-error');
  if (el) {
    el.textContent = msg || '';
    el.classList.toggle('hidden', !msg);
    if (msg) setTimeout(() => el.classList.add('hidden'), 5000);
  } else if (msg) {
    alert(msg);
  }
}

async function refreshMedicines() {
  const pid = getPatientId();
  const isNotificationCenter = window.location.pathname.includes('medications_list.html');
  if (!pid) {
    medicines = [];
    if (isNotificationCenter) renderNotifications();
    else { renderMedicines(); updateStats(); }
    return;
  }
  try {
    showError('');
    medicines = await apiListMedications(pid);
    if (isNotificationCenter) {
      renderNotifications();
      if (window.activeMedicationId) populateEditForm(window.activeMedicationId);
    } else {
      renderMedicines();
      updateStats();
    }
  } catch (e) {
    showError(e.message);
  }
}

window.populateEditForm = function (pmId) {
  const med = medicines.find(m => m.patient_medication_id == pmId);
  if (!med) return;

  const el = (id) => document.getElementById(id);

  if (el('treatment-end-date')) {
    el('treatment-end-date').value = med.end_date ? med.end_date.split(' ')[0] : '';
    if (typeof calcRemainingDays === 'function') calcRemainingDays();
  }

  if (el('med-name')) el('med-name').value = med.medication_name || '';

  if (el('total-capacity')) {
    el('total-capacity').value = med.total_capacity ?? 0;
  }
  if (el('capacity-display')) {
    el('capacity-display').value = med.total_capacity ?? 0;
  }

  if (el('pills-count')) {
    const stock = med.current_stock ?? (med.total_capacity ?? 0);
    el('pills-count').innerText = stock;
    const progressFill = el('pills-progress');
    const cap = med.total_capacity ?? 0;
    if (progressFill && cap > 0) {
      const percentage = Math.min(100, Math.max(0, (stock / cap) * 100));
      progressFill.style.width = percentage + '%';
    } else if (progressFill) {
      progressFill.style.width = '0%';
    }
  }

  if (el('main-alarm-time')) {
    el('main-alarm-time').value = med.intake_time ? med.intake_time.substring(0, 5) : '10:00';
  }

  const dosageValRaw = med.dosage || med.dosage_amount || 1;
  const numericDosage = parseInt(dosageValRaw, 10) || 1;
  if (el('dosage-value')) {
    el('dosage-value').value = numericDosage;
  }
  if (el('dosage-display')) {
    el('dosage-display').innerText = updateDosageLabel(numericDosage);
  }
  if (el('doctor-name')) el('doctor-name').value = med.doctor_name || '';
  if (el('clinic-name')) el('clinic-name').value = med.clinic_name || '';

  if (med.schedule_days) {
    const daysArr = med.schedule_days.split(',');
    document.querySelectorAll('.day-checkbox').forEach(cb => {
      cb.checked = daysArr.includes(cb.value);
    });
  } else {
    document.querySelectorAll('.day-checkbox').forEach(cb => cb.checked = false);
  }
};

/* ── Page Initialization ───────────────────────────── */

document.addEventListener('DOMContentLoaded', function () {
  const isNotificationCenter = window.location.pathname.includes('medications_list.html');

  // Notification Center deep-link handling
  if (isNotificationCenter) {
    const urlParams = new URLSearchParams(window.location.search);
    const pmId = urlParams.get('pmId');
    const medName = urlParams.get('name');
    if (pmId) {
      window.activeMedicationId = pmId;
      const medNameInput = document.getElementById('med-name');
      if (medNameInput && medName) {
        medNameInput.value = medName;
      }
    }
  }

  // Dashboard: Set greeting name
  const greetingEl = document.getElementById('greeting-name');
  if (greetingEl) {
    greetingEl.textContent = 'مرحباً، ' + (getPatientName() || 'مستخدم');
  }

  // Dashboard: Logout logic moved to global scope
  window.logoutUser = function () {
    clearSession();
    window.location.href = 'landing.html';
  };

  // Dashboard: Medication form submit
  const medicineForm = document.getElementById('medicine-form');
  if (medicineForm) {
    medicineForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      const pid = getPatientId();
      if (!pid) {
        showError('سجّل الدخول أولاً.');
        return;
      }

      const medName = document.getElementById('medicine-name').value.trim();
      const dosage = document.getElementById('dosage').value.trim();
      const timeVal = document.getElementById('medicine-time').value;
      const disease = document.getElementById('disease-type').value;
      const notes = document.getElementById('personal-notes').value.trim();
      const instructions = [disease ? 'الحالة: ' + disease : '', notes].filter(Boolean).join('\n');

      try {
        showError('');
        const medId = await apiCreateMedication(medName, 'Tablet', '', instructions);
        const pmId = await apiAddForPatient(pid, medId, dosage, instructions, new Date().toISOString().slice(0, 10));
        await apiAddSchedule(pmId, timeVal);
        await refreshMedicines();
        e.target.reset();
        window.location.href = "medications_list.html?pmId=" + pmId + "&name=" + encodeURIComponent(medName);
      } catch (err) {
        showError(err.message);
      }
    });
  }

  // Load KPI stats and medications
  refreshMedicines();
});

/* ── Notification Center Functions ─────────────────── */

function renderNotifications() {
  const container = document.getElementById('missed-alarms-list');
  if (!container) return;

  let medsToRender = medicines;
  if (window.activeMedicationId) {
    medsToRender = medicines.filter(m => m.patient_medication_id == window.activeMedicationId);
  }

  if (!medsToRender.length) {
    container.innerHTML = '<p class="text-center text-sm text-emerald-800 font-bold py-10 bg-emerald-50 rounded-[24px] border border-emerald-100">✅ تفقدت جميع أدويتك بنجاح!</p>';
    return;
  }

  container.innerHTML = medsToRender.map(med => {
    let timeStr = formatTimeDisplay(med.intake_time);
    if (!med.intake_time) timeStr = '—';

    if (med.is_taken_today == 1) {
      return `
        <div class="p-5 bg-green-50 rounded-[24px] border border-green-100 flex items-center justify-between shadow-sm opacity-60">
            <div class="flex items-center gap-4">
                <div class="w-12 h-12 bg-white rounded-2xl flex items-center justify-center text-xl shadow-sm">✅</div>
                <div>
                  <p class="text-xs font-bold text-green-900">تم أخذ ` + (med.medication_name || 'الدواء') + `</p>
                  <p class="text-[9px] text-green-600">تم تسجيل الجرعة بنجاح</p>
                </div>
            </div>
            <span class="text-green-700 text-[10px] px-4 py-2.5 font-bold">مكتمل</span>
        </div>`;
    }

    return `
    <div class="p-5 bg-red-50 rounded-[24px] border border-red-100 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-4">
            <div class="w-12 h-12 bg-white rounded-2xl flex items-center justify-center text-xl shadow-sm">⚠️</div>
            <div>
              <p class="text-xs font-bold text-red-900">لم يتم أخذ ` + (med.medication_name || 'الدواء') + `</p>
              <p class="text-[9px] text-red-500">الجرعة المقررة في: ` + timeStr + `</p>
            </div>
        </div>
        <button onclick="confirmTaken(this)" data-pm-id="` + (med.patient_medication_id || '') + `" class="bg-red-600 text-white text-[10px] px-4 py-2.5 rounded-xl font-bold active:scale-95 transition-all">أخذت الآن</button>
    </div>`;
  }).join('');
}

/* ── Advanced Config (Notifications Page) ──────────── */

window.saveToDatabase = async function () {
  if (!window.activeMedicationId) {
    alert("الرجاء إضافة الدواء أولاً للوصول لهذه الإعدادات.");
    return;
  }

  const doctorName = document.getElementById('doctor-name').value.trim();
  const treatmentDuration = document.getElementById('treatment-end-date')?.value || '';
  const totalCapacity = parseInt(document.getElementById('total-capacity')?.value, 10) || 0;
  const pillsNode = document.getElementById('pills-count');
  const currentStock = pillsNode ? (parseInt(pillsNode.innerText, 10) || totalCapacity) : totalCapacity;

  const daysCheckboxes = document.querySelectorAll('.day-checkbox:checked');
  const selectedDays = Array.from(daysCheckboxes).map(cb => cb.value);

  const fd = new FormData();
  fd.append('patient_medication_id', window.activeMedicationId);
  const clinicName = document.getElementById('clinic-name')?.value.trim();
  const dosageText = document.getElementById('dosage-value')?.value || document.getElementById('dosage-text')?.value.trim() || '';

  if (doctorName) fd.append('doctor_name', doctorName);
  if (clinicName) fd.append('clinic_name', clinicName);
  if (dosageText) fd.append('dosage', dosageText);
  if (treatmentDuration) fd.append('treatment_duration', treatmentDuration);
  fd.append('total_capacity', totalCapacity);
  fd.append('current_stock', currentStock);
  fd.append('days_of_week', JSON.stringify(selectedDays));

  try {
    const res = await fetch(apiUrl('/api/medications/update_advanced_config.php'), {
      method: 'POST',
      body: fd
    });

    if (!res.ok) throw new Error("تعذر حفظ التكوين");
    alert("تم حفظ إعدادات منبه الدواء بنجاح!");
    refreshMedicines();
  } catch (err) {
    alert(err.message);
  }
};

/* ── Report Modal ──────────────────────────────────── */

window.openReportModal = function () {
  const modal = document.getElementById('report-modal');
  if (!modal) return;
  // Populate filter dropdown
  const select = document.getElementById('report-filter');
  if (select) {
    select.innerHTML = '<option value="all">جميع الأدوية</option>';
    medicines.forEach(med => {
      const opt = document.createElement('option');
      opt.value = med.patient_medication_id;
      opt.textContent = med.medication_name || 'دواء';
      select.appendChild(opt);
    });
  }
  modal.classList.remove('hidden');
};

window.closeReportModal = function () {
  const modal = document.getElementById('report-modal');
  if (modal) modal.classList.add('hidden');
};

/* ── Dynamic PDF Generation ────────────────────────── */

window.generateDynamicPDF = function () {
  const btn = document.getElementById('btn-generate-report');
  const originalText = btn.innerText;
  btn.innerText = "جارٍ تحميل التقرير...";
  btn.disabled = true;

  try {
    const pid = getPatientId();
    if (!pid) {
      alert("معرف المريض غير متوفر.");
      return;
    }

    const filterVal = document.getElementById('report-filter')?.value || 'all';
    const url = apiUrl('/api/medications/generate_pdf_report.php?patient_id=' + pid + '&pm_id=' + filterVal);

    // Trigger download in new tab
    window.open(url, '_blank');

    closeReportModal();
  } catch (err) {
    console.error(err);
    alert('حدث خطأ: ' + err.message);
  } finally {
    setTimeout(() => {
      btn.innerText = originalText;
      btn.disabled = false;
    }, 1500);
  }
};

/* ── Date Picker Helper ────────────────────────────── */

window.calcRemainingDays = function () {
  const dateInput = document.getElementById('treatment-end-date');
  const box = document.getElementById('remaining-days-box');
  const display = document.getElementById('remaining-days');
  if (!dateInput || !box || !display) return;

  const endDate = new Date(dateInput.value);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  endDate.setHours(0, 0, 0, 0);

  if (isNaN(endDate.getTime())) { box.classList.add('hidden'); return; }

  const diff = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));
  box.classList.remove('hidden');

  if (diff > 0) {
    display.textContent = diff + ' يوماً';
    display.className = 'text-xl font-black text-blue-700';
  } else if (diff === 0) {
    display.textContent = 'اليوم!';
    display.className = 'text-xl font-black text-amber-600';
  } else {
    display.textContent = 'منتهي';
    display.className = 'text-xl font-black text-red-600';
  }
};

/* ── Dose Confirmation ─────────────────────────────── */

window.confirmTaken = async function (btn) {
  const pmId = btn.getAttribute('data-pm-id');
  if (!pmId) {
    alert("معرف الدواء مفقود!");
    return;
  }

  try {
    const res = await fetch(apiUrl('/api/medications/decrement_stock.php'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ patient_medication_id: pmId })
    });

    const data = await parseJson(res);

    if (res.ok) {
      if (typeof updatePills === 'function') {
        updatePills(-1);
      }
      const card = btn.closest('div.bg-red-50');
      if (card) {
        card.style.opacity = '0';
        setTimeout(() => card.remove(), 300);
      }
      alert("تم تأكيد الجرعة وتحديث المخزون بنجاح ✅");

      const pid = getPatientId();
      if (pid) fetchDailyStatistics(pid);
    } else {
      alert(data.message || "المخزون نفذ تماماً!");
    }
  } catch (e) {
    alert("تعذر الاتصال بالخادم: " + e.message);
  }
};

window.toggleTime = function (btn, mins) {
  document.querySelectorAll('.time-btn').forEach(b => b.classList.remove('active', 'border-emerald-500', 'bg-emerald-50', 'text-emerald-600'));
  btn.classList.add('active', 'border-emerald-500', 'bg-emerald-50', 'text-emerald-600');
};