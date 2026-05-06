<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type");

include_once '../../config/database.php';

$database = new Database();
$db = $database->getConnection();

$patient_id = isset($_GET['patient_id']) ? $_GET['patient_id'] : 1;

$query = "SELECT 
            SUM(CASE WHEN ml.status = 'taken' THEN 1 ELSE 0 END) as taken_count, 
            SUM(CASE WHEN ml.status = 'missed' THEN 1 ELSE 0 END) as missed_count 
          FROM MEDICATION_LOGS ml
          JOIN PATIENT_MEDICATIONS pm ON ml.patient_medication_id = pm.patient_medication_id 
          WHERE pm.patient_id = :patient_id AND ml.log_date = CURDATE()";

$stmt = $db->prepare($query);
$stmt->bindParam(":patient_id", $patient_id, PDO::PARAM_INT);
$stmt->execute();
$row = $stmt->fetch(PDO::FETCH_ASSOC);

echo json_encode(array(
    "taken" => isset($row['taken_count']) ? (int)$row['taken_count'] : 0,
    "missed" => isset($row['missed_count']) ? (int)$row['missed_count'] : 0
));
?>
