 --scenario_4_student_number.sql

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

-- ============================================
-- 1. Create tables
-- ============================================
CREATE TABLE medicines (
    medicine_id   SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE dispensing_records (
    record_id      SERIAL PRIMARY KEY,
    medicine_id    INTEGER REFERENCES medicines(medicine_id),
    student_number VARCHAR(20),
    quantity       INTEGER,
    status         VARCHAR(20) DEFAULT 'DISPENSED'
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol', 50),
('Amoxicillin', 8),
('Antihistamine', 0);

-- ============================================
-- 2. IF ELSIF ELSE
-- ============================================
DO $$
DECLARE
    v_stock INTEGER;
    v_name  VARCHAR(100);
BEGIN
    SELECT medicine_name, stock_quantity INTO v_name, v_stock
    FROM medicines WHERE medicine_id = 2;

    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine "%" is OUT OF STOCK.', v_name;
    ELSIF v_stock <= 10 THEN
        RAISE NOTICE 'Medicine "%" is LOW ON STOCK (% left).', v_name, v_stock;
    ELSE
        RAISE NOTICE 'Medicine "%" is SUFFICIENTLY STOCKED (% units).', v_name, v_stock;
    END IF;
END $$;

-- ============================================
-- 3. WHILE + numeric FOR
-- ============================================
DO $$
DECLARE i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock Review Day #%', i;
        i := i + 1;
    END LOOP;
END $$;

DO $$
BEGIN
    FOR n IN 1..3 LOOP
        RAISE NOTICE 'Shelf Inspection #%', n;
    END LOOP;
END $$;

-- ============================================
-- 4. dispense_medicine procedure
-- ============================================
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id    INTEGER,
    p_student_number VARCHAR,
    p_quantity       INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid dispensing quantity: %', p_quantity;
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines WHERE medicine_id = p_medicine_id FOR UPDATE;

    IF v_stock IS NULL THEN
        RAISE EXCEPTION 'Medicine % not found', p_medicine_id;
    END IF;

    IF v_stock >= p_quantity THEN
        UPDATE medicines
        SET stock_quantity = stock_quantity - p_quantity
        WHERE medicine_id = p_medicine_id;

        INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
        VALUES (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

        RAISE NOTICE 'Dispensed % units of medicine % to student %.',
            p_quantity, p_medicine_id, p_student_number;
    ELSE
        RAISE NOTICE 'Cannot dispense % units. Only % in stock.',
            p_quantity, v_stock;
    END IF;
END $$;

-- ============================================
-- 5. Calls: 2 valid + 1 exceeding stock
-- ============================================
CALL dispense_medicine(1, 'STU200', 10);
CALL dispense_medicine(2, 'STU201', 5);
CALL dispense_medicine(1, 'STU202', 100); -- exceeds stock

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- ============================================
-- 6. reverse_dispensing procedure
-- ============================================
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status    VARCHAR(20);
    v_med_id    INTEGER;
    v_quantity  INTEGER;
BEGIN
    SELECT status, medicine_id, quantity
    INTO v_status, v_med_id, v_quantity
    FROM dispensing_records WHERE record_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record % not found', p_record_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % already reversed. Stock not restored again.', p_record_id;
    ELSE
        UPDATE dispensing_records SET status = 'REVERSED'
        WHERE record_id = p_record_id;

        UPDATE medicines
        SET stock_quantity = stock_quantity + v_quantity
        WHERE medicine_id = v_med_id;

        RAISE NOTICE 'Record % reversed. % units restored.', p_record_id, v_quantity;
    END IF;
END $$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);  -- second must not restore again

-- ============================================
-- 7. Explicit cursor - below low-stock threshold
-- ============================================
DO $$
DECLARE
    cur CURSOR FOR
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines WHERE stock_quantity <= 10;
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: Medicine % - "%" (% units)',
            rec.medicine_id, rec.medicine_name, rec.stock_quantity;
    END LOOP;
    CLOSE cur;
END $$;

-- ============================================
-- 8. Negative quantity with EXCEPTION
-- ============================================
DO $$
BEGIN
    CALL dispense_medicine(1, 'STU203', -5);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught: %', SQLERRM;
END $$;

-- ============================================
-- 9. Final query
-- ============================================
SELECT * FROM medicines;
SELECT * FROM dispensing_records;