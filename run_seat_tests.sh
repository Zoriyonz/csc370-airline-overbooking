#!/usr/bin/env bash
# Zoriyon Zion (V01029666)
# Sprint 1, Goal 1: automated evidence for the seat rules.
# Success criterion: 3 invalid seat assignments are rejected and 3 valid ones are accepted.
# I added a 4th invalid test (UPDATE) because a rule that only guards INSERT can be dodged.
#
# Run (after schema.sql and seed.sql):  bash run_seat_tests.sh
#
# Every test runs inside its own transaction that is rolled back (or never commits), so
# the sample data is never changed. Each test makes its own throwaway passenger (id 99)
# so a duplicate-booking error can never hide the real reason for a rejection.

MYSQL="mysql -u root airline"
pass=0
fail=0

# A valid test must succeed. An invalid test must fail AND mention the expected message.
valid() {   # valid "description" "SQL"
    if $MYSQL -e "START TRANSACTION; $2 ROLLBACK;" >/dev/null 2>&1; then
        echo "PASS  accepted: $1"; pass=$((pass+1))
    else
        echo "FAIL  should have been accepted: $1"; fail=$((fail+1))
    fi
}
invalid() { # invalid "description" "expected message fragment" "SQL"
    out=$($MYSQL -e "START TRANSACTION; $3 ROLLBACK;" 2>&1)
    if [ $? -ne 0 ] && echo "$out" | grep -q "$2"; then
        echo "PASS  rejected: $1"; pass=$((pass+1))
    else
        echo "FAIL  should have been rejected ($2): $1"; echo "      got: $out"; fail=$((fail+1))
    fi
}

NEWP="INSERT INTO passengers (passenger_id, first_name, last_name, email) VALUES (99,'Test','Passenger','t@example.com');"

echo "=== Valid seat assignments (3 must be accepted) ==="
valid "Economy seat 10A on the 737 (flight 1)" \
  "$NEWP INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,1,'Y',10,'A');"
valid "Premium Economy seat 5F on the 737 (flight 1)" \
  "$NEWP INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,1,'W',5,'F');"
valid "Business seat 1C on the Caravan (flight 3, fare J)" \
  "$NEWP INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,3,'J',1,'C');"

echo
echo "=== Invalid seat assignments (must be rejected) ==="
invalid "seat 31A does not exist on the 737 (30 rows)" "does not exist on this flight" \
  "$NEWP INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,1,'Y',31,'A');"
invalid "seat 9A does not exist on the Caravan (3 rows, letters A-C)" "does not exist on this flight" \
  "$NEWP INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,3,'Y',9,'A');"
invalid "Economy ticket in Business seat 1B (cabin mismatch)" "different cabin" \
  "$NEWP INSERT INTO bookings (passenger_id, flight_id, fare_class_code, seat_row, seat_letter) VALUES (99,1,'Y',1,'B');"
invalid "UPDATE moving an existing booking to nonexistent seat 40A" "does not exist on this flight" \
  "UPDATE bookings SET seat_row = 40, seat_letter = 'A' WHERE passenger_id = 1 AND flight_id = 1;"

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
