select current_date;

create schema hospital_data;

set search_path to hospital_data;

select * from hospital_data.admissions;
select * from hospital_data.bills;
select * from hospital_data.doctors;
select * from hospital_data.nurses;
select * from hospital_data.patients;
select * from hospital_data.payments;
select * from hospital_data.prescriptions;
select * from hospital_data.treatments;
select * from hospital_data.wards;
select * from hospital_data.appointments;

drop table hospital_data.admissions;
select * from hospital_data.admissions;

alter table hospital_data.admissions
alter column 'AdmissionDate' type date;

select column 'AdmissionDate' from hospital_data.admissions;

drop table hospital_data.admissions;
select * from hospital_data.admissions;

select "AdmissionDate" from hospital_data.admissions; 

ALTER TABLE hospital_data.admissions 
ADD COLUMN admission_date_converted DATE,
ADD COLUMN discharge_date_converted DATE;

UPDATE hospital_data.admissions
SET 
  admission_date_converted = "AdmissionDate"::int + DATE '1899-12-30',
  discharge_date_converted = "DischargeDate"::int + DATE '1899-12-30';

ALTER TABLE hospital_data.admissions
DROP COLUMN "AdmissionDate",
DROP COLUMN "DischargeDate";

ALTER TABLE hospital_data.admissions
RENAME COLUMN "admission_date_converted" TO AdmissionDate;

ALTER TABLE hospital_data.admissions
RENAME COLUMN "discharge_date_converted" TO DischargeDate;

select * from hospital_data.admissions;
select * from hospital_data.patients;

drop table hospital_data.patients;
select * from hospital_data.patients;

set search_path to hospital_data;

--Generate a report of all appointments scheduled for the next 7 days based on the latest date in the Appointments Table
WITH latest AS (
  SELECT MAX("AppointmentDate") AS latest_date
  FROM "hospital_data".appointments
)
SELECT * FROM hospital_data.appointments
WHERE "AppointmentDate" BETWEEN (SELECT latest_date FROM latest)
                            AND (SELECT latest_date FROM latest) + INTERVAL '7 days';

--Generate a report of all unpaid bills, including patient and admission details
SELECT b.*, a.*, p.*
FROM "hospital_data".bills b
JOIN "hospital_data".admissions a ON b."AdmissionID" = a."AdmissionID"
JOIN "hospital_data".patients p ON a."PatientID" = p."PatientID"
WHERE b."OutstandingAmount" > 0;

--Evaluate doctors' performance based on the number of appointments and treatments provided
SELECT d."FirstName" || ' ' || d."LastName" AS DoctorName,
       COUNT(DISTINCT ap."AppointmentID") AS AppointmentCount,
       COUNT(DISTINCT t."AppointmentID") AS TreatmentCount
FROM "hospital_data".doctors d
LEFT JOIN "hospital_data".appointments ap ON d."DoctorID" = ap."DoctorID"
LEFT JOIN "hospital_data".treatments t ON d."DoctorID" = ap."DoctorID"
GROUP BY DoctorName;

--Track all medications prescribed in the last month based on the latest date in the Appointments table.
WITH latest AS (
  SELECT MAX("AppointmentDate") AS latest_date
  FROM "hospital_data".appointments
)
SELECT pr.*
FROM "hospital_data".prescriptions pr
JOIN "hospital_data".appointments ap ON pr."AppointmentID" = ap."AppointmentID"
WHERE ap."AppointmentDate" >= (SELECT latest_date FROM latest) - INTERVAL '1 month';

--Understand nurse assignments, including ward details and the number of patients handled.
SELECT n."FirstName" || ' ' || n."LastName" AS NurseName,
       w."WardName",
       COUNT(DISTINCT a."PatientID") AS PatientsHandled
FROM hospital_data.nurses n
JOIN "hospital_data".wards w ON n."NurseID" = w."NurseID"
JOIN "hospital_data".admissions a ON w."WardID" = a."WardID"
GROUP BY NurseName, w."WardName";

--Identify patients with the highest total bills, including their number of admissions.
SELECT p."FirstName" || ' ' || p."LastName" AS PatientName,
       COUNT(DISTINCT a."AdmissionID") AS AdmissionCount,
       SUM(b."TotalAmount") AS TotalBill
FROM hospital_data.patients p
JOIN hospital_data.admissions a ON p."PatientID" = a."PatientID"
JOIN hospital_data.bills b ON a."AdmissionID" = b."AdmissionID"
GROUP BY PatientName
ORDER BY TotalBill DESC
LIMIT 10;

--Identify patients who visit the hospital frequently.
SELECT p."FirstName" || ' ' || p."LastName" AS PatientName,
       COUNT(a."AppointmentID") AS VisitCount
FROM "hospital_data".patients p
JOIN "hospital_data".appointments a ON p."PatientID" = a."PatientID"
GROUP BY PatientName
ORDER BY VisitCount DESC
LIMIT 10;

--Analyse monthly patient admissions to understand patterns.
SELECT DATE_TRUNC('month', a."admissiondate") AS Month,
       COUNT(*) AS AdmissionCount
FROM hospital_data.admissions a
GROUP BY Month
ORDER BY Month;

--Identify patients who have not visited the hospital in the last year
WITH last_visited AS (
  SELECT "PatientID", MAX("AppointmentDate") AS last_date
  FROM "hospital_data".appointments
  GROUP BY "PatientID"
)
SELECT p."FirstName" || ' ' || p."LastName" AS PatientName,
       lv.last_date
FROM "hospital_data".patients p
LEFT JOIN last_visited lv ON p."PatientID" = lv."PatientID"
WHERE lv.last_date < CURRENT_DATE - INTERVAL '1 year';

--Identify the most prescribed medications and their prescription counts.
SELECT "Medication",
       COUNT(*) AS PrescriptionCount
FROM "hospital_data".prescriptions
GROUP BY "Medication"
ORDER BY PrescriptionCount DESC
LIMIT 10;

--Analyse treatment success rates for each doctor.
SELECT d."FirstName" || ' ' || d."LastName" AS DoctorName,
       COUNT(*) FILTER (WHERE t."Outcome" = 'Successful') AS SuccessfulTreatments,
       COUNT(*) AS TotalTreatments,
       ROUND(
         COUNT(*) FILTER (WHERE t."Outcome" = 'Successful') * 100.0 / NULLIF(COUNT(*), 0), 2
       ) AS SuccessRate
FROM hospital_data.doctors d
JOIN hospital_data.appointments a ON d."DoctorID" = a."DoctorID"
JOIN hospital_data.treatments t ON a."AppointmentID" = t."AppointmentID"
GROUP BY DoctorName;

--Understand patient demographics (gender, age) by ward.
SELECT w."WardName",
       a."Gender",
       ROUND(AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, a."DateOfBirth")))) AS AverageAge,
       COUNT(*) AS PatientCount
FROM "hospital_data".admissions ad
JOIN "hospital_data".wards w ON ad."WardID" = w."WardID"
JOIN "hospital_data".patients a ON ad."PatientID" = a."PatientID"
GROUP BY w."WardName", a."Gender"
ORDER BY w."WardName", a."Gender";

--Evaluate nurse workload by ward, including patient counts.
SELECT w."WardName",
       n."FirstName" || ' ' || n."LastName" AS NurseName,
       COUNT(DISTINCT a."PatientID") AS PatientsHandled
FROM "hospital_data".wards w
JOIN "hospital_data".nurses n ON w."NurseID" = n."NurseID"
JOIN "hospital_data".admissions a ON w."WardID" = a."WardID"
GROUP BY w."WardName", NurseName;

--Identify the top 5 doctors with the most appointments.
SELECT d."FirstName" || ' ' || d."LastName" AS DoctorName,
       COUNT(a."AppointmentID") AS AppointmentCount
FROM "hospital_data".doctors d
JOIN "hospital_data".appointments a ON d."DoctorID" = a."DoctorID"
GROUP BY DoctorName
ORDER BY AppointmentCount DESC
LIMIT 5;

--Analyse the age distribution of patients in each ward.
SELECT w."WardName",
       WIDTH_BUCKET(EXTRACT(YEAR FROM AGE(CURRENT_DATE, p."DateOfBirth")), 0, 100, 5) AS AgeGroup,
       COUNT(*) AS CountInGroup
FROM "hospital_data".admissions a
JOIN "hospital_data".wards w ON a."WardID" = w."WardID"
JOIN "hospital_data".patients p ON a."PatientID" = p."PatientID"
GROUP BY w."WardName", AgeGroup
ORDER BY w."WardName", AgeGroup;

--Analyse readmission rates and intervals for patients.
SELECT p."FirstName" || ' ' || p."LastName" AS PatientName,
       COUNT(a."AdmissionID") AS AdmissionCount
FROM "hospital_data".patients p
JOIN "hospital_data".admissions a ON p."PatientID" = a."PatientID"
GROUP BY PatientName
HAVING COUNT(a."AdmissionID") > 1
ORDER BY AdmissionCount DESC;

--Track the treatment history of patients, including appointments and treatments.
SELECT p."FirstName" || ' ' || p."LastName" AS PatientName,
       a."AppointmentDate",
       t."TreatmentType",
       t."Outcome"
FROM "hospital_data".patients p
JOIN "hospital_data".appointments a ON p."PatientID" = a."PatientID"
JOIN "hospital_data".treatments t ON a."AppointmentID" = t."AppointmentID"
ORDER BY PatientName, a."AppointmentDate";

--Calculate the occupancy rate for each ward as a percentage of capacity.
SELECT w."WardName",
       w."Capacity",
       w."Occupied",
       ROUND(w."Occupied" * 100.0 / NULLIF(w."Capacity", 0), 2) AS OccupancyRate
FROM "hospital_data".wards w;

--List all appointments for doctors Laura Garcia and James Hernandez.
SELECT a.*
FROM "hospital_data".appointments a
JOIN "hospital_data".doctors d ON a."DoctorID" = d."DoctorID"
WHERE (d."FirstName" = 'Laura' AND d."LastName" = 'Garcia')
   OR (d."FirstName" = 'James' AND d."LastName" = 'Hernandez');

--List all appointments and treatments assigned to nurse Olivia Thompson.
SELECT a.*, t."TreatmentType", t."Outcome"
FROM "hospital_data".nurses n
JOIN "hospital_data".appointments a ON n."NurseID" = a."NurseID"
JOIN "hospital_data".treatments t ON a."AppointmentID" = t."AppointmentID"
WHERE n."FirstName" = 'Olivia' AND n."LastName" = 'Thompson';


















































