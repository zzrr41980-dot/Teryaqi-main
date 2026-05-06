<?php
header("Access-Control-Allow-Origin: *");
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

if (empty($_POST['patient_medication_id'])) {
    http_response_code(400);
    echo json_encode(array("message" => "Incomplete data. Required: patient_medication_id."));
    exit;
}

$patient_medication_id = $_POST['patient_medication_id'];
$doctor_name = isset($_POST['doctor_name']) ? $_POST['doctor_name'] : null;
$clinic_name = isset($_POST['clinic_name']) ? $_POST['clinic_name'] : null;
$dosage      = isset($_POST['dosage']) ? $_POST['dosage'] : null;
$treatment_duration = isset($_POST['treatment_duration']) ? $_POST['treatment_duration'] : null;
$total_capacity = isset($_POST['total_capacity']) ? (int)$_POST['total_capacity'] : 0;
$current_stock = isset($_POST['current_stock']) ? (int)$_POST['current_stock'] : $total_capacity; 
$days_of_week = isset($_POST['days_of_week']) ? json_decode($_POST['days_of_week'], true) : [];

if ($medication->updateAdvancedConfig($patient_medication_id, $doctor_name, $treatment_duration, $total_capacity, $current_stock, $clinic_name, $dosage, $days_of_week)) {
    http_response_code(200);
    echo json_encode(array(
        "message" => "Medication configuration updated successfully."
    ));
} else {
    http_response_code(503);
    echo json_encode(array("message" => "Unable to update medication configuration."));
}
?>
