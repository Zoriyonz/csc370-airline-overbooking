-- CSC 370 Term Project: Airline Seat Reservation with Overbooking
-- Kick-off sprint: conceptual -> relational schema, normalised to BCNF
-- Run with:  mysql -u root < schema.sql

DROP DATABASE IF EXISTS airline;
CREATE DATABASE airline CHARACTER SET utf8mb4;
USE airline;

-- ---------------------------------------------------------------
-- Reference tables
-- ---------------------------------------------------------------
CREATE TABLE airports (
    airport_code CHAR(3)      NOT NULL,
    name         VARCHAR(100) NOT NULL,
    city         VARCHAR(60)  NOT NULL,
    country      VARCHAR(60)  NOT NULL,
    PRIMARY KEY (airport_code)
);

-- Cabin / fare class. priority_rank: higher = bumped LAST.
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
-- Aircraft: model (type) vs physical plane
-- Seat map belongs to the MODEL, so it is not repeated per plane.
-- ---------------------------------------------------------------
CREATE TABLE aircraft_types (
    type_id      INT          NOT NULL AUTO_INCREMENT,
    model        VARCHAR(50)  NOT NULL,
    manufacturer VARCHAR(50)  NOT NULL,
    PRIMARY KEY (type_id),
    UNIQUE (model)
);

CREATE TABLE seats (
    type_id         INT      NOT NULL,
    seat_row        TINYINT  NOT NULL,
    seat_letter     CHAR(1)  NOT NULL,
    fare_class_code CHAR(1)  NOT NULL,
    PRIMARY KEY (type_id, seat_row, seat_letter),
    FOREIGN KEY (type_id)         REFERENCES aircraft_types (type_id),
    FOREIGN KEY (fare_class_code) REFERENCES fare_classes (fare_class_code)
);

CREATE TABLE aircraft (
    tail_number VARCHAR(10) NOT NULL,
    type_id     INT         NOT NULL,
    PRIMARY KEY (tail_number),
    FOREIGN KEY (type_id) REFERENCES aircraft_types (type_id)
);

-- ---------------------------------------------------------------
-- Flights
-- ---------------------------------------------------------------
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

-- Per flight and fare class: how many seats are for sale and how far we overbook.
-- Max sellable = FLOOR(seats_allocated * (1 + overbook_pct/100))
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

-- Seat is NULL until check-in. Seat is unique per flight (MySQL allows many NULLs).
-- NOTE (Sprint 2 goal): enforce that the seat exists on the flight's aircraft type.
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

CREATE TABLE bump_events (
    bump_id             INT          NOT NULL AUTO_INCREMENT,
    booking_id          INT          NOT NULL,
    bumped_at           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason              VARCHAR(100) NOT NULL,
    compensation_amount DECIMAL(8,2) NOT NULL,
    rebooked_flight_id  INT          NULL,
    PRIMARY KEY (bump_id),
    UNIQUE (booking_id),
    FOREIGN KEY (booking_id)         REFERENCES bookings (booking_id),
    FOREIGN KEY (rebooked_flight_id) REFERENCES flights (flight_id),
    CHECK (compensation_amount >= 0)
);
