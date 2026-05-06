<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");

include_once '../../config/database.php';
include_once '../../includes/medication.php';

$database = new Database();
$db = $database->getConnection();
$medication = new Medication($db);

if (!isset($_GET['patient_id']) || $_GET['patient_id'] === '') {
    http_response_code(400);
    echo json_encode(array("message" => "Required: patient_id."));
    exit;
}

$patient_id = $_GET['patient_id'];
$pm_id = isset($_GET['pm_id']) ? $_GET['pm_id'] : null;

$data = $medication->getReportData($patient_id, $pm_id);

http_response_code(200);
echo json_encode($data);
?>
