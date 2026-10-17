-- Zoriyon Zion (V01029666)
-- CSC 370 Term Project: Airline Seat Reservation with Overbooking
-- Sprint 1 version. Changes since the kick-off:
--   1. seats was NOT in BCNF: the cabin depends on (type_id, seat_row), which is not a key
--      of seats. I split the row-to-cabin fact out into a new table, cabin_rows.
--   2. A booked seat must now exist on the flight's aircraft type (Goal 1), enforced with triggers.
--   3. bump_events is now modelled as a subclass of bookings: it shares the booking's identifier.
-- To build the whole database in one go: mysql -u root < schema.sql
-- Needs MySQL 8.0.16 or newer (CHECK constraints, window functions, recursive CTEs).

-- I start from a clean slate every time so I can re-run this file as often as I like.
-- Careful: this wipes any existing "airline" database!
DROP DATABASE IF EXISTS airline;
CREATE DATABASE airline CHARACTER SET utf8mb4;
USE airline;


-- ---------------------------------------------------------------
-- Reference tables
-- ---------------------------------------------------------------

-- Airports, keyed by the 3-letter IATA code (YYJ, YVR, and so on).
CREATE TABLE airports (
    airport_code CHAR(3)      NOT NULL,
    name         VARCHAR(100) NOT NULL,
    city         VARCHAR(60)  NOT NULL,
    country      VARCHAR(60)  NOT NULL,
    PRIMARY KEY (airport_code)
);

-- Cabin / fare class. priority_rank: higher = bumped LAST.
-- name and priority_rank are both UNIQUE so two cabins can never tie in the bump order.
CREATE TABLE fare_classes (
    fare_class_code CHAR(1)      NOT NULL,
    name            VARCHAR(30)  NOT NULL,
    priority_rank   TINYINT      NOT NULL,
    PRIMARY KEY (fare_class_code),
    UNIQUE (name),
    UNIQUE (priority_rank)
);

-- Loyalty tier. bump_priority: higher = bumped LAST.
CREATE TABLE loyalty_tiers (
    tier_id           TINYINT      NOT NULL,
    tier_name         VARCHAR(20)  NOT NULL,
    bump_priority     TINYINT      NOT NULL,
    points_multiplier DECIMAL(3,2) NOT NULL,
    PRIMARY KEY (tier_id),
    UNIQUE (tier_name),
    UNIQUE (bump_priority)
);


-- ---------------------------------------------------------------
-- Aircraft: model (type) vs physical plane, and the seat map
-- ---------------------------------------------------------------

-- One row per aircraft MODEL (e.g. a 737 or a Caravan).
CREATE TABLE aircraft_types (
    type_id      INT          NOT NULL AUTO_INCREMENT,
    model        VARCHAR(50)  NOT NULL,
    manufacturer VARCHAR(50)  NOT NULL,
    PRIMARY KEY (type_id),
    UNIQUE (model)
);

-- NEW in Sprint 1. One row per seat ROW of a model, and which cabin that row is in.
-- This is a weak entity set: a row only has meaning inside its aircraft type, so its
-- identifier is (type_id, seat_row). Putting the cabin here (instead of on each seat)
-- is what fixes the BCNF violation: (type_id, seat_row) -> fare_class_code, and that
-- left side is now a key of this table.
CREATE TABLE cabin_rows (
    type_id         INT      NOT NULL,
    seat_row        TINYINT  NOT NULL,
    fare_class_code CHAR(1)  NOT NULL,
    PRIMARY KEY (type_id, seat_row),
    FOREIGN KEY (type_id)         REFERENCES aircraft_types (type_id),
    FOREIGN KEY (fare_class_code) REFERENCES fare_classes (fare_class_code)
);

-- One row per physical seat. Another weak entity set, identified through its row.
-- A seat has no non-key attributes left: its cabin comes from its row.
CREATE TABLE seats (
    type_id     INT      NOT NULL,
    seat_row    TINYINT  NOT NULL,
    seat_letter CHAR(1)  NOT NULL,
    PRIMARY KEY (type_id, seat_row, seat_letter),
    FOREIGN KEY (type_id, seat_row) REFERENCES cabin_rows (type_id, seat_row)
);

-- One row per actual plane in the fleet, identified by its tail number.
CREATE TABLE aircraft (
    tail_number VARCHAR(10) NOT NULL,
    type_id     INT         NOT NULL,
    PRIMARY KEY (tail_number),
    FOREIGN KEY (type_id) REFERENCES aircraft_types (type_id)
);


-- ---------------------------------------------------------------
-- Flights
-- ---------------------------------------------------------------

-- A flight is one scheduled trip: a route, a time window, and a specific plane.
CREATE TABLE flights (
    flight_id      INT         NOT NULL AUTO_INCREMENT,
    flight_number  VARCHAR(8)  NOT NULL,
    origin         CHAR(3)     NOT NULL,
    destination    CHAR(3)     NOT NULL,
    departure_time DATETIME    NOT NULL,
    arrival_time   DATETIME    NOT NULL,
    tail_number    VARCHAR(10) NOT NULL,
    PRIMARY KEY (flight_id),
    UNIQUE (flight_number, departure_time),
    FOREIGN KEY (origin)      REFERENCES airports (airport_code),
    FOREIGN KEY (destination) REFERENCES airports (airport_code),
    FOREIGN KEY (tail_number) REFERENCES aircraft (tail_number),
    CHECK (origin <> destination),
    CHECK (arrival_time > departure_time)
);

-- Per flight and fare class: seats for sale, overbooking percentage and price.
-- Max sellable = FLOOR(seats_allocated * (1 + overbook_pct/100))
-- In the ERD this is a weak entity set (FlightFare) identified by a flight AND a fare class.
CREATE TABLE flight_fares (
    flight_id       INT          NOT NULL,
    fare_class_code CHAR(1)      NOT NULL,
    seats_allocated SMALLINT     NOT NULL,
    overbook_pct    DECIMAL(5,2) NOT NULL DEFAULT 0,
    price           DECIMAL(8,2) NOT NULL,
    PRIMARY KEY (flight_id, fare_class_code),
    FOREIGN KEY (flight_id)       REFERENCES flights (flight_id),
    FOREIGN KEY (fare_class_code) REFERENCES fare_classes (fare_class_code),
    CHECK (seats_allocated >= 0),
    CHECK (overbook_pct >= 0),
    CHECK (price >= 0)
);


-- ---------------------------------------------------------------
-- Passengers and bookings
-- ---------------------------------------------------------------

CREATE TABLE passengers (
    passenger_id INT          NOT NULL AUTO_INCREMENT,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(100) NOT NULL,
    tier_id      TINYINT      NOT NULL DEFAULT 1,
    points       INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (passenger_id),
    UNIQUE (email),
    FOREIGN KEY (tier_id) REFERENCES loyalty_tiers (tier_id),
    CHECK (points >= 0)
);

-- A booking links one passenger to one flight in one fare class.
-- Seat is NULL until check-in. Seat is unique per flight (MySQL allows many NULLs).
-- There is deliberately NO foreign key from the seat to the seats table here. A seat
-- belongs to an aircraft TYPE, and a booking only knows its FLIGHT, so a plain foreign
-- key cannot say "this seat exists on this flight's plane". The two triggers below do.
-- (See README: Design decision for Goal 1.)
CREATE TABLE bookings (
    booking_id      INT         NOT NULL AUTO_INCREMENT,
    passenger_id    INT         NOT NULL,
    flight_id       INT         NOT NULL,
    fare_class_code CHAR(1)     NOT NULL,
    status          ENUM('confirmed','checked_in','bumped','cancelled') NOT NULL DEFAULT 'confirmed',
    seat_row        TINYINT     NULL,
    seat_letter     CHAR(1)     NULL,
    booked_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (booking_id),
    UNIQUE (passenger_id, flight_id),
    UNIQUE (flight_id, seat_row, seat_letter),
    FOREIGN KEY (passenger_id) REFERENCES passengers (passenger_id),
    FOREIGN KEY (flight_id, fare_class_code)
        REFERENCES flight_fares (flight_id, fare_class_code),
    CHECK ((seat_row IS NULL AND seat_letter IS NULL)
        OR (seat_row IS NOT NULL AND seat_letter IS NOT NULL))
);

-- A bump is a special kind of booking, so bump_events is a SUBCLASS of bookings (ISA).
-- It reuses the booking's identifier as its own primary key, instead of having its own
-- bump_id. That one-to-one link is exactly what makes the table a subclass.
CREATE TABLE bump_events (
    booking_id          INT          NOT NULL,
    bumped_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason              VARCHAR(100) NOT NULL,
    compensation_amount DECIMAL(8,2) NOT NULL,
    rebooked_flight_id  INT          NULL,    -- NULL if the passenger wasn't rebooked
    PRIMARY KEY (booking_id),
    FOREIGN KEY (booking_id)         REFERENCES bookings (booking_id),
    FOREIGN KEY (rebooked_flight_id) REFERENCES flights (flight_id),
    CHECK (compensation_amount >= 0)
);


-- ---------------------------------------------------------------
-- Goal 1: a booked seat must exist on the flight's aircraft type
-- ---------------------------------------------------------------
-- Two rules, checked whenever a booking with a seat is inserted or changed:
--   (a) the seat exists on the aircraft type that flies this flight
--   (b) the seat's cabin matches the fare class that was booked
-- I need both an INSERT and an UPDATE trigger, otherwise someone could dodge the
-- check by inserting without a seat and then updating one in. The bodies are identical.

DELIMITER //

CREATE TRIGGER bookings_seat_check_insert
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE seat_cabin CHAR(1);
    -- Only fully assigned seats are checked. A half-assigned seat (row without letter, or the
    -- reverse) is left for the CHECK constraint above, which rejects it for the right reason.
    IF NEW.seat_row IS NOT NULL AND NEW.seat_letter IS NOT NULL THEN
        -- Follow flight -> plane -> aircraft type -> row -> seat. If there is no such
        -- seat the subquery returns no rows, so seat_cabin stays NULL.
        SET seat_cabin = (
            SELECT cr.fare_class_code
            FROM flights f
            JOIN aircraft a    ON a.tail_number = f.tail_number
            JOIN seats s       ON s.type_id = a.type_id
                              AND s.seat_row = NEW.seat_row
                              AND s.seat_letter = NEW.seat_letter
            JOIN cabin_rows cr ON cr.type_id = s.type_id AND cr.seat_row = s.seat_row
            WHERE f.flight_id = NEW.flight_id
        );
        IF seat_cabin IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Seat does not exist on this flight''s aircraft type';
        ELSEIF seat_cabin <> NEW.fare_class_code THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Seat is in a different cabin than the booked fare class';
        END IF;
    END IF;
END//

CREATE TRIGGER bookings_seat_check_update
BEFORE UPDATE ON bookings
FOR EACH ROW
BEGIN
    DECLARE seat_cabin CHAR(1);
    -- Only fully assigned seats are checked. A half-assigned seat (row without letter, or the
    -- reverse) is left for the CHECK constraint above, which rejects it for the right reason.
    IF NEW.seat_row IS NOT NULL AND NEW.seat_letter IS NOT NULL THEN
        SET seat_cabin = (
            SELECT cr.fare_class_code
            FROM flights f
            JOIN aircraft a    ON a.tail_number = f.tail_number
            JOIN seats s       ON s.type_id = a.type_id
                              AND s.seat_row = NEW.seat_row
                              AND s.seat_letter = NEW.seat_letter
            JOIN cabin_rows cr ON cr.type_id = s.type_id AND cr.seat_row = s.seat_row
            WHERE f.flight_id = NEW.flight_id
        );
        IF seat_cabin IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Seat does not exist on this flight''s aircraft type';
        ELSEIF seat_cabin <> NEW.fare_class_code THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Seat is in a different cabin than the booked fare class';
        END IF;
    END IF;
END//

DELIMITER ;
