-- Zoriyon Zion (V01029666)
-- Demo queries for my sprint video (Sprint 1 version).
-- To run the whole file: mysql -u root -t < queries.sql
-- Q1, Q3, Q4 and Q5 are unchanged from the kick-off, so their results are the same.
-- Q2 changed because the cabin now lives in cabin_rows instead of seats.
-- The seat rules from Goal 1 are tested in run_seat_tests.sh, and the bump demo is in demo_bump.sql.
USE airline;


-- ---------------------------------------------------------------------------
-- Q1: Flight schedule with airport names and aircraft model
-- ---------------------------------------------------------------------------
-- A flight only stores airport codes and a tail number, so to get cities and a plane
-- model I join through five tables. The airports table is joined twice (origin and
-- destination), with the aliases o and d so I don't mix them up.
SELECT f.flight_number, o.city AS origin, d.city AS destination,
       f.departure_time, t.model
FROM flights f
JOIN airports o ON o.airport_code = f.origin
JOIN airports d ON d.airport_code = f.destination
JOIN aircraft a ON a.tail_number = f.tail_number
JOIN aircraft_types t ON t.type_id = a.type_id
ORDER BY f.departure_time;


-- ---------------------------------------------------------------------------
-- Q2: Physical seats per cabin for each aircraft model
-- ---------------------------------------------------------------------------
-- The seat map belongs to the aircraft MODEL, not to each plane. Since the cabin is now a
-- property of a ROW (cabin_rows), this query goes seats -> cabin_rows -> fare_classes.
-- The counts are the same as at the kick-off, which shows the split lost no information.
SELECT t.model, c.name AS cabin, COUNT(*) AS seats
FROM seats s
JOIN cabin_rows cr ON cr.type_id = s.type_id AND cr.seat_row = s.seat_row
JOIN aircraft_types t ON t.type_id = s.type_id
JOIN fare_classes c ON c.fare_class_code = cr.fare_class_code
GROUP BY t.model, c.name
ORDER BY t.model, MIN(c.priority_rank) DESC;


-- ---------------------------------------------------------------------------
-- Q3: Overbooking status per flight and fare class
-- ---------------------------------------------------------------------------
--   seats_allocated  : how many real seats we have
--   max_sellable     : how many we're allowed to sell, after the overbook percentage
--   active_bookings  : how many people currently hold a live booking
--   oversold_by      : how far past the real seat count we are (never below zero)
SELECT f.flight_number, ff.fare_class_code,
       ff.seats_allocated,
       FLOOR(ff.seats_allocated * (1 + ff.overbook_pct / 100)) AS max_sellable,
       COUNT(b.booking_id) AS active_bookings,
       GREATEST(COUNT(b.booking_id) - ff.seats_allocated, 0) AS oversold_by
FROM flight_fares ff
JOIN flights f ON f.flight_id = ff.flight_id
-- LEFT JOIN on purpose so fare classes with zero bookings still show up with a 0.
LEFT JOIN bookings b
       ON b.flight_id = ff.flight_id
      AND b.fare_class_code = ff.fare_class_code
      AND b.status IN ('confirmed','checked_in')   -- cancelled and bumped ones don't use a seat
GROUP BY f.flight_number, ff.flight_id, ff.fare_class_code, ff.seats_allocated, ff.overbook_pct
ORDER BY f.flight_number, ff.fare_class_code;


-- ---------------------------------------------------------------------------
-- Q4: Bump ranking for flight 3, Economy
-- ---------------------------------------------------------------------------
-- Rule: lowest fare class is bumped first, then lowest loyalty tier, then latest booking.
-- This query is limited to Economy, so rule 1 already holds. I rank everyone from most
-- protected to least protected; if the rank is higher than the real seat count, bump.
SELECT ranked.*,
       IF(ranked.keep_rank > ranked.seats_allocated, 'BUMP', 'keep') AS decision
FROM (
    SELECT p.first_name, p.last_name, lt.tier_name, b.booked_at,
           ff.seats_allocated,
           ROW_NUMBER() OVER (
               ORDER BY lt.bump_priority DESC, b.booked_at ASC
           ) AS keep_rank
    FROM bookings b
    JOIN passengers p ON p.passenger_id = b.passenger_id
    JOIN loyalty_tiers lt ON lt.tier_id = p.tier_id
    JOIN flight_fares ff ON ff.flight_id = b.flight_id AND ff.fare_class_code = b.fare_class_code
    WHERE b.flight_id = 3 AND b.fare_class_code = 'Y'
      AND b.status IN ('confirmed','checked_in')
) ranked
ORDER BY ranked.keep_rank;


-- ---------------------------------------------------------------------------
-- Q5: Passengers per loyalty tier, with booking counts
-- ---------------------------------------------------------------------------
-- LEFT JOINs so a tier with no passengers still shows up as zeros. COUNT(DISTINCT ...)
-- because the join to bookings repeats each passenger once per booking.
SELECT lt.tier_name, COUNT(DISTINCT p.passenger_id) AS passengers, COUNT(b.booking_id) AS bookings
FROM loyalty_tiers lt
LEFT JOIN passengers p ON p.tier_id = lt.tier_id
LEFT JOIN bookings b ON b.passenger_id = p.passenger_id
GROUP BY lt.tier_id, lt.tier_name
ORDER BY lt.bump_priority DESC;


-- ---------------------------------------------------------------------------
-- Q6: Constraint evidence (each statement below is SUPPOSED to fail)
-- ---------------------------------------------------------------------------
-- Commented out so running the file doesn't stop halfway. Run them one at a time with:
--   mysql -u root airline -e "<statement>"

-- CHECK constraint: a flight can't leave and land at the same airport.
-- INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number)
--   VALUES ('XA999','YYJ','YYJ','2026-11-01 08:00:00','2026-11-01 09:00:00','C-FCVN');

-- Foreign key: flight 2 only sells Economy, so a Business booking on it is rejected.
-- INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter)
--   VALUES (6,2,'J',NULL,NULL);

-- Unique key: seat 9A on flight 1 is already taken (by Ava).
-- INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter)
--   VALUES (6,1,'Y',9,'A');

-- Unique key: Finn already has a booking on flight 3.
-- INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter)
--   VALUES (6,3,'Y',NULL,NULL);
