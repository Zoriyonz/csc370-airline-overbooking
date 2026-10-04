-- Demo queries for my sprint video.
-- These are the queries I run on camera to show the airline database actually works.
-- To run the whole file: mysql -u root < queries.sql
USE airline;


-- ---------------------------------------------------------------------------
-- Q1: Flight schedule with airport names and aircraft model
-- ---------------------------------------------------------------------------
-- I wanted to start with a query that shows off a real multi-table join.
-- A flight only stores airport codes and a tail number, so to get something
-- a human can read (cities and a plane model) I have to hop through five tables.
-- Note that I join the airports table twice: once for the origin, once for the
-- destination. I use the aliases o and d so I don't lose track of which is which.
SELECT f.flight_number, o.city AS origin, d.city AS destination,
       f.departure_time, t.model
FROM flights f
JOIN airports o ON o.airport_code = f.origin
JOIN airports d ON d.airport_code = f.destination
JOIN aircraft a ON a.tail_number = f.tail_number      -- which physical plane is flying this
JOIN aircraft_types t ON t.type_id = a.type_id        -- and what model that plane is
ORDER BY f.departure_time;                            -- earliest flights first, like a departures board


-- ---------------------------------------------------------------------------
-- Q2: Physical seats per cabin for each aircraft model
-- ---------------------------------------------------------------------------
-- A design decision I'm proud of: the seat map belongs to the aircraft MODEL,
-- not to each individual plane. Every plane of the same type shares one layout,
-- so I don't have to duplicate hundreds of seat rows per tail number.
-- This query proves it by counting seats per cabin for each model.
SELECT t.model, c.name AS cabin, COUNT(*) AS seats
FROM seats s
JOIN aircraft_types t ON t.type_id = s.type_id
JOIN fare_classes c ON c.fare_class_code = s.fare_class_code
GROUP BY t.model, c.name
-- I order by priority_rank descending so the best cabin shows up first within
-- each model. MIN() is there because c.priority_rank isn't in the GROUP BY,
-- and MySQL needs an aggregate for it.
ORDER BY t.model, MIN(c.priority_rank) DESC;


-- ---------------------------------------------------------------------------
-- Q3: Overbooking status per flight and fare class
-- ---------------------------------------------------------------------------
-- Airlines deliberately sell more tickets than seats because some people don't
-- show up. This query is my dashboard for that. For every flight and fare class
-- it shows:
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
-- LEFT JOIN on purpose: I still want fare classes with zero bookings to appear
-- in the results (with a count of 0) instead of silently vanishing.
LEFT JOIN bookings b
       ON b.flight_id = ff.flight_id
      AND b.fare_class_code = ff.fare_class_code
      -- Only count bookings that are still live. Cancelled ones don't use a seat.
      AND b.status IN ('confirmed','checked_in')
GROUP BY f.flight_number, ff.flight_id, ff.fare_class_code, ff.seats_allocated, ff.overbook_pct
ORDER BY f.flight_number, ff.fare_class_code;


-- ---------------------------------------------------------------------------
-- Q4: Bump ranking for flight 3, Economy
-- ---------------------------------------------------------------------------
-- This is the one I'm most excited to demo. When a flight is oversold, someone
-- has to give up their seat, and I wanted that decision to be rule-based and
-- explainable rather than random. My rules, in order:
--   1. Lowest fare class gets bumped first
--   2. Then lowest loyalty tier
--   3. Then whoever booked latest
-- (Since this query is limited to Economy, rule 1 is already satisfied here.)
--
-- How it works: I rank everyone from "most protected" to "least protected"
-- using ROW_NUMBER(). If your rank is higher than the number of real seats
-- (seats_allocated), you don't fit, so you're a bump candidate.
SELECT ranked.*,
       IF(ranked.keep_rank > ranked.seats_allocated, 'BUMP', 'keep') AS decision
FROM (
    SELECT p.first_name, p.last_name, lt.tier_name, b.booked_at,
           ff.seats_allocated,
           -- Rank 1 = safest passenger. A higher bump_priority means more
           -- protected, and among equals the earlier booking wins the seat.
           ROW_NUMBER() OVER (
               ORDER BY lt.bump_priority DESC, b.booked_at ASC
           ) AS keep_rank
    FROM bookings b
    JOIN passengers p ON p.passenger_id = b.passenger_id
    JOIN loyalty_tiers lt ON lt.tier_id = p.tier_id
    JOIN flight_fares ff ON ff.flight_id = b.flight_id AND ff.fare_class_code = b.fare_class_code
    WHERE b.flight_id = 3 AND b.fare_class_code = 'Y'   -- flight 3, Economy only
      AND b.status IN ('confirmed','checked_in')        -- ignore cancelled bookings
) ranked
-- I wrapped the ranking in a subquery because MySQL won't let me filter or
-- compare on a window function result in the same SELECT where it's created.
ORDER BY ranked.keep_rank;


-- ---------------------------------------------------------------------------
-- Q5: Passengers per loyalty tier, with booking counts
-- ---------------------------------------------------------------------------
-- A simple summary to show how my passengers are spread across tiers.
-- I used LEFT JOINs so that a tier with no passengers (or a passenger with no
-- bookings) still shows up as a row of zeros instead of disappearing.
-- COUNT(DISTINCT ...) for passengers is needed because the join to bookings
-- repeats each passenger once per booking, and I don't want to double count them.
SELECT lt.tier_name, COUNT(DISTINCT p.passenger_id) AS passengers, COUNT(b.booking_id) AS bookings
FROM loyalty_tiers lt
LEFT JOIN passengers p ON p.tier_id = lt.tier_id
LEFT JOIN bookings b ON b.passenger_id = p.passenger_id
GROUP BY lt.tier_id, lt.tier_name
ORDER BY lt.bump_priority DESC;   -- highest-priority tier at the top


-- ---------------------------------------------------------------------------
-- Q6: Constraint evidence
-- ---------------------------------------------------------------------------
-- Last, I want to show the database defends itself against bad data.
-- Every statement below is SUPPOSED to fail with an error, and that's the point.
-- I leave them commented out so running the file doesn't blow up halfway.
-- For the video, I uncomment them and run them one at a time.

-- Should fail: a flight can't leave and land at the same airport (CHECK constraint).
-- INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number)
--   VALUES ('XA999','YYJ','YYJ','2026-11-01 08:00:00','2026-11-01 09:00:00','C-FCVN');      -- origin = destination

-- Should fail: flight 2 only sells Economy (Y), so the foreign key to flight_fares
-- rejects a Business (J) booking on it. You can only book a fare class the flight actually sells.
-- INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter)
--   VALUES (6,2,'J',NULL,NULL);                                                              -- flight 2 has no J fare

-- Should fail: seat 9A on flight 1 is already taken (by Ava), and my unique constraint
-- stops two people from holding the same seat on the same flight.
-- INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter)
--   VALUES (6,1,'Y',9,'A');                                                                  -- seat 9A already taken on flight 1

-- Should fail: Finn (passenger 6) already holds a booking on flight 3, and my unique
-- constraint on (passenger_id, flight_id) stops one person booking the same flight twice.
-- INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter)
--   VALUES (6,3,'Y',NULL,NULL);                                                              -- Finn is already on flight 3