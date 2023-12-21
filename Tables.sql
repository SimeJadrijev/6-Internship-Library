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
