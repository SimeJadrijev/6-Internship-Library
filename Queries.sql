--1. ime, prezime, spol (ispisati ‘MUŠKI’, ‘ŽENSKI’, ‘NEPOZNATO’, ‘OSTALO’;), ime države i  prosječna plaća u toj državi svakom autoru
SELECT
    A.AuthorName AS "Ime",
    A.Surname AS "Prezime",
    CASE
        WHEN G.GenderID = 1 THEN 'MUŠKI'
        WHEN G.GenderID = 2 THEN 'ŽENSKI'
        WHEN G.GenderID = 0 THEN 'NEPOZNATO'
        ELSE 'OSTALO'
    END AS "Spol",
    C.CountryName AS "Ime Države",
    C.AverageSalary AS "Prosječna Plaća"
FROM
    Authors A
JOIN
    Countries C ON A.CountryID = C.CountryID
JOIN
    Genders G ON A.GenderID = G.GenderID;
--2. naziv i datum objave svake znanstvene knjige zajedno s imenima glavnih autora koji su na njoj radili, pri čemu imena autora moraju biti u jednoj ćeliji i u obliku Prezime, I.; npr. Puljak, I.; Godinović, N.; Bilušić, A.
SELECT
    B.Title AS "Naziv",
    B.PublicationDate AS "Datum Objave",
    ARRAY_TO_STRING(ARRAY_AGG(A.Surname || ', ' || A.AuthorName || '.'), '; ') AS "Imena Glavnih Autora"
FROM
    Books B
JOIN
    Authorship AS ASH ON B.BookID = ASH.BookID
JOIN
    Authors A ON ASH.AuthorID = A.AuthorID
JOIN
    BookTypes BT ON B.BookTypeID = BT.BookTypeID
WHERE
    BT.TypeName = 'Science Book'
GROUP BY
    B.Title, B.PublicationDate;

--3. sve kombinacije (naslova) knjiga i posudbi istih u prosincu 2023.; u slučaju da neka nije ni jednom posuđena u tom periodu, prikaži je samo jednom (a na mjestu posudbe neka piše null)
SELECT
    B.Title AS "Naslov Knjige",
    BL.LoanDate AS "Datum Posudbe"
FROM
    Books B
LEFT JOIN (
    SELECT
        DISTINCT B.BookID,
        BL.LoanDate
    FROM
        Books B
    LEFT JOIN
        BookInstances BI ON B.BookID = BI.BookID
    LEFT JOIN
        BookLoans BL ON BI.InstanceID = BL.InstanceID AND EXTRACT(MONTH FROM BL.LoanDate) = 12 AND EXTRACT(YEAR FROM BL.LoanDate) = 2023
) BL ON B.BookID = BL.BookID
ORDER BY
    B.Title;

--4. top 3 knjižnice s najviše primjeraka knjiga
SELECT
    L.LibraryName AS "Knjižnica",
    COUNT(BI.InstanceID) AS "Broj Primjeraka"
FROM
    Libraries L
LEFT JOIN
    BookInstances BI ON L.LibraryID = BI.LibraryID
GROUP BY
    L.LibraryName
ORDER BY
    COUNT(BI.InstanceID) DESC
LIMIT 3;

--5. po svakoj knjizi broj ljudi koji su je pročitali (korisnika koji posudili bar jednom)
SELECT
    B.Title AS "Naslov Knjige",
    COUNT(DISTINCT BL.UserID) AS "Broj Čitatelja"
FROM
    Books B
JOIN
    BookInstances BI ON B.BookID = BI.BookID
JOIN
    BookLoans BL ON BI.InstanceID = BL.InstanceID
GROUP BY
    B.Title
ORDER BY
    COUNT(DISTINCT BL.UserID) DESC;
	
--6. imena svih korisnika koji imaju trenutno posuđenu knjigu
SELECT DISTINCT
    U.UserName AS "Ime Korisnika"
FROM
    Users U
JOIN
    BookLoans BL ON U.UserID = BL.UserID
WHERE
    BL.DueDate >= CURRENT_DATE;

--7. sve autore kojima je bar jedna od knjiga izašla između 2019. i 2022.
SELECT DISTINCT
    A.AuthorName || ' ' || A.Surname AS "Ime i Prezime Autora"
FROM
    Authors A
JOIN
    Authorship AS ASH ON A.AuthorID = ASH.AuthorID
JOIN
    Books B ON ASH.BookID = B.BookID
WHERE
    B.PublicationDate BETWEEN '2019-01-01' AND '2022-12-31';

--8. ime države i broj umjetničkih knjiga po svakoj (ako su dva autora iz iste države, računa se kao jedna knjiga), gdje su države sortirane po broju živih autora od najveće ka najmanjoj 
SELECT
    C.CountryName AS "Ime Države",
    COUNT(DISTINCT B.BookID) AS "Broj Umjetničkih Knjiga"
FROM
    Countries C
JOIN
    Authors A ON C.CountryID = A.CountryID
JOIN
    Authorship AS ASH ON A.AuthorID = ASH.AuthorID
JOIN
    Books B ON ASH.BookID = B.BookID
WHERE
    B.BookTypeID = (
        SELECT BookTypeID FROM BookTypes WHERE TypeName = 'Art Book'
    )
GROUP BY
    C.CountryName
ORDER BY
    COUNT(DISTINCT A.AuthorID) DESC;


--9. po svakoj kombinaciji autora i žanra (ukoliko postoji) broj posudbi knjiga tog autora u tom žanru
SELECT
    A.AuthorID,
    A.AuthorName || ' ' || A.Surname AS "Ime i Prezime Autora",
    BT.TypeName AS "Žanr",
    COUNT(BL.LoanID) AS "Broj Posudbi"
FROM
    Authors A
JOIN
    Authorship AS ASH ON A.AuthorID = ASH.AuthorID
JOIN
    Books B ON ASH.BookID = B.BookID
JOIN
    BookTypes BT ON B.BookTypeID = BT.BookTypeID
LEFT JOIN
    BookInstances BI ON B.BookID = BI.BookID
LEFT JOIN
    BookLoans BL ON BI.InstanceID = BL.InstanceID
GROUP BY
    A.AuthorID, A.AuthorName, A.Surname, BT.TypeName
ORDER BY
    A.AuthorID, COUNT(BL.LoanID) DESC;

--10. po svakom članu koliko trenutno duguje zbog kašnjenja; u slučaju da ne duguje ispiši “ČISTO”
SELECT
    U.UserName AS "Ime Korisnika",
    CASE
        WHEN COALESCE(SUM(CASE WHEN BL.DueDate < CURRENT_DATE THEN late_fee_per_day * (CURRENT_DATE - BL.DueDate) END), 0) = 0 THEN 'ČISTO'
        ELSE COALESCE(SUM(CASE WHEN BL.DueDate < CURRENT_DATE THEN late_fee_per_day * (CURRENT_DATE - BL.DueDate) END), 0)::TEXT
    END AS "Dugovanje"
FROM
    Users U
LEFT JOIN
    BookLoans BL ON U.UserID = BL.UserID
LEFT JOIN
    BookInstances BI ON BL.InstanceID = BI.InstanceID
LEFT JOIN
    Libraries L ON BI.LibraryID = L.LibraryID
LEFT JOIN (
    SELECT
        LibraryID,
        CASE
            WHEN EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 6 AND 9 THEN
                CASE
                    WHEN EXTRACT(DOW FROM CURRENT_DATE) IN (0, 6) THEN 20
                    ELSE 30
                END
            ELSE
                CASE
                    WHEN EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 1 AND 5 OR EXTRACT(MONTH FROM CURRENT_DATE) BETWEEN 10 AND 12 THEN
                        CASE
                            WHEN EXTRACT(DOW FROM CURRENT_DATE) IN (0, 6) THEN 20
                            ELSE 40
                        END
                    ELSE
                        50
                END
        END AS late_fee_per_day
    FROM
        Libraries
) LF ON L.LibraryID = LF.LibraryID
GROUP BY
    U.UserName
ORDER BY
    U.UserName;
--11. autora i ime prve objavljene knjige istog
SELECT
    A.AuthorID,
    A.AuthorName || ' ' || A.Surname AS "Ime i Prezime Autora",
    B.Title AS "Ime Prve Objavljene Knjige"
FROM
    Authors A
JOIN
    Authorship AS ASH ON A.AuthorID = ASH.AuthorID
JOIN (
    SELECT
        ASH.AuthorID,
        MIN(B.PublicationDate) AS first_publication_date
    FROM
        Authorship AS ASH
    JOIN
        Books B ON ASH.BookID = B.BookID
    GROUP BY
        ASH.AuthorID
) FirstPublication ON A.AuthorID = FirstPublication.AuthorID
JOIN
    Books B ON ASH.BookID = B.BookID AND B.PublicationDate = FirstPublication.first_publication_date
ORDER BY
    A.AuthorID;

--12. državu i ime druge objavljene knjige iste
WITH RankedBooks AS (
    SELECT
        A.AuthorID,
        B.Title AS BookTitle,
        C.CountryName AS AuthorCountry,
        B.PublicationDate,
        ROW_NUMBER() OVER (PARTITION BY A.AuthorID ORDER BY B.PublicationDate) AS BookRank
    FROM
        Authors A
    JOIN
        Authorship AS ASH ON A.AuthorID = ASH.AuthorID
    JOIN
        Books B ON ASH.BookID = B.BookID
    JOIN
        Countries C ON A.CountryID = C.CountryID
)
SELECT
    AuthorID,
    AuthorCountry AS "Država",
    MAX(CASE WHEN BookRank = 2 THEN BookTitle END) AS "Ime Druge Objavljene Knjige"
FROM
    RankedBooks
WHERE
    BookRank = 2
GROUP BY
    AuthorID, AuthorCountry
ORDER BY
    AuthorID;

--13. knjige i broj aktivnih posudbi, gdje se one s manje od 10 aktivnih ne prikazuju
SELECT
    B.Title AS "Naslov Knjige",
    COUNT(BL.LoanID) AS "Broj Aktivnih Posudbi"
FROM
    Books B
LEFT JOIN
    BookInstances BI ON B.BookID = BI.BookID
LEFT JOIN
    BookLoans BL ON BI.InstanceID = BL.InstanceID
WHERE
    BL.DueDate >= CURRENT_DATE
GROUP BY
    B.Title
HAVING
    COUNT(BL.LoanID) >= 10
ORDER BY
    COUNT(BL.LoanID) DESC;

--14. prosječan broj posudbi po primjerku knjige po svakoj državi
SELECT
    C.CountryName AS "Ime Države",
    AVG(InstancesPerBook.LoansPerInstance) AS "Prosječan Broj Posudbi po Primjerku"
FROM
    Countries C
LEFT JOIN (
    SELECT
        B.BookID,
        COUNT(DISTINCT BI.InstanceID) AS InstanceCount,
        COUNT(BL.LoanID) AS LoansPerInstance
    FROM
        Books B
    LEFT JOIN
        BookInstances BI ON B.BookID = BI.BookID
    LEFT JOIN
        BookLoans BL ON BI.InstanceID = BL.InstanceID
    GROUP BY
        B.BookID
) InstancesPerBook ON TRUE
GROUP BY
    C.CountryName
ORDER BY
    "Prosječan Broj Posudbi po Primjerku" DESC;

--15. broj autora (koji su objavili više od 5 knjiga) po struci, desetljeću rođenja i spolu; u slučaju da je broj autora manji od 10, ne prikazuj kategoriju; poredaj prikaz po desetljeću rođenja
-- po struci??

--16. deset najbogatijih autora po zadanoj formuli
WITH AuthorWealth AS (
    SELECT
        A.AuthorID,
        A.AuthorName || ' ' || A.Surname AS "Ime i Prezime Autora",
        CONCAT('€', ROUND(SQRT(COUNT(DISTINCT BI.InstanceID) * 1.0 / COUNT(DISTINCT ASH.AuthorID)), 2)) AS "Bogatstvo po Knjizi"
    FROM
        Authors A
    JOIN
        Authorship AS ASH ON A.AuthorID = ASH.AuthorID
    LEFT JOIN
        Books B ON ASH.BookID = B.BookID
    LEFT JOIN
        BookInstances BI ON B.BookID = BI.BookID
    GROUP BY
        A.AuthorID, "Ime i Prezime Autora"
)
SELECT
    "Ime i Prezime Autora",
    "Bogatstvo po Knjizi"
FROM
    AuthorWealth
ORDER BY
    "Bogatstvo po Knjizi" DESC
LIMIT 10;

