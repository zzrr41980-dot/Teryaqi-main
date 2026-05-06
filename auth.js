// ═══════════════════════════════════════════════════════
// تِرياقي — Shared Authentication Module
// ═══════════════════════════════════════════════════════

const LS_PATIENT = 'teryaqi_patient_id';
const LS_NAME    = 'teryaqi_full_name';

/* ── API Helpers ─────────────────────────────────────── */

function apiUrl(path) {
  const base = (typeof window.TERYAQI_API_BASE === 'string'
    ? window.TERYAQI_API_BASE
    : 'http://localhost:8080').replace(/\/$/, '');
  if (base === '') return path.replace(/^\//, '');
  return base + (path.startsWith('/') ? path : '/' + path);
}

async function parseJson(res) {
  const text = await res.text();
  try { return text ? JSON.parse(text) : {}; }
  catch (e) { return { message: text || 'استجابة غير صالحة' }; }
}

/* ── Legacy Cleanup ──────────────────────────────────── */
;(function cleanupLegacyStorage() {
  try {
    localStorage.removeItem(LS_PATIENT);
    localStorage.removeItem(LS_NAME);
  } catch (e) { console.warn('Could not clear legacy localStorage'); }
})();

/* ── Session Management ──────────────────────────────── */

function getPatientId() {
  try {
    const v = sessionStorage.getItem(LS_PATIENT);
    if (!v) return null;
    const parsed = parseInt(v, 10);
    return isNaN(parsed) ? null : parsed;
  } catch (e) { return null; }
}

function getPatientName() {
  try { return sessionStorage.getItem(LS_NAME) || ''; }
  catch (e) { return ''; }
}

function setSession(patientId, fullName) {
  if (patientId) sessionStorage.setItem(LS_PATIENT, String(patientId));
  else sessionStorage.removeItem(LS_PATIENT);
  if (fullName) sessionStorage.setItem(LS_NAME, fullName);
  else sessionStorage.removeItem(LS_NAME);
}

function clearSession() {
  sessionStorage.removeItem(LS_PATIENT);
  sessionStorage.removeItem(LS_NAME);
}

function isAuthenticated() {
  return getPatientId() !== null;
}

/* ── Auth Guards ─────────────────────────────────────── */

function requireAuth() {
  if (!isAuthenticated()) {
    window.location.replace('landing.html');
    return false;
  }
  return true;
}

function redirectIfAuthenticated() {
  if (isAuthenticated()) {
    window.location.replace('index.html');
    return true;
  }
  return false;
}

/* ── Auth API ────────────────────────────────────────── */

async function apiLogin(email, password) {
  const res = await fetch(apiUrl('/api/patients/login.php'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await parseJson(res);
  if (!res.ok) throw new Error(data.message || 'فشل تسجيل الدخول');
  return data;
}

async function apiRegister(body) {
  const res = await fetch(apiUrl('/api/patients/register.php'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await parseJson(res);
  if (!res.ok) throw new Error(data.message || 'فشل إنشاء الحساب');
  return data;
}
