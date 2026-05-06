<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

include_once '../../config/database.php';
include_once '../../includes/medication.php';

$database = new Database();
$db = $database->getConnection();
$medication = new Medication($db);

$data = json_decode(file_get_contents("php://input"));

if(empty($data->patient_medication_id)) {
    http_response_code(400);
    echo json_encode(array("message" => "Incomplete data. Required: patient_medication_id."));
    exit;
}

$status = $medication->decrementStock($data->patient_medication_id);

if ($status === "SUCCESS") {
    http_response_code(200);
    echo json_encode(array("message" => "تم تأكيد الجرعة بنجاح"));
} else if ($status === "DEPLETED") {
    http_response_code(400);
    echo json_encode(array("message" => "المخزون نفذ تماماً!"));
} else if ($status === "NOT_FOUND") {
    http_response_code(404);
    echo json_encode(array("message" => "معرف الدواء غير موجود"));
} else {
    http_response_code(503);
    echo json_encode(array("message" => "حدث خطأ غير معروف"));
}
?>
