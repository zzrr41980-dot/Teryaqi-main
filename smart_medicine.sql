-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 03, 2026 at 06:13 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.1.25

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `smart_medicine`
--

-- --------------------------------------------------------

--
-- Table structure for table `chronic_diseases`
--

CREATE TABLE `chronic_diseases` (
  `disease_id` int(11) NOT NULL,
  `disease_name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `medications`
--

CREATE TABLE `medications` (
  `medication_id` int(11) NOT NULL,
  `patient_id` int(11) DEFAULT NULL,
  `medication_name` varchar(100) NOT NULL,
  `dosage_form` enum('Tablet','Capsule','Syrup') NOT NULL,
  `strength` varchar(50) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `dosage_amount` varchar(50) DEFAULT NULL,
  `intake_time` time DEFAULT NULL,
  `instructions` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `medication_logs`
--

CREATE TABLE `medication_logs` (
  `log_id` int(11) NOT NULL,
  `patient_medication_id` int(11) NOT NULL,
  `status` enum('taken','missed') NOT NULL DEFAULT 'taken',
  `log_date` date NOT NULL,
  `recorded_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `medication_schedule`
--

CREATE TABLE `medication_schedule` (
  `schedule_id` int(11) NOT NULL,
  `patient_medication_id` int(11) NOT NULL,
  `intake_time` time NOT NULL,
  `frequency_per_day` int(11) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `patients`
--

CREATE TABLE `patients` (
  `patient_id` int(11) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `national_id` varchar(20) NOT NULL,
  `date_of_birth` date DEFAULT NULL,
  `gender` enum('Male','Female') NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `pill_box_serial` varchar(100) DEFAULT NULL,
  `pill_box_status` enum('Active','Inactive') DEFAULT 'Active',
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `patient_medications`
--

CREATE TABLE `patient_medications` (
  `patient_medication_id` int(11) NOT NULL,
  `patient_id` int(11) NOT NULL,
  `medication_id` int(11) NOT NULL,
  `dosage_amount` varchar(50) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `instructions` text DEFAULT NULL,
  `doctor_name` varchar(100) DEFAULT NULL,
  `clinic_name` varchar(150) DEFAULT NULL,
  `dosage` varchar(150) DEFAULT NULL,
  `treatment_duration` date DEFAULT NULL,
  `total_capacity` int(11) DEFAULT 0,
  `current_stock` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `schedule_days`
--

CREATE TABLE `schedule_days` (
  `day_id` int(11) NOT NULL,
  `schedule_id` int(11) NOT NULL,
  `day_name` enum('Sun','Mon','Tue','Wed','Thu','Fri','Sat') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `chronic_diseases`
--
ALTER TABLE `chronic_diseases`
  ADD PRIMARY KEY (`disease_id`);

--
-- Indexes for table `medications`
--
ALTER TABLE `medications`
  ADD PRIMARY KEY (`medication_id`),
  ADD KEY `patient_id` (`patient_id`);

--
-- Indexes for table `medication_logs`
--
ALTER TABLE `medication_logs`
  ADD PRIMARY KEY (`log_id`);

--
-- Indexes for table `medication_schedule`
--
ALTER TABLE `medication_schedule`
  ADD PRIMARY KEY (`schedule_id`),
  ADD KEY `patient_medication_id` (`patient_medication_id`);

--
-- Indexes for table `patients`
--
ALTER TABLE `patients`
  ADD PRIMARY KEY (`patient_id`),
  ADD UNIQUE KEY `national_id` (`national_id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `pill_box_serial` (`pill_box_serial`);

--
-- Indexes for table `patient_medications`
--
ALTER TABLE `patient_medications`
  ADD PRIMARY KEY (`patient_medication_id`),
  ADD KEY `patient_id` (`patient_id`),
  ADD KEY `medication_id` (`medication_id`);

--
-- Indexes for table `schedule_days`
--
ALTER TABLE `schedule_days`
  ADD PRIMARY KEY (`day_id`),
  ADD KEY `schedule_id` (`schedule_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `chronic_diseases`
--
ALTER TABLE `chronic_diseases`
  MODIFY `disease_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `medications`
--
ALTER TABLE `medications`
  MODIFY `medication_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `medication_logs`
--
ALTER TABLE `medication_logs`
  MODIFY `log_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `medication_schedule`
--
ALTER TABLE `medication_schedule`
  MODIFY `schedule_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `patients`
--
ALTER TABLE `patients`
  MODIFY `patient_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `patient_medications`
--
ALTER TABLE `patient_medications`
  MODIFY `patient_medication_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `schedule_days`
--
ALTER TABLE `schedule_days`
  MODIFY `day_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `medications`
--
ALTER TABLE `medications`
  ADD CONSTRAINT `MEDICATIONS_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`patient_id`) ON DELETE CASCADE;

--
-- Constraints for table `medication_schedule`
--
ALTER TABLE `medication_schedule`
  ADD CONSTRAINT `medication_schedule_ibfk_1` FOREIGN KEY (`patient_medication_id`) REFERENCES `patient_medications` (`patient_medication_id`) ON DELETE CASCADE;

--
-- Constraints for table `patient_medications`
--
ALTER TABLE `patient_medications`
  ADD CONSTRAINT `patient_medications_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`patient_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `patient_medications_ibfk_2` FOREIGN KEY (`medication_id`) REFERENCES `medications` (`medication_id`) ON DELETE CASCADE;

--
-- Constraints for table `schedule_days`
--
ALTER TABLE `schedule_days`
  ADD CONSTRAINT `schedule_days_ibfk_1` FOREIGN KEY (`schedule_id`) REFERENCES `medication_schedule` (`schedule_id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
