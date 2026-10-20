-- Zoriyon Zion (V01029666)
-- Sprint 1: normal-form evidence (Lessons on 3NF and 4NF / MVDs).
-- Run with: mysql -u root -t < normal_forms_checks.sql
USE airline;

-- 1. Lossless join of the BCNF split (Lesson 07): joining cabin_rows and seats back together
--    gives one row per seat, with its cabin. Expected: 189 seats = 180 (737) + 9 (Caravan).
SELECT 'seats rebuilt by join' AS check_name, COUNT(*) AS rows_found,
       (SELECT COUNT(*) FROM seats) AS rows_in_seats
FROM seats s JOIN cabin_rows c ON c.type_id = s.type_id AND c.seat_row = s.seat_row;

-- 2. The functional dependency (type_id, seat_row) -> fare_class_code is preserved:
--    it is the key of cabin_rows, so the DBMS enforces it. A violation would be a row
--    pair with the same key and different cabins. Expected: 0.
SELECT 'FD violations (type_id, seat_row -> cabin)' AS check_name, COUNT(*) AS violations
FROM cabin_rows a JOIN cabin_rows b
  ON a.type_id = b.type_id AND a.seat_row = b.seat_row AND a.fare_class_code <> b.fare_class_code;

-- 3. Does type_id ->> seat_row hold in the seats table? An MVD B ->> C holds iff for any two
--    tuples t, u with the same B there is a tuple v with t's C and u's rest (Lesson 24).
--    Here that means: for every pair (row from t, letter from u) of the same aircraft type,
--    the seat exists. Missing pairs below are MVD violations. Expected: 0 on the sample data.
SELECT 'MVD type_id ->> seat_row: missing combinations' AS check_name, COUNT(*) AS violations
FROM (SELECT DISTINCT type_id, seat_row FROM seats) r
JOIN (SELECT DISTINCT type_id, seat_letter FROM seats) l ON l.type_id = r.type_id
LEFT JOIN seats s ON s.type_id = r.type_id AND s.seat_row = r.seat_row AND s.seat_letter = l.seat_letter
WHERE s.seat_row IS NULL;
