-- scenario_2_student_number.sql

DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;

-- ============================================
-- 1. Create tables
-- ============================================
CREATE TABLE lab_sessions (
    session_id            SERIAL PRIMARY KEY,
    session_name          VARCHAR(100) NOT NULL,
    available_workstations INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE reservations (
    reservation_id    SERIAL PRIMARY KEY,
    session_id        INTEGER REFERENCES lab_sessions(session_id),
    lecturer          VARCHAR(100),
    workstations      INTEGER,
    status            VARCHAR(20) DEFAULT 'ACTIVE'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('Monday Morning Lab', 20),
('Wednesday Afternoon Lab', 5),
('Friday Practical', 0);

-- ============================================
-- 2. IF ELSIF ELSE
-- ============================================
DO $$
DECLARE
    v_avail INTEGER;
    v_name  VARCHAR(100);
BEGIN
    SELECT session_name, available_workstations INTO v_name, v_avail
    FROM lab_sessions WHERE session_id = 2;

    IF v_avail = 0 THEN
        RAISE NOTICE 'Session "%" is FULL.', v_name;
    ELSIF v_avail <= 5 THEN
        RAISE NOTICE 'Session "%" is NEARLY FULL (% left).', v_name, v_avail;
    ELSE
        RAISE NOTICE 'Session "%" has ENOUGH workstations (% left).', v_name, v_avail;
    END IF;
END $$;

-- ============================================
-- 3. WHILE + numeric FOR
-- ============================================
DO $$
DECLARE i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Session Preparation Reminder #%', i;
        i := i + 1;
    END LOOP;
END $$;

DO $$
BEGIN
    FOR n IN 1..3 LOOP
        RAISE NOTICE 'Workstation Check #%', n;
    END LOOP;
END $$;

-- ============================================
-- 4. reserve_workstations procedure
-- ============================================
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id   INTEGER,
    p_lecturer     VARCHAR,
    p_workstations INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INTEGER;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Invalid workstation count: %', p_workstations;
    END IF;

    SELECT available_workstations INTO v_avail
    FROM lab_sessions WHERE session_id = p_session_id FOR UPDATE;

    IF v_avail IS NULL THEN
        RAISE EXCEPTION 'Session % not found', p_session_id;
    END IF;

    IF v_avail >= p_workstations THEN
        UPDATE lab_sessions
        SET available_workstations = available_workstations - p_workstations
        WHERE session_id = p_session_id;

        INSERT INTO reservations (session_id, lecturer, workstations, status)
        VALUES (p_session_id, p_lecturer, p_workstations, 'ACTIVE');

        RAISE NOTICE 'Reserved % workstations for % in session %.',
            p_workstations, p_lecturer, p_session_id;
    ELSE
        RAISE NOTICE 'Cannot reserve % workstations. Only % available.',
            p_workstations, v_avail;
    END IF;
END $$;

-- ============================================
-- 5. Calls: 2 valid + 1 exceeding
-- ============================================
CALL reserve_workstations(1, 'Dr. Banda', 5);
CALL reserve_workstations(1, 'Prof. Phiri', 3);
CALL reserve_workstations(2, 'Dr. Tembo', 10); -- exceeds

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- ============================================
-- 6. cancel_reservation procedure
-- ============================================
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status     VARCHAR(20);
    v_session_id INTEGER;
    v_ws         INTEGER;
BEGIN
    SELECT status, session_id, workstations
    INTO v_status, v_session_id, v_ws
    FROM reservations WHERE reservation_id = p_reservation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % not found', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % already cancelled. No release.', p_reservation_id;
    ELSE
        UPDATE reservations SET status = 'CANCELLED'
        WHERE reservation_id = p_reservation_id;

        UPDATE lab_sessions
        SET available_workstations = available_workstations + v_ws
        WHERE session_id = v_session_id;

        RAISE NOTICE 'Reservation % cancelled. % workstations released.',
            p_reservation_id, v_ws;
    END IF;
END $$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);  -- second must not release again

-- ============================================
-- 7. Explicit cursor - sessions with few workstations
-- ============================================
DO $$
DECLARE
    cur CURSOR FOR
        SELECT session_id, session_name, available_workstations
        FROM lab_sessions WHERE available_workstations <= 5;
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low availability: Session % - "%" (% left)',
            rec.session_id, rec.session_name, rec.available_workstations;
    END LOOP;
    CLOSE cur;
END $$;

-- ============================================
-- 8. Zero workstations with EXCEPTION
-- ============================================
DO $$
BEGIN
    CALL reserve_workstations(1, 'Dr. Mwale', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught: %', SQLERRM;
END $$;

-- ============================================
-- 9. Final query
-- ============================================
SELECT * FROM lab_sessions;
SELECT * FROM reservations;