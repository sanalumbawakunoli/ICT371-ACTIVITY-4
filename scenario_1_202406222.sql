-- scenario_1_student_number.sql
-- PostgreSQL PL/pgSQL Implementation

-- ============================================
-- 1. Create tables
-- ============================================
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

CREATE TABLE books (
    book_id         SERIAL PRIMARY KEY,
    title           VARCHAR(200) NOT NULL,
    available_copies INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE book_loans (
    loan_id         SERIAL PRIMARY KEY,
    book_id         INTEGER REFERENCES books(book_id),
    student_number  VARCHAR(20),
    quantity        INTEGER,
    loan_status     VARCHAR(20) DEFAULT 'ACTIVE'
);

-- Add at least three books
INSERT INTO books (title, available_copies) VALUES
('Introduction to Databases', 5),
('Programming in Python', 2),
('Data Structures and Algorithms', 0);

-- ============================================
-- 2. IF ELSIF ELSE - stock status of one book
-- ============================================
DO $$
DECLARE
    v_copies INTEGER;
    v_title  VARCHAR(200);
BEGIN
    SELECT title, available_copies INTO v_title, v_copies
    FROM books WHERE book_id = 2;

    IF v_copies = 0 THEN
        RAISE NOTICE 'Book "%" is UNAVAILABLE (0 copies).', v_title;
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Book "%" is LOW ON COPIES (% remaining).', v_title, v_copies;
    ELSE
        RAISE NOTICE 'Book "%" is SUFFICIENTLY STOCKED (% copies).', v_title, v_copies;
    END IF;
END $$;

-- ============================================
-- 3. WHILE - three overdue reminder numbers
-- ============================================
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue Reminder #%: Please return your book.', i;
        i := i + 1;
    END LOOP;
END $$;

-- Numeric FOR - three library shelf numbers
DO $$
BEGIN
    FOR shelf IN 1..3 LOOP
        RAISE NOTICE 'Library Shelf Number: SH-%', shelf;
    END LOOP;
END $$;

-- ============================================
-- 4. borrow_book procedure
-- ============================================
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id        INTEGER,
    p_student_number VARCHAR,
    p_quantity       INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %', p_quantity;
    END IF;

    SELECT available_copies INTO v_available
    FROM books WHERE book_id = p_book_id FOR UPDATE;

    IF v_available IS NULL THEN
        RAISE EXCEPTION 'Book ID % not found', p_book_id;
    END IF;

    IF v_available >= p_quantity THEN
        UPDATE books
        SET available_copies = available_copies - p_quantity
        WHERE book_id = p_book_id;

        INSERT INTO book_loans (book_id, student_number, quantity, loan_status)
        VALUES (p_book_id, p_student_number, p_quantity, 'ACTIVE');

        RAISE NOTICE 'Loan recorded: % copies of book % to student %.',
            p_quantity, p_book_id, p_student_number;
    ELSE
        RAISE NOTICE 'Cannot borrow % copies. Only % available.',
            p_quantity, v_available;
    END IF;
END $$;

-- ============================================
-- 5. Call borrow_book: 2 valid + 1 exceeding
-- ============================================
CALL borrow_book(1, 'STU001', 2);   -- valid
CALL borrow_book(2, 'STU002', 1);   -- valid
CALL borrow_book(1, 'STU003', 10);  -- exceeds available

SELECT * FROM books;
SELECT * FROM book_loans;

-- ============================================
-- 6. return_book procedure
-- ============================================
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status   VARCHAR(20);
    v_book_id  INTEGER;
    v_quantity INTEGER;
BEGIN
    SELECT loan_status, book_id, quantity
    INTO v_status, v_book_id, v_quantity
    FROM book_loans WHERE loan_id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan ID % not found', p_loan_id;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % already returned. No stock restored.', p_loan_id;
    ELSE
        UPDATE book_loans SET loan_status = 'RETURNED'
        WHERE loan_id = p_loan_id;

        UPDATE books SET available_copies = available_copies + v_quantity
        WHERE book_id = v_book_id;

        RAISE NOTICE 'Loan % returned. % copies restored.', p_loan_id, v_quantity;
    END IF;
END $$;

-- Call twice for same loan
CALL return_book(1);
CALL return_book(1);  -- must NOT restore again

-- ============================================
-- 7. Explicit cursor - books with few copies
-- ============================================
DO $$
DECLARE
    cur_books CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books WHERE available_copies <= 2;
    rec RECORD;
BEGIN
    OPEN cur_books;
    LOOP
        FETCH cur_books INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: Book % - "%" (% copies)',
            rec.book_id, rec.title, rec.available_copies;
    END LOOP;
    CLOSE cur_books;
END $$;

-- ============================================
-- 8. Borrow zero copies with EXCEPTION
-- ============================================
DO $$
BEGIN
    CALL borrow_book(1, 'STU004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught: %', SQLERRM;
END $$;

-- ============================================
-- 9. Final query
-- ============================================
SELECT * FROM books;
SELECT * FROM book_loans;