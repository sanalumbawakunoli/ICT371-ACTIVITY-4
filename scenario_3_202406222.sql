-- scenario_3_student_number.sql
-- PostgreSQL PL/pgSQL Implementation

DROP TABLE IF EXISTS equipment_rentals CASCADE;
DROP TABLE IF EXISTS equipment CASCADE;

-- ============================================
-- 1. Create tables
-- ============================================
CREATE TABLE equipment (
    equipment_id       SERIAL PRIMARY KEY,
    equipment_name     VARCHAR(100) NOT NULL,
    available_units    INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE equipment_rentals (
    rental_id          SERIAL PRIMARY KEY,
    equipment_id       INTEGER REFERENCES equipment(equipment_id),
    borrower_name      VARCHAR(100),
    units              INTEGER,
    status             VARCHAR(20) DEFAULT 'ACTIVE'
);

INSERT INTO equipment (equipment_name, available_units) VALUES
('Football', 15),
('Basketball', 3),
('Tennis Racket', 0);

-- ============================================
-- 2. IF ELSIF ELSE - stock status of one equipment
-- ============================================
DO $$
DECLARE
    v_avail INTEGER;
    v_name  VARCHAR(100);
BEGIN
    SELECT equipment_name, available_units INTO v_name, v_avail
    FROM equipment WHERE equipment_id = 2;

    IF v_avail = 0 THEN
        RAISE NOTICE 'Equipment "%" is OUT OF STOCK.', v_name;
    ELSIF v_avail <= 3 THEN
        RAISE NOTICE 'Equipment "%" is LOW (% left).', v_name, v_avail;
    ELSE
        RAISE NOTICE 'Equipment "%" has SUFFICIENT stock (% left).', v_name, v_avail;
    END IF;
END $$;

-- ============================================
-- 3. WHILE + numeric FOR
-- ============================================
DO $$
DECLARE i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Equipment Maintenance Reminder #%', i;
        i := i + 1;
    END LOOP;
END $$;

DO $$
BEGIN
    FOR n IN 1..3 LOOP
        RAISE NOTICE 'Inventory Check #%', n;
    END LOOP;
END $$;

-- ============================================
-- 4. rent_equipment procedure
-- ============================================
CREATE OR REPLACE PROCEDURE rent_equipment(
    p_equipment_id INTEGER,
    p_borrower     VARCHAR,
    p_units        INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INTEGER;
BEGIN
    IF p_units <= 0 THEN
        RAISE EXCEPTION 'Invalid units: %', p_units;
    END IF;

    SELECT available_units INTO v_avail
    FROM equipment WHERE equipment_id = p_equipment_id FOR UPDATE;

    IF v_avail IS NULL THEN
        RAISE EXCEPTION 'Equipment % not found', p_equipment_id;
    END IF;

    IF v_avail >= p_units THEN
        UPDATE equipment
        SET available_units = available_units - p_units
        WHERE equipment_id = p_equipment_id;

        INSERT INTO equipment_rentals (equipment_id, borrower_name, units, status)
        VALUES (p_equipment_id, p_borrower, p_units, 'ACTIVE');

        RAISE NOTICE 'Rented % units of equipment % to %.',
            p_units, p_equipment_id, p_borrower;
    ELSE
        RAISE NOTICE 'Cannot rent % units. Only % available.',
            p_units, v_avail;
    END IF;
END $$;

-- ============================================
-- 5. Calls: 2 valid + 1 exceeding
-- ============================================
CALL rent_equipment(1, 'John Mwanza', 4);
CALL rent_equipment(1, 'Mary Zulu', 2);
CALL rent_equipment(2, 'Peter Banda', 10); -- exceeds

SELECT * FROM equipment;
SELECT * FROM equipment_rentals;

-- ============================================
-- 6. return_equipment procedure
-- ============================================
CREATE OR REPLACE PROCEDURE return_equipment(p_rental_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status       VARCHAR(20);
    v_equipment_id INTEGER;
    v_units        INTEGER;
BEGIN
    SELECT status, equipment_id, units
    INTO v_status, v_equipment_id, v_units
    FROM equipment_rentals WHERE rental_id = p_rental_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rental % not found', p_rental_id;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Rental % already returned. No stock restored.', p_rental_id;
    ELSE
        UPDATE equipment_rentals SET status = 'RETURNED'
        WHERE rental_id = p_rental_id;

        UPDATE equipment
        SET available_units = available_units + v_units
        WHERE equipment_id = v_equipment_id;

        RAISE NOTICE 'Rental % returned. % units restored.', p_rental_id, v_units;
    END IF;
END $$;

CALL return_equipment(1);
CALL return_equipment(1); -- must NOT restore again

-- ============================================
-- 7. Explicit cursor - equipment with few units
-- ============================================
DO $$
DECLARE
    cur CURSOR FOR
        SELECT equipment_id, equipment_name, available_units
        FROM equipment WHERE available_units <= 3;
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: Equipment % - "%" (% left)',
            rec.equipment_id, rec.equipment_name, rec.available_units;
    END LOOP;
    CLOSE cur;
END $$;

-- ============================================
-- 8. Zero units with EXCEPTION
-- ============================================
DO $$
BEGIN
    CALL rent_equipment(1, 'Test User', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught: %', SQLERRM;
END $$;

-- ============================================
-- 9. Final query
-- ============================================
SELECT * FROM equipment;
SELECT * FROM equipment_rentals;