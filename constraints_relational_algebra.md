**Zoriyon Zion (V01029666)**

# Constraints in relational algebra (Sprint 1, Goal 2)

Every key, foreign key and rule in `schema.sql`, written in the notation of Lesson 08 and linked to a test in `run_constraint_tests.sh` (same ID). Two forms are used, as in the lesson: `Query = ∅` (nothing violating the rule exists) and `π(R) ⊆ π(S)` (inclusion, for referential integrity). `ρ` renames a relation so a table can be joined to itself.

**Run the tests:** `bash run_constraint_tests.sh` (and `bash run_seat_tests.sh` for the seat rules).

Counts: 12 primary keys, 9 other candidate keys, 14 foreign keys (+3 delete-side tests), 8 CHECK rules, 2 seat rules. The kick-off schema had 13 foreign keys. It is 14 now because the cabin moved from `seats` into the new `cabin_rows` table.


## Primary keys

**`PK-airports`**: No two tuples of Airports agree on the key (airport_code) but differ elsewhere.

```
σ_{t1.name ≠ t2.name ∨ t1.city ≠ t2.city ∨ t1.country ≠ t2.country}(ρ_{t1}(Airports) ⋈_{t1.airport_code = t2.airport_code} ρ_{t2}(Airports)) = ∅
```

**`PK-fare_classes`**: No two tuples of FareClasses agree on the key (fare_class_code) but differ elsewhere.

```
σ_{t1.name ≠ t2.name ∨ t1.priority_rank ≠ t2.priority_rank}(ρ_{t1}(FareClasses) ⋈_{t1.fare_class_code = t2.fare_class_code} ρ_{t2}(FareClasses)) = ∅
```

**`PK-loyalty_tiers`**: No two tuples of LoyaltyTiers agree on the key (tier_id) but differ elsewhere.

```
σ_{t1.tier_name ≠ t2.tier_name ∨ t1.bump_priority ≠ t2.bump_priority ∨ t1.points_multiplier ≠ t2.points_multiplier}(ρ_{t1}(LoyaltyTiers) ⋈_{t1.tier_id = t2.tier_id} ρ_{t2}(LoyaltyTiers)) = ∅
```

**`PK-aircraft_types`**: No two tuples of AircraftTypes agree on the key (type_id) but differ elsewhere.

```
σ_{t1.model ≠ t2.model ∨ t1.manufacturer ≠ t2.manufacturer}(ρ_{t1}(AircraftTypes) ⋈_{t1.type_id = t2.type_id} ρ_{t2}(AircraftTypes)) = ∅
```

**`PK-cabin_rows`**: No two tuples of CabinRows agree on the key (type_id, seat_row) but differ elsewhere.

```
σ_{t1.fare_class_code ≠ t2.fare_class_code}(ρ_{t1}(CabinRows) ⋈_{t1.type_id = t2.type_id ∧ t1.seat_row = t2.seat_row} ρ_{t2}(CabinRows)) = ∅
```

**`PK-seats`**: (type_id, seat_row, seat_letter) is the whole tuple of Seats, so it is unique by definition.

```
Trivially true: every attribute is part of the key, so two tuples that agree on the key are the same tuple. (The test below still shows the DBMS rejects a duplicate.)
```

**`PK-aircraft`**: No two tuples of Aircraft agree on the key (tail_number) but differ elsewhere.

```
σ_{t1.type_id ≠ t2.type_id}(ρ_{t1}(Aircraft) ⋈_{t1.tail_number = t2.tail_number} ρ_{t2}(Aircraft)) = ∅
```

**`PK-flights`**: No two tuples of Flights agree on the key (flight_id) but differ elsewhere.

```
σ_{t1.flight_number ≠ t2.flight_number ∨ t1.origin ≠ t2.origin ∨ t1.destination ≠ t2.destination ∨ t1.departure_time ≠ t2.departure_time ∨ t1.arrival_time ≠ t2.arrival_time ∨ t1.tail_number ≠ t2.tail_number}(ρ_{t1}(Flights) ⋈_{t1.flight_id = t2.flight_id} ρ_{t2}(Flights)) = ∅
```

**`PK-flight_fares`**: No two tuples of FlightFares agree on the key (flight_id, fare_class_code) but differ elsewhere.

```
σ_{t1.seats_allocated ≠ t2.seats_allocated ∨ t1.overbook_pct ≠ t2.overbook_pct ∨ t1.price ≠ t2.price}(ρ_{t1}(FlightFares) ⋈_{t1.flight_id = t2.flight_id ∧ t1.fare_class_code = t2.fare_class_code} ρ_{t2}(FlightFares)) = ∅
```

**`PK-passengers`**: No two tuples of Passengers agree on the key (passenger_id) but differ elsewhere.

```
σ_{t1.first_name ≠ t2.first_name ∨ t1.last_name ≠ t2.last_name ∨ t1.email ≠ t2.email ∨ t1.tier_id ≠ t2.tier_id ∨ t1.points ≠ t2.points}(ρ_{t1}(Passengers) ⋈_{t1.passenger_id = t2.passenger_id} ρ_{t2}(Passengers)) = ∅
```

**`PK-bookings`**: No two tuples of Bookings agree on the key (booking_id) but differ elsewhere.

```
σ_{t1.passenger_id ≠ t2.passenger_id ∨ t1.flight_id ≠ t2.flight_id ∨ t1.fare_class_code ≠ t2.fare_class_code ∨ t1.status ≠ t2.status ∨ t1.seat_row ≠ t2.seat_row ∨ t1.seat_letter ≠ t2.seat_letter ∨ t1.booked_at ≠ t2.booked_at}(ρ_{t1}(Bookings) ⋈_{t1.booking_id = t2.booking_id} ρ_{t2}(Bookings)) = ∅
```

**`PK-bump_events`**: No two tuples of BumpEvents agree on the key (booking_id) but differ elsewhere.

```
σ_{t1.bumped_at ≠ t2.bumped_at ∨ t1.reason ≠ t2.reason ∨ t1.compensation_amount ≠ t2.compensation_amount ∨ t1.rebooked_flight_id ≠ t2.rebooked_flight_id}(ρ_{t1}(BumpEvents) ⋈_{t1.booking_id = t2.booking_id} ρ_{t2}(BumpEvents)) = ∅
```


## Other candidate keys (UNIQUE)

**`UQ-aircraft_types-model`**: No two different tuples of AircraftTypes have the same (model).

```
σ_{t1.model = t2.model}(ρ_{t1}(AircraftTypes) ⋈_{t1.type_id ≠ t2.type_id} ρ_{t2}(AircraftTypes)) = ∅
```

**`UQ-fare_classes-name`**: No two different tuples of FareClasses have the same (name).

```
σ_{t1.name = t2.name}(ρ_{t1}(FareClasses) ⋈_{t1.fare_class_code ≠ t2.fare_class_code} ρ_{t2}(FareClasses)) = ∅
```

**`UQ-fare_classes-priority_rank`**: No two different tuples of FareClasses have the same (priority_rank).

```
σ_{t1.priority_rank = t2.priority_rank}(ρ_{t1}(FareClasses) ⋈_{t1.fare_class_code ≠ t2.fare_class_code} ρ_{t2}(FareClasses)) = ∅
```

**`UQ-loyalty_tiers-tier_name`**: No two different tuples of LoyaltyTiers have the same (tier_name).

```
σ_{t1.tier_name = t2.tier_name}(ρ_{t1}(LoyaltyTiers) ⋈_{t1.tier_id ≠ t2.tier_id} ρ_{t2}(LoyaltyTiers)) = ∅
```

**`UQ-loyalty_tiers-bump_priority`**: No two different tuples of LoyaltyTiers have the same (bump_priority).

```
σ_{t1.bump_priority = t2.bump_priority}(ρ_{t1}(LoyaltyTiers) ⋈_{t1.tier_id ≠ t2.tier_id} ρ_{t2}(LoyaltyTiers)) = ∅
```

**`UQ-flights-flight_number+departure_time`**: No two different tuples of Flights have the same (flight_number, departure_time).

```
σ_{t1.flight_number = t2.flight_number ∧ t1.departure_time = t2.departure_time}(ρ_{t1}(Flights) ⋈_{t1.flight_id ≠ t2.flight_id} ρ_{t2}(Flights)) = ∅
```

**`UQ-passengers-email`**: No two different tuples of Passengers have the same (email).

```
σ_{t1.email = t2.email}(ρ_{t1}(Passengers) ⋈_{t1.passenger_id ≠ t2.passenger_id} ρ_{t2}(Passengers)) = ∅
```

**`UQ-bookings-passenger_id+flight_id`**: No two different tuples of Bookings have the same (passenger_id, flight_id).

```
σ_{t1.passenger_id = t2.passenger_id ∧ t1.flight_id = t2.flight_id}(ρ_{t1}(Bookings) ⋈_{t1.booking_id ≠ t2.booking_id} ρ_{t2}(Bookings)) = ∅
```

**`UQ-bookings-flight_id+seat_row+seat_letter`**: No two different tuples of Bookings have the same (flight_id, seat_row, seat_letter).

```
σ_{t1.flight_id = t2.flight_id ∧ t1.seat_row = t2.seat_row ∧ t1.seat_letter = t2.seat_letter}(ρ_{t1}(Bookings) ⋈_{t1.booking_id ≠ t2.booking_id} ρ_{t2}(Bookings)) = ∅
```


## Referential integrity (foreign keys)

**`FK-aircraft-type_id`**: Every (type_id) in Aircraft appears as (type_id) in AircraftTypes.

```
π_{type_id}(Aircraft) ⊆ π_{type_id}(AircraftTypes)
```

**`FK-bookings-passenger_id`**: Every (passenger_id) in Bookings appears as (passenger_id) in Passengers.

```
π_{passenger_id}(Bookings) ⊆ π_{passenger_id}(Passengers)
```

**`FK-bookings-flight_id+fare_class_code`**: Every (flight_id, fare_class_code) in Bookings appears as (flight_id, fare_class_code) in FlightFares.

```
π_{flight_id, fare_class_code}(Bookings) ⊆ π_{flight_id, fare_class_code}(FlightFares)
```

**`FK-bump_events-booking_id`**: Every (booking_id) in BumpEvents appears as (booking_id) in Bookings.

```
π_{booking_id}(BumpEvents) ⊆ π_{booking_id}(Bookings)
```

**`FK-bump_events-rebooked_flight_id`**: Every non-NULL rebooked_flight_id of BumpEvents is a flight_id of Flights. (NULL means 'not rebooked' and is exempt.)

```
π_{rebooked_flight_id}(σ_{rebooked_flight_id ≠ NULL}(BumpEvents)) ⊆ π_{flight_id}(Flights)
```

**`FK-cabin_rows-type_id`**: Every (type_id) in CabinRows appears as (type_id) in AircraftTypes.

```
π_{type_id}(CabinRows) ⊆ π_{type_id}(AircraftTypes)
```

**`FK-cabin_rows-fare_class_code`**: Every (fare_class_code) in CabinRows appears as (fare_class_code) in FareClasses.

```
π_{fare_class_code}(CabinRows) ⊆ π_{fare_class_code}(FareClasses)
```

**`FK-flights-origin`**: Every (origin) in Flights appears as (airport_code) in Airports.

```
π_{origin}(Flights) ⊆ π_{airport_code}(Airports)
```

**`FK-flights-destination`**: Every (destination) in Flights appears as (airport_code) in Airports.

```
π_{destination}(Flights) ⊆ π_{airport_code}(Airports)
```

**`FK-flights-tail_number`**: Every (tail_number) in Flights appears as (tail_number) in Aircraft.

```
π_{tail_number}(Flights) ⊆ π_{tail_number}(Aircraft)
```

**`FK-flight_fares-flight_id`**: Every (flight_id) in FlightFares appears as (flight_id) in Flights.

```
π_{flight_id}(FlightFares) ⊆ π_{flight_id}(Flights)
```

**`FK-flight_fares-fare_class_code`**: Every (fare_class_code) in FlightFares appears as (fare_class_code) in FareClasses.

```
π_{fare_class_code}(FlightFares) ⊆ π_{fare_class_code}(FareClasses)
```

**`FK-passengers-tier_id`**: Every (tier_id) in Passengers appears as (tier_id) in LoyaltyTiers.

```
π_{tier_id}(Passengers) ⊆ π_{tier_id}(LoyaltyTiers)
```

**`FK-seats-type_id+seat_row`**: Every (type_id, seat_row) in Seats appears as (type_id, seat_row) in CabinRows.

```
π_{type_id, seat_row}(Seats) ⊆ π_{type_id, seat_row}(CabinRows)
```

**`FK-delete-airports`**: An airport that a flight departs from or arrives at cannot be deleted.

```
(Same inclusion as above, tested from the parent side: removing the parent tuple would break ⊆.)
```

**`FK-delete-passengers`**: A passenger who has bookings cannot be deleted.

```
(Same inclusion as above, tested from the parent side: removing the parent tuple would break ⊆.)
```

**`FK-delete-flight_fares`**: A fare that bookings were sold under cannot be deleted.

```
(Same inclusion as above, tested from the parent side: removing the parent tuple would break ⊆.)
```


## Value and attribute constraints (CHECK)

**`CK-flights-origin-destination`**: A flight cannot leave and land at the same airport.

```
σ_{origin = destination}(Flights) = ∅
```

**`CK-flights-times`**: A flight cannot land before it takes off.

```
σ_{arrival_time ≤ departure_time}(Flights) = ∅
```

**`CK-flight_fares-seats`**: A fare cannot allocate a negative number of seats.

```
σ_{seats_allocated < 0}(FlightFares) = ∅
```

**`CK-flight_fares-overbook`**: The overbooking percentage cannot be negative.

```
σ_{overbook_pct < 0}(FlightFares) = ∅
```

**`CK-flight_fares-price`**: A price cannot be negative.

```
σ_{price < 0}(FlightFares) = ∅
```

**`CK-passengers-points`**: Loyalty points cannot be negative.

```
σ_{points < 0}(Passengers) = ∅
```

**`CK-bump_events-compensation`**: Bump compensation cannot be negative.

```
σ_{compensation_amount < 0}(BumpEvents) = ∅
```

**`CK-bookings-seat-pair`**: A seat is assigned completely (row AND letter) or not at all.

```
σ_{(seat_row = NULL ∧ seat_letter ≠ NULL) ∨ (seat_row ≠ NULL ∧ seat_letter = NULL)}(Bookings) = ∅   (NULL tests written informally; relational algebra has no NULL operator)
```


## Seat rule (Goal 1): enforced by triggers

**`SEAT-exists`**: Every assigned seat exists on the aircraft type that flies the booking's flight.

```
π_{a.type_id, b.seat_row, b.seat_letter}(σ_{b.seat_row ≠ NULL ∧ b.seat_letter ≠ NULL}(ρ_{b}(Bookings) ⋈_{b.flight_id = f.flight_id} ρ_{f}(Flights) ⋈_{f.tail_number = a.tail_number} ρ_{a}(Aircraft))) ⊆ π_{type_id, seat_row, seat_letter}(Seats)
```

**`SEAT-cabin`**: The cabin of an assigned seat matches the fare class that was booked.

```
σ_{b.fare_class_code ≠ cr.fare_class_code}(ρ_{b}(Bookings) ⋈_{b.flight_id = f.flight_id} ρ_{f}(Flights) ⋈_{f.tail_number = a.tail_number} ρ_{a}(Aircraft) ⋈_{a.type_id = cr.type_id ∧ b.seat_row = cr.seat_row} ρ_{cr}(CabinRows)) = ∅
```


## Rules I can state but do not enforce yet

These hold on the current sample data (the audit tests below confirm it), but nothing in the schema stops a future statement from breaking them. They are my known limitations and the reason Sprint 2 needs transactions and concurrency control.

**`NE-bump-has-bumped-booking`**: Every bump event belongs to a booking whose status is 'bumped'.

```
π_{booking_id}(BumpEvents) ⊆ π_{booking_id}(σ_{status = 'bumped'}(Bookings))
```

**`NE-bumped-booking-has-event`**: Every booking whose status is 'bumped' has a bump event.

```
π_{booking_id}(σ_{status = 'bumped'}(Bookings)) ⊆ π_{booking_id}(BumpEvents)
```

**`NE-max-sellable`**: A fare never sells more than FLOOR(seats_allocated × (1 + overbook_pct/100)) live bookings. This is the overbooking limit itself.

```
σ_{cnt > ⌊seats_allocated × (1 + overbook_pct/100)⌋}(γ_{flight_id, fare_class_code, COUNT(*)→cnt}(σ_{status ∈ {confirmed, checked_in}}(Bookings)) ⋈ FlightFares) = ∅   (needs the extended grouping operator γ, which Lesson 08 does not cover)
```


## Why the seat rule needs triggers and not a foreign key

A foreign key compares columns of *one row* with a key of the parent table. `SEAT-exists` needs the aircraft type of the booking's flight, which is not a column of `bookings`: it is only reachable by joining `Flights` and `Aircraft` (note `a.type_id` on the left of the ⊆). No `FOREIGN KEY` clause can express a left side that comes out of a join, so the rule is enforced by the `BEFORE INSERT` and `BEFORE UPDATE` triggers in `schema.sql`. The alternative, copying `type_id` into `bookings` so a composite foreign key works, would put the dependency `flight_id → type_id` inside `bookings` where `flight_id` is not a key. That violates BCNF (see README).
