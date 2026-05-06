<?php
require_once __DIR__ . '/../../vendor/autoload.php';
include_once '../../config/database.php';
include_once '../../includes/medication.php';

$database = new Database();
$db = $database->getConnection();
$medication = new Medication($db);

if (!isset($_GET['patient_id']) || $_GET['patient_id'] === '') {
    http_response_code(400);
    echo "Required: patient_id.";
    exit;
}

$patient_id = $_GET['patient_id'];
$pm_id = isset($_GET['pm_id']) && $_GET['pm_id'] !== 'all' ? $_GET['pm_id'] : null;

$data = $medication->getReportData($patient_id, $pm_id);

if (!$data || !isset($data['medications']) || count($data['medications']) === 0) {
    echo "<h3 style='text-align:center; color:red; direction:rtl;'>لا توجد أدوية لإنشاء التقرير.</h3>";
    exit;
}

$patientName = isset($data['patient']['full_name']) ? $data['patient']['full_name'] : '';
$currentDate = date('Y/m/d');

try {
    $defaultConfig = (new \Mpdf\Config\ConfigVariables())->getDefaults();
    $fontDirs = $defaultConfig['fontDir'];

    $defaultFontConfig = (new \Mpdf\Config\FontVariables())->getDefaults();
    $fontData = $defaultFontConfig['fontdata'];

    $mpdf = new \Mpdf\Mpdf([
        'mode' => 'utf-8',
        'format' => 'A4',
        'orientation' => 'P',
        'dir' => 'rtl',
        'fontDir' => array_merge($fontDirs, [
            __DIR__ . '/../../assets/fonts',
        ]),
        'fontdata' => $fontData + [
            'amiri' => [
                'R' => 'Amiri-Regular.ttf',
                'useOTL' => 0xFF,
                'useKashida' => 75,
            ]
        ],
        'default_font' => 'amiri',
        'autoScriptToLang' => true,
        'autoLangToFont' => true,
    ]);

    $mpdf->SetDirectionality('rtl');

    $html = '
    <style>
        body { font-family: amiri, sans-serif; direction: rtl; text-align: right; }
        .header { background-color: #065F46; color: white; text-align: center; padding: 20px; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 5px 0 0 0; font-size: 14px; }
        table { width: 100%; border-collapse: collapse; margin-top: 30px; }
        th { background-color: #065F46; color: white; padding: 10px; border: 1px solid #10B981; }
        td { padding: 10px; border: 1px solid #10B981; color: #1E293B; }
        .footer { text-align: center; color: #9CA3AF; font-size: 12px; margin-top: 50px; }
    </style>
    <div class="header">
        <h1>تقرير المعالجة الطبي - تِرياقي</h1>
        <p>المريض: ' . htmlspecialchars($patientName) . '</p>
    </div>
    <table>
        <thead>
            <tr>
                <th>اسم الدواء</th>
                <th>الجرعة</th>
                <th>الطبيب</th>
                <th>انتهاء العلاج</th>
                <th>المخزون</th>
            </tr>
        </thead>
        <tbody>';

    foreach ($data['medications'] as $med) {
        $html .= '<tr>
            <td>' . htmlspecialchars($med['medication_name'] ?? '-') . '</td>
            <td>' . htmlspecialchars($med['dosage_amount'] ?? $med['dosage'] ?? '-') . '</td>
            <td>' . htmlspecialchars($med['doctor_name'] ?? '-') . '</td>
            <td>' . htmlspecialchars($med['treatment_duration'] ?? '-') . '</td>
            <td>' . htmlspecialchars(($med['current_stock'] ?? 0) . ' حبة') . '</td>
        </tr>';
    }

    $html .= '</tbody>
    </table>
    <div class="footer">
        تم إنشاء هذا التقرير ديناميكياً من نظام تِرياقي — ' . $currentDate . '
    </div>
    ';

    $mpdf->WriteHTML($html);
    $mpdf->Output('Teryaqi_Report_' . time() . '.pdf', 'D');

} catch (\Mpdf\MpdfException $e) {
    echo "Error generating PDF: " . $e->getMessage();
}
?>
