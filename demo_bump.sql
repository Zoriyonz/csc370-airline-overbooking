-- Zoriyon Zion (V01029666)
-- Sprint 1, Goal 3 demo: bump_events as a SUBCLASS of bookings.
-- A bump event has the same identifier as its booking, so "who was bumped and what did
-- they get" is just bookings joined to bump_events on booking_id.
-- Everything runs inside a transaction that I roll back at the end, so the sample data
-- is unchanged afterwards. Run with: mysql -u root -t < demo_bump.sql
USE airline;

START TRANSACTION;

-- Before: flight 3 Economy is oversold by 1 (Q3).
SELECT 'BEFORE' AS stage, ff.seats_allocated, COUNT(b.booking_id) AS active_bookings
FROM flight_fares ff
JOIN bookings b ON b.flight_id = ff.flight_id AND b.fare_class_code = ff.fare_class_code
WHERE ff.flight_id = 3 AND ff.fare_class_code = 'Y' AND b.status IN ('confirmed','checked_in')
GROUP BY ff.seats_allocated;

-- 1. Gia (passenger 7) is the bump that Q4 picked. Her booking becomes 'bumped'.
UPDATE bookings SET status = 'bumped' WHERE passenger_id = 7 AND flight_id = 3;

-- 2. Record the bump. The subclass row reuses her booking_id as its identifier.
INSERT INTO bump_events (booking_id, reason, compensation_amount)
SELECT booking_id, 'Oversold at check-in', 400.00
FROM bookings WHERE passenger_id = 7 AND flight_id = 3;

-- 3. Superclass + subclass together: ordinary booking fields plus bump-only fields.
SELECT b.booking_id, p.first_name, p.last_name, b.status,
       e.reason, e.compensation_amount, e.rebooked_flight_id
FROM bookings b
JOIN bump_events e ON e.booking_id = b.booking_id
JOIN passengers p ON p.passenger_id = b.passenger_id;

-- After: the flight is exactly full instead of oversold.
SELECT 'AFTER' AS stage, ff.seats_allocated, COUNT(b.booking_id) AS active_bookings
FROM flight_fares ff
JOIN bookings b ON b.flight_id = ff.flight_id AND b.fare_class_code = ff.fare_class_code
WHERE ff.flight_id = 3 AND ff.fare_class_code = 'Y' AND b.status IN ('confirmed','checked_in')
GROUP BY ff.seats_allocated;

ROLLBACK;

-- Proof the demo left no trace: this returns 0.
SELECT COUNT(*) AS bump_events_left FROM bump_events;
