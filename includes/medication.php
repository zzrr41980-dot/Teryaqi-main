<?php
class Medication {
    private $conn;

    public function __construct($db) {
        $this->conn = $db;
    }

    public function addForPatient($patient_id, $medication_id, $dosage_amount, $start_date, $end_date, $instructions) {
        $query = "INSERT INTO PATIENT_MEDICATIONS 
                SET patient_id=:patient_id, medication_id=:medication_id, dosage_amount=:dosage_amount, 
                    start_date=:start_date, end_date=:end_date, instructions=:instructions";
        
        $stmt = $this->conn->prepare($query);

        $stmt->bindParam(":patient_id", $patient_id);
        $stmt->bindParam(":medication_id", $medication_id);
        $stmt->bindParam(":dosage_amount", $dosage_amount);
        $stmt->bindParam(":start_date", $start_date);
        $stmt->bindParam(":end_date", $end_date);
        $stmt->bindParam(":instructions", $instructions);

        if($stmt->execute()) {
            return $this->conn->lastInsertId();
        }
        return false;
    }

    public function getForPatient($patient_id) {
        $query = "SELECT pm.patient_medication_id, m.medication_name, m.dosage_form, m.strength, 
                         pm.dosage_amount, pm.dosage, pm.start_date, pm.end_date, pm.instructions,
                         pm.doctor_name, pm.clinic_name, pm.treatment_duration, pm.total_capacity, pm.current_stock,
                         (SELECT MIN(ms.intake_time) FROM MEDICATION_SCHEDULE ms 
                          WHERE ms.patient_medication_id = pm.patient_medication_id) AS intake_time,
                         (SELECT GROUP_CONCAT(sd.day_name) 
                          FROM SCHEDULE_DAYS sd 
                          JOIN MEDICATION_SCHEDULE ms ON sd.schedule_id = ms.schedule_id 
                          WHERE ms.patient_medication_id = pm.patient_medication_id) AS schedule_days,
                         (CASE WHEN ml.log_id IS NOT NULL THEN 1 ELSE 0 END) AS is_taken_today
                  FROM PATIENT_MEDICATIONS pm
                  JOIN MEDICATIONS m ON pm.medication_id = m.medication_id
                  LEFT JOIN (SELECT patient_medication_id, MAX(log_id) as log_id FROM MEDICATION_LOGS WHERE log_date = CURDATE() GROUP BY patient_medication_id) ml 
                  ON pm.patient_medication_id = ml.patient_medication_id
                  WHERE pm.patient_id = ?";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(1, $patient_id);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function createSchedule($patient_medication_id, $intake_time, $frequency_per_day) {
        $query = "INSERT INTO MEDICATION_SCHEDULE 
                SET patient_medication_id=:patient_medication_id, intake_time=:intake_time, 
                    frequency_per_day=:frequency_per_day";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(":patient_medication_id", $patient_medication_id);
        $stmt->bindParam(":intake_time", $intake_time);
        $stmt->bindParam(":frequency_per_day", $frequency_per_day);

        return $stmt->execute();
    }

    public function getTodaySchedules($patient_id) {
        $query = "SELECT ms.schedule_id, m.medication_name, ms.intake_time, pm.dosage_amount, pm.dosage,
                         (CASE WHEN ml.log_id IS NOT NULL THEN 1 ELSE 0 END) AS is_taken_today
                  FROM MEDICATION_SCHEDULE ms
                  JOIN PATIENT_MEDICATIONS pm ON ms.patient_medication_id = pm.patient_medication_id
                  JOIN MEDICATIONS m ON pm.medication_id = m.medication_id
                  LEFT JOIN (SELECT patient_medication_id, MAX(log_id) as log_id FROM MEDICATION_LOGS WHERE log_date = CURDATE() GROUP BY patient_medication_id) ml 
                  ON pm.patient_medication_id = ml.patient_medication_id
                  WHERE pm.patient_id = ? AND (pm.end_date >= CURDATE() OR pm.end_date IS NULL)
                  AND (
                      NOT EXISTS (SELECT 1 FROM SCHEDULE_DAYS sd WHERE sd.schedule_id = ms.schedule_id)
                      OR 
                      EXISTS (
                          SELECT 1 FROM SCHEDULE_DAYS sd2 
                          WHERE sd2.schedule_id = ms.schedule_id 
                            AND sd2.day_name = DATE_FORMAT(CURDATE(), '%a')
                      )
                  )";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(1, $patient_id);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    // New: Function to add a base medication (for APIdog/Postman)
    public function createBaseMedication($name, $form, $strength, $description) {
        $query = "INSERT INTO MEDICATIONS 
                SET medication_name=:name, dosage_form=:form, strength=:strength, description=:description";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(":name", $name);
        $stmt->bindParam(":form", $form);
        $stmt->bindParam(":strength", $strength);
        $stmt->bindParam(":description", $description);

        if($stmt->execute()) {
            return $this->conn->lastInsertId();
        }
        return false;
    }

    // New: Function to get all available base medications
    public function getAllMedications() {
        $query = "SELECT * FROM MEDICATIONS ORDER BY medication_name ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getReportData($patient_id, $pm_id = null) {
        // Patient info
        $pQuery = "SELECT full_name, national_id FROM PATIENTS WHERE patient_id = ?";
        $pStmt = $this->conn->prepare($pQuery);
        $pStmt->bindParam(1, $patient_id);
        $pStmt->execute();
        $patient = $pStmt->fetch(PDO::FETCH_ASSOC);

        // Medications query with optional filter
        $mQuery = "SELECT m.medication_name, m.dosage_form, m.strength,
                          pm.patient_medication_id, pm.dosage_amount, pm.dosage, pm.doctor_name,
                          pm.clinic_name, pm.treatment_duration, pm.total_capacity,
                          pm.current_stock, pm.start_date, pm.end_date,
                          (SELECT MIN(ms.intake_time) FROM MEDICATION_SCHEDULE ms
                           WHERE ms.patient_medication_id = pm.patient_medication_id) AS intake_time
                   FROM PATIENT_MEDICATIONS pm
                   JOIN MEDICATIONS m ON pm.medication_id = m.medication_id
                   WHERE pm.patient_id = :patient_id";
        if ($pm_id) {
            $mQuery .= " AND pm.patient_medication_id = :pm_id";
        }
        $mQuery .= " ORDER BY m.medication_name";

        $mStmt = $this->conn->prepare($mQuery);
        $mStmt->bindParam(":patient_id", $patient_id, PDO::PARAM_INT);
        if ($pm_id) {
            $mStmt->bindParam(":pm_id", $pm_id, PDO::PARAM_INT);
        }
        $mStmt->execute();
        $medications = $mStmt->fetchAll(PDO::FETCH_ASSOC);

        return array(
            "patient" => $patient ? $patient : new \stdClass(),
            "medications" => $medications
        );
    }

    public function updateAdvancedConfig($patient_medication_id, $doctor_name, $treatment_duration, $total_capacity, $current_stock, $clinic_name = null, $dosage = null, $days = []) {
        $query = "UPDATE PATIENT_MEDICATIONS 
                  SET doctor_name = :doctor_name,
                      clinic_name = :clinic_name,
                      dosage = :dosage,
                      treatment_duration = :treatment_duration,
                      total_capacity = :total_capacity,
                      current_stock = :current_stock
                  WHERE patient_medication_id = :patient_medication_id";
        
        $stmt = $this->conn->prepare($query);
        
        $stmt->bindParam(":doctor_name", $doctor_name);
        $stmt->bindParam(":clinic_name", $clinic_name);
        $stmt->bindParam(":dosage", $dosage);
        $stmt->bindParam(":treatment_duration", $treatment_duration);
        $stmt->bindParam(":total_capacity", $total_capacity, PDO::PARAM_INT);
        $stmt->bindParam(":current_stock", $current_stock, PDO::PARAM_INT);
        $stmt->bindParam(":patient_medication_id", $patient_medication_id, PDO::PARAM_INT);
        
        if(!$stmt->execute()) {
            return false;
        }

        // --- RELATIONAL SCHEDULE SYNC (DAYS OF WEEK) ---
        if (!empty($days) && is_array($days)) {
            // Retrieve underlying Schedule ID
            $sQuery = "SELECT schedule_id FROM MEDICATION_SCHEDULE WHERE patient_medication_id = :pm_id LIMIT 1";
            $sStmt = $this->conn->prepare($sQuery);
            $sStmt->bindParam(":pm_id", $patient_medication_id, PDO::PARAM_INT);
            $sStmt->execute();
            if ($sRow = $sStmt->fetch(PDO::FETCH_ASSOC)) {
                $schedule_id = $sRow['schedule_id'];
                
                // Clear old records mapping exact schedule constraints
                $delQuery = "DELETE FROM SCHEDULE_DAYS WHERE schedule_id = :sid";
                $delStmt = $this->conn->prepare($delQuery);
                $delStmt->bindParam(":sid", $schedule_id, PDO::PARAM_INT);
                $delStmt->execute();
                
                // Insert newly selected records loop
                $insQuery = "INSERT INTO SCHEDULE_DAYS (schedule_id, day_name) VALUES (:sid, :day)";
                $insStmt = $this->conn->prepare($insQuery);
                foreach ($days as $d) {
                    // Quick validation against allowed Enum constraints
                    $allowed = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
                    if (in_array($d, $allowed)) {
                        $insStmt->bindParam(":sid", $schedule_id, PDO::PARAM_INT);
                        $insStmt->bindParam(":day", $d, PDO::PARAM_STR);
                        $insStmt->execute();
                    }
                }
            }
        }
        
        return true;
    }

    public function decrementStock($patient_medication_id) {
        try {
            $this->conn->beginTransaction();
            
            $checkQuery = "SELECT current_stock FROM PATIENT_MEDICATIONS WHERE patient_medication_id = :id FOR UPDATE";
            $checkStmt = $this->conn->prepare($checkQuery);
            $checkStmt->bindParam(":id", $patient_medication_id, PDO::PARAM_INT);
            $checkStmt->execute();
            
            if ($checkStmt->rowCount() === 0) {
                $this->conn->rollback();
                return "NOT_FOUND";
            }
            
            $row = $checkStmt->fetch(PDO::FETCH_ASSOC);
            if ($row['current_stock'] <= 0) {
                $this->conn->rollback();
                return "DEPLETED";
            }
            
            $query = "UPDATE PATIENT_MEDICATIONS 
                      SET current_stock = current_stock - 1
                      WHERE patient_medication_id = :pm_id";
            
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":pm_id", $patient_medication_id, PDO::PARAM_INT);
            $stmt->execute();
            
            if ($stmt->rowCount() > 0) {
                $logQuery = "INSERT INTO MEDICATION_LOGS (patient_medication_id, status, log_date) 
                             VALUES (:log_pm_id, 'taken', CURDATE())";
                $logStmt = $this->conn->prepare($logQuery);
                $logStmt->bindParam(":log_pm_id", $patient_medication_id, PDO::PARAM_INT);
                $logStmt->execute();
                
                $this->conn->commit();
                return "SUCCESS";
            }
            $this->conn->rollback();
            return "ERROR";
        } catch(PDOException $e) {
            $this->conn->rollback();
            return "ERROR";
        }
    }
}
?>
