-- Sample data. Run after schema.sql:  mysql -u root < seed.sql
USE airline;

INSERT INTO airports VALUES
 ('YYJ','Victoria International','Victoria','Canada'),
 ('YVR','Vancouver International','Vancouver','Canada'),
 ('YYC','Calgary International','Calgary','Canada'),
 ('YYZ','Toronto Pearson','Toronto','Canada'),
 ('YLW','Kelowna International','Kelowna','Canada');

INSERT INTO fare_classes VALUES
 ('J','Business',3),
 ('W','Premium Economy',2),
 ('Y','Economy',1);

INSERT INTO loyalty_tiers VALUES
 (1,'Member',1,1.00),
 (2,'Silver',2,1.25),
 (3,'Gold',3,1.50),
 (4,'Platinum',4,2.00);

INSERT INTO aircraft_types (type_id, model, manufacturer) VALUES
 (1,'737-800','Boeing'),
 (2,'Caravan 208B','Cessna');

-- 737-800: rows 1-30, letters A-F. Rows 1-4 Business, 5-8 Premium, 9-30 Economy (180 seats)
INSERT INTO seats (type_id, seat_row, seat_letter, fare_class_code)
WITH RECURSIVE n AS (
    SELECT 1 AS r UNION ALL SELECT r + 1 FROM n WHERE r < 30
)
SELECT 1, n.r, l.letter,
       CASE WHEN n.r <= 4 THEN 'J' WHEN n.r <= 8 THEN 'W' ELSE 'Y' END
FROM n
JOIN (SELECT 'A' AS letter UNION ALL SELECT 'B' UNION ALL SELECT 'C'
      UNION ALL SELECT 'D' UNION ALL SELECT 'E' UNION ALL SELECT 'F') l;

-- Caravan: rows 1-3, letters A-C. Row 1 Business, rows 2-3 Economy (9 seats)
INSERT INTO seats (type_id, seat_row, seat_letter, fare_class_code)
WITH RECURSIVE n AS (
    SELECT 1 AS r UNION ALL SELECT r + 1 FROM n WHERE r < 3
)
SELECT 2, n.r, l.letter, CASE WHEN n.r = 1 THEN 'J' ELSE 'Y' END
FROM n
JOIN (SELECT 'A' AS letter UNION ALL SELECT 'B' UNION ALL SELECT 'C') l;

INSERT INTO aircraft VALUES
 ('C-FBJA',1),
 ('C-FCVN',2);

INSERT INTO flights (flight_id, flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES
 (1,'XA101','YVR','YYZ','2026-10-20 08:00:00','2026-10-20 15:30:00','C-FBJA'),
 (2,'XA202','YYC','YVR','2026-10-21 10:00:00','2026-10-21 10:50:00','C-FBJA'),
 (3,'XA303','YYJ','YLW','2026-10-22 09:00:00','2026-10-22 10:10:00','C-FCVN');

INSERT INTO flight_fares (flight_id, fare_class_code, seats_allocated, overbook_pct, price) VALUES
 (1,'J',24,0,1450.00),
 (1,'W',24,5,890.00),
 (1,'Y',132,8,420.00),
 (2,'Y',132,8,180.00),
 -- Tiny Caravan flight: 6 Economy seats, sell up to FLOOR(6*1.30)=7
 (3,'J',3,0,320.00),
 (3,'Y',6,30,150.00);

INSERT INTO passengers (passenger_id, first_name, last_name, email, tier_id, points) VALUES
 (1,'Ava','Singh','ava@example.com',3,48000),
 (2,'Ben','Chu','ben@example.com',1,1200),
 (3,'Chloe','Park','chloe@example.com',2,15000),
 (4,'Dev','Rao','dev@example.com',1,300),
 (5,'Emma','Li','emma@example.com',4,120000),
 (6,'Finn','Cole','finn@example.com',1,0),
 (7,'Gia','Rossi','gia@example.com',1,50),
 (8,'Hana','Sato','hana@example.com',2,16500);

-- Flight 3 (Caravan): 7 Economy bookings against 6 allocated seats = 1 oversold. Passenger 8 is Business.
INSERT INTO bookings (passenger_id, flight_id, fare_class_code, status, seat_row, seat_letter, booked_at) VALUES
 (8,3,'J','checked_in',1,'A','2026-09-01 09:00:00'),
 (1,3,'Y','confirmed',2,'A','2026-09-02 10:00:00'),
 (2,3,'Y','confirmed',2,'B','2026-09-03 11:00:00'),
 (3,3,'Y','confirmed',2,'C','2026-09-04 12:00:00'),
 (4,3,'Y','confirmed',3,'A','2026-09-05 13:00:00'),
 (5,3,'Y','confirmed',3,'B','2026-09-06 14:00:00'),
 (6,3,'Y','confirmed',3,'C','2026-09-07 15:00:00'),
 (7,3,'Y','confirmed',NULL,NULL,'2026-09-08 16:00:00');

-- A few bookings on the 737 flights
INSERT INTO bookings (passenger_id, flight_id, fare_class_code, status, seat_row, seat_letter, booked_at) VALUES
 (5,1,'J','confirmed',1,'A','2026-09-10 08:00:00'),
 (1,1,'Y','confirmed',9,'A','2026-09-11 08:00:00'),
 (2,2,'Y','confirmed',NULL,NULL,'2026-09-12 08:00:00');
