#!/usr/bin/env bash
# Zoriyon Zion (V01029666)
# Sprint 1, Goal 2: one failing statement for every constraint in constraints_relational_algebra.md.
# Run (after schema.sql and seed.sql):  bash run_constraint_tests.sh
#
# Each test runs inside a transaction that is rolled back, so the sample data never changes.
# A test PASSES only if the statement is rejected AND the error looks like the one I expect
# (so a statement that fails for some other reason does not count). The three "audit" tests at
# the end are for rules I do NOT enforce yet: they PASS if the current data happens to obey them.

MYSQL="mysql -u root airline"
pass=0; fail=0

expect_fail() {   # expect_fail ID "regex for the error" "SQL"
    out=$($MYSQL -e "START TRANSACTION; $3 ROLLBACK;" 2>&1)
    if [ $? -ne 0 ] && echo "$out" | grep -Eq "$2"; then
        echo "PASS  $1"; pass=$((pass+1))
    else
        echo "FAIL  $1"; echo "      got: $out"; fail=$((fail+1))
    fi
}
audit_empty() {   # audit_empty ID "SQL that returns the violating rows"
    out=$($MYSQL -N -e "$2" 2>&1)
    if [ $? -eq 0 ] && [ -z "$out" ]; then
        echo "PASS  $1 (no violating rows today, but NOT enforced)"; pass=$((pass+1))
    else
        echo "FAIL  $1"; echo "      violating rows: $out"; fail=$((fail+1))
    fi
}

expect_fail "PK-airports" '1062|Duplicate entry' "INSERT INTO airports VALUES ('YYJ','Dup','X','Y');"
expect_fail "PK-fare_classes" '1062|Duplicate entry' "INSERT INTO fare_classes VALUES ('J','Dup',9);"
expect_fail "PK-loyalty_tiers" '1062|Duplicate entry' "INSERT INTO loyalty_tiers VALUES (1,'Dup',9,1.00);"
expect_fail "PK-aircraft_types" '1062|Duplicate entry' "INSERT INTO aircraft_types (type_id, model, manufacturer) VALUES (1,'Dup','X');"
expect_fail "PK-cabin_rows" '1062|Duplicate entry' "INSERT INTO cabin_rows VALUES (1,1,'J');"
expect_fail "PK-seats" '1062|Duplicate entry' "INSERT INTO seats VALUES (1,1,'A');"
expect_fail "PK-aircraft" '1062|Duplicate entry' "INSERT INTO aircraft VALUES ('C-FBJA',2);"
expect_fail "PK-flights" '1062|Duplicate entry' "INSERT INTO flights (flight_id, flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES (1,'ZZ1','YVR','YYC','2026-12-01 08:00:00','2026-12-01 09:00:00','C-FBJA');"
expect_fail "PK-flight_fares" '1062|Duplicate entry' "INSERT INTO flight_fares VALUES (1,'J',1,0,1.00);"
expect_fail "PK-passengers" '1062|Duplicate entry' "INSERT INTO passengers (passenger_id, first_name, last_name, email) VALUES (1,'A','B','pk@example.com');"
expect_fail "PK-bookings" '1062|Duplicate entry' "INSERT INTO bookings (booking_id, passenger_id, flight_id, fare_class_code) VALUES (1,6,1,'Y');"
expect_fail "PK-bump_events" '1062|Duplicate entry' "INSERT INTO bump_events (booking_id, reason, compensation_amount) VALUES (8,'a',0); INSERT INTO bump_events (booking_id, reason, compensation_amount) VALUES (8,'b',0);"
expect_fail "UQ-aircraft_types-model" '1062|Duplicate entry' "INSERT INTO aircraft_types (model, manufacturer) VALUES ('737-800','X');"
expect_fail "UQ-fare_classes-name" '1062|Duplicate entry' "INSERT INTO fare_classes VALUES ('X','Business',9);"
expect_fail "UQ-fare_classes-priority_rank" '1062|Duplicate entry' "INSERT INTO fare_classes VALUES ('X','Other',3);"
expect_fail "UQ-loyalty_tiers-tier_name" '1062|Duplicate entry' "INSERT INTO loyalty_tiers VALUES (9,'Gold',9,1.00);"
expect_fail "UQ-loyalty_tiers-bump_priority" '1062|Duplicate entry' "INSERT INTO loyalty_tiers VALUES (9,'Other',4,1.00);"
expect_fail "UQ-flights-flight_number+departure_time" '1062|Duplicate entry' "INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES ('XA101','YYC','YVR','2026-10-20 08:00:00','2026-10-20 09:00:00','C-FBJA');"
expect_fail "UQ-passengers-email" '1062|Duplicate entry' "INSERT INTO passengers (first_name, last_name, email) VALUES ('A','B','ava@example.com');"
expect_fail "UQ-bookings-passenger_id+flight_id" '1062|Duplicate entry' "INSERT INTO bookings (passenger_id, flight_id, fare_class_code) VALUES (6,3,'Y');"
expect_fail "UQ-bookings-flight_id+seat_row+seat_letter" '1062|Duplicate entry' "INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (6,1,'Y',9,'A');"
expect_fail "FK-aircraft-type_id" '1452|foreign key constraint fails' "INSERT INTO aircraft VALUES ('C-TEST',99);"
expect_fail "FK-bookings-passenger_id" '1452|foreign key constraint fails' "INSERT INTO bookings (passenger_id, flight_id, fare_class_code) VALUES (999,1,'Y');"
expect_fail "FK-bookings-flight_id+fare_class_code" '1452|foreign key constraint fails' "INSERT INTO bookings (passenger_id, flight_id, fare_class_code) VALUES (6,2,'J');"
expect_fail "FK-bump_events-booking_id" '1452|foreign key constraint fails' "INSERT INTO bump_events (booking_id, reason, compensation_amount) VALUES (999,'x',0);"
expect_fail "FK-bump_events-rebooked_flight_id" '1452|foreign key constraint fails' "INSERT INTO bump_events (booking_id, reason, compensation_amount, rebooked_flight_id) VALUES (8,'x',0,999);"
expect_fail "FK-cabin_rows-type_id" '1452|foreign key constraint fails' "INSERT INTO cabin_rows VALUES (99,1,'Y');"
expect_fail "FK-cabin_rows-fare_class_code" '1452|foreign key constraint fails' "INSERT INTO cabin_rows VALUES (1,99,'Z');"
expect_fail "FK-flights-origin" '1452|foreign key constraint fails' "INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES ('T1','XXX','YVR','2026-12-01 08:00:00','2026-12-01 09:00:00','C-FBJA');"
expect_fail "FK-flights-destination" '1452|foreign key constraint fails' "INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES ('T2','YVR','XXX','2026-12-01 08:00:00','2026-12-01 09:00:00','C-FBJA');"
expect_fail "FK-flights-tail_number" '1452|foreign key constraint fails' "INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES ('T3','YVR','YYC','2026-12-01 08:00:00','2026-12-01 09:00:00','C-NONE');"
expect_fail "FK-flight_fares-flight_id" '1452|foreign key constraint fails' "INSERT INTO flight_fares VALUES (99,'Y',10,0,100.00);"
expect_fail "FK-flight_fares-fare_class_code" '1452|foreign key constraint fails' "INSERT INTO flight_fares VALUES (1,'Z',10,0,100.00);"
expect_fail "FK-passengers-tier_id" '1452|foreign key constraint fails' "INSERT INTO passengers (first_name, last_name, email, tier_id) VALUES ('A','B','fk@example.com',9);"
expect_fail "FK-seats-type_id+seat_row" '1452|foreign key constraint fails' "INSERT INTO seats VALUES (1,99,'A');"
expect_fail "FK-delete-airports" '1451|foreign key constraint fails' "DELETE FROM airports WHERE airport_code = 'YYJ';"
expect_fail "FK-delete-passengers" '1451|foreign key constraint fails' "DELETE FROM passengers WHERE passenger_id = 1;"
expect_fail "FK-delete-flight_fares" '1451|foreign key constraint fails' "DELETE FROM flight_fares WHERE flight_id = 3 AND fare_class_code = 'Y';"
expect_fail "CK-flights-origin-destination" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES ('ZZ2','YVR','YVR','2026-12-01 08:00:00','2026-12-01 09:00:00','C-FBJA');"
expect_fail "CK-flights-times" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time, tail_number) VALUES ('ZZ3','YVR','YYC','2026-12-01 09:00:00','2026-12-01 08:00:00','C-FBJA');"
expect_fail "CK-flight_fares-seats" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO flight_fares VALUES (2,'W',-1,0,100.00);"
expect_fail "CK-flight_fares-overbook" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO flight_fares VALUES (2,'W',10,-5,100.00);"
expect_fail "CK-flight_fares-price" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO flight_fares VALUES (2,'W',10,0,-1.00);"
expect_fail "CK-passengers-points" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO passengers (first_name, last_name, email, points) VALUES ('A','B','ck@example.com',-1);"
expect_fail "CK-bump_events-compensation" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO bump_events (booking_id, reason, compensation_amount) VALUES (8,'x',-1);"
expect_fail "CK-bookings-seat-pair" '3819|4025|Check constraint|CONSTRAINT .* failed' "INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (6,1,'Y',5,NULL);"
expect_fail "SEAT-exists" 'does not exist on this flight' "INSERT INTO passengers (passenger_id, first_name, last_name, email) VALUES (99,'Test','Passenger','t@example.com'); INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,1,'Y',31,'A');"
expect_fail "SEAT-cabin" 'different cabin' "INSERT INTO passengers (passenger_id, first_name, last_name, email) VALUES (99,'Test','Passenger','t@example.com'); INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,1,'Y',1,'B');"

echo "--- audits: rules not enforced yet ---"
audit_empty "NE-bump-has-bumped-booking" "SELECT e.booking_id FROM bump_events e WHERE NOT EXISTS (SELECT 1 FROM bookings b WHERE b.booking_id = e.booking_id AND b.status = 'bumped');"
audit_empty "NE-bumped-booking-has-event" "SELECT b.booking_id FROM bookings b WHERE b.status = 'bumped' AND NOT EXISTS (SELECT 1 FROM bump_events e WHERE e.booking_id = b.booking_id);"
audit_empty "NE-max-sellable" "SELECT ff.flight_id, ff.fare_class_code FROM flight_fares ff JOIN bookings b ON b.flight_id = ff.flight_id AND b.fare_class_code = ff.fare_class_code AND b.status IN ('confirmed','checked_in') GROUP BY ff.flight_id, ff.fare_class_code, ff.seats_allocated, ff.overbook_pct HAVING COUNT(*) > FLOOR(ff.seats_allocated * (1 + ff.overbook_pct/100));"

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
