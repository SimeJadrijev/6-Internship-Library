CREATE TABLE Libraries (
    LibraryID SERIAL PRIMARY KEY,
    LibraryName VARCHAR(255) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL
);

CREATE TABLE Countries (
    CountryID SERIAL PRIMARY KEY,
    CountryName VARCHAR(255) NOT NULL,
    Population INT NOT NULL,
    AverageSalary DECIMAL(10, 2) NOT NULL
);

CREATE TABLE Genders (
    GenderID SERIAL PRIMARY KEY,
    GenderName VARCHAR(10) NOT NULL
);

CREATE TABLE Authors (
    AuthorID SERIAL PRIMARY KEY,
    AuthorName VARCHAR(255) NOT NULL,
    DateOfBirth DATE NOT NULL,
    CountryID INT REFERENCES Countries(CountryID),
    GenderID INT REFERENCES Genders(GenderID)
);

CREATE TABLE BookTypes (
    BookTypeID SERIAL PRIMARY KEY,
    TypeName VARCHAR(50) NOT NULL
);

CREATE TABLE Books (
    BookID SERIAL PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    PublicationDate DATE NOT NULL,
    BookTypeID INT REFERENCES BookTypes(BookTypeID)
);

CREATE TABLE BookInstances (
    InstanceID SERIAL PRIMARY KEY,
    BookID INT REFERENCES Books(BookID),
    LibraryID INT REFERENCES Libraries(LibraryID),
    InstanceCode VARCHAR(20) NOT NULL
);

CREATE TABLE Users (
    UserID SERIAL PRIMARY KEY,
    UserName VARCHAR(255) NOT NULL
);

CREATE TABLE BookLoans (
    LoanID SERIAL PRIMARY KEY,
    InstanceID INT REFERENCES BookInstances(InstanceID),
    UserID INT REFERENCES Users(UserID),
    LoanDate DATE NOT NULL,
    DueDate DATE NOT NULL
);



CREATE TABLE Authorship (
    AuthorshipID SERIAL PRIMARY KEY,
    AuthorID INT REFERENCES Authors(AuthorID),
    BookID INT REFERENCES Books(BookID),
    AuthorshipType VARCHAR(20)
);

-- loan time limit
CREATE OR REPLACE FUNCTION check_loan_dates() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.DueDate < NEW.LoanDate THEN
        RAISE EXCEPTION 'Due date must be after loan date';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_loan_dates_trigger
BEFORE INSERT ON BookLoans
FOR EACH ROW EXECUTE FUNCTION check_loan_dates();

--limiting the number of loans per person
CREATE OR REPLACE FUNCTION check_user_loan_limit() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM BookLoans WHERE UserID = NEW.UserID) >= 3 THEN
        RAISE EXCEPTION 'User can borrow up to 3 books at a time';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_user_loan_limit_trigger
BEFORE INSERT ON BookLoans
FOR EACH ROW EXECUTE FUNCTION check_user_loan_limit();

--ISO/IEC gender check
ALTER TABLE Genders
ADD CONSTRAINT chk_valid_gender
CHECK (GenderName IN ('Male', 'Female', 'Not Applicable', 'Not known'));

-- booktype check
ALTER TABLE BookTypes
ADD CONSTRAINT chk_valid_book_type
CHECK (TypeName IN ('Reading Material', 'Art Book', 'Science Book', 'Biography', 'Professional Book'));

-- autorship check
ALTER TABLE Authorship
DROP CONSTRAINT IF EXISTS chk_valid_authorship_type;

ALTER TABLE Authorship
ADD CONSTRAINT chk_valid_authorship_type
CHECK (AuthorshipType IN ('Main author', 'Co-author'));

--procedure for book loan
CREATE OR REPLACE PROCEDURE borrow_book(
    instance_id INT,
    user_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    loan_id INT;
    loan_start_date DATE;
    due_date DATE;
    is_weekend BOOLEAN;
    is_summer BOOLEAN;
    is_readingmaterial BOOLEAN;
    late_fee_per_day INT;
BEGIN
    SELECT EXTRACT(DOW FROM CURRENT_DATE) IN (0, 6) INTO is_weekend;

    SELECT EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 6 AND 9 INTO is_summer;

    SELECT COUNT(*)
    INTO is_readingmaterial
    FROM Book b
    INNER JOIN BookInstances bi ON b.BookID = bi.BookID
    WHERE bi.InstanceID = instance_id AND b.BookTypeID = 1; 

    IF is_summer THEN
        IF is_weekend THEN
            late_fee_per_day := 20;
        ELSE
            late_fee_per_day := 30; 
        END IF;
    ELSE
        IF is_textbook THEN
            late_fee_per_day := 50; 
        ELSE
            IF is_weekend THEN
                late_fee_per_day := 20;
            ELSE
                late_fee_per_day := 40; 
            END IF;
        END IF;
    END IF;

    loan_start_date := CURRENT_DATE;
    due_date := loan_start_date + INTERVAL '20 days';

    INSERT INTO BookLoans (InstanceID, UserID, StartDate, DueDate)
    VALUES (instance_id, user_id, loan_start_date, due_date)
    RETURNING LoanID INTO loan_id;

    RAISE NOTICE 'The book is successfully loaned. ID of loan: %, Start date: %, Due date: %', loan_id, loan_start_date, due_date;

END;
$$;

