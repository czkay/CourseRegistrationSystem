DROP TABLE IF EXISTS Accounts CASCADE;
DROP TABLE IF EXISTS Students CASCADE;
DROP TABLE IF EXISTS Completed CASCADE;
DROP TABLE IF EXISTS Administrators CASCADE;
DROP TABLE IF EXISTS Courses CASCADE;
DROP TABLE IF EXISTS Prerequisites CASCADE;
DROP TABLE IF EXISTS Teaches CASCADE;
DROP TABLE IF EXISTS Enrolls CASCADE;
DROP TABLE IF EXISTS Bypasses CASCADE;
DROP TABLE IF EXISTS Teachers CASCADE;
DROP TABLE IF EXISTS Attends CASCADE;
DROP TABLE IF EXISTS Classes CASCADE;
DROP TABLE IF EXISTS TA CASCADE;
DROP TABLE IF EXISTS Departments CASCADE;
DROP TABLE IF EXISTS Semesters CASCADE;
DROP TABLE IF EXISTS CurrentAY CASCADE;
DROP PROCEDURE IF EXISTS add_student_account CASCADE; --(id varchar(50), password varchar(50), name varchar(50), year int, isGraduate boolean) CASCADE;
DROP PROCEDURE IF EXISTS add_admin_account CASCADE; --(id varchar(50), password varchar(50), name varchar(50)) CASCADE;
DROP PROCEDURE IF EXISTS add_teacher_account CASCADE; --(id varchar(50), password varchar(50), name varchar(50), departmentID varchar(50), roomID varchar(50)) CASCADE;
DROP PROCEDURE IF EXISTS switch_to_new_semester CASCADE; --(y int, s int) CASCADE;
-- DROP PROCEDURE IF EXISTS add_student_account(id varchar(50), password varchar(50), name varchar(50), year int, isGraduate boolean) CASCADE;
-- DROP PROCEDURE IF EXISTS add_admin_account(id varchar(50), password varchar(50), name varchar(50)) CASCADE;
-- DROP PROCEDURE IF EXISTS add_teacher_account(id varchar(50), password varchar(50), name varchar(50), departmentID varchar(50), roomID varchar(50)) CASCADE;
-- DROP PROCEDURE IF EXISTS switch_to_new_semester(y int, s int) CASCADE;
BEGIN;
CREATE TABLE Departments (
    departmentID varchar(50) PRIMARY KEY,
    name varchar(50) NOT NULL
);

CREATE TABLE Semesters (
    year int,
    semNum int,
    PRIMARY KEY(year, semNum)
);

CREATE TABLE Accounts (
    accountID varchar(50) PRIMARY KEY,
    password varchar(50) NOT NULL
);

CREATE TABLE Students (
    accountID varchar(50) PRIMARY KEY,
    name varchar(50) NOT NULL,
    year int NOT NULL,
    departmentID varchar(50) NOT NULL,
    isGraduate boolean NOT NULL,
    FOREIGN KEY(accountID) REFERENCES Accounts,
    FOREIGN KEY(departmentID) REFERENCES Departments,
    CHECK (year <= 6 AND year >= 1)
);

CREATE TABLE Administrators (
    accountID varchar(50) PRIMARY KEY,
    name varchar(50) NOT NULL,
    FOREIGN KEY(accountID) REFERENCES Accounts
);

CREATE TABLE Teachers (
    accountID varchar(50) PRIMARY KEY,
    name varchar(50) NOT NULL,
    departmentID varchar(50) NOT NULL,
    roomID int NOT NULL,
    FOREIGN KEY(accountID) REFERENCES Accounts,
    FOREIGN KEY(departmentID) REFERENCES Departments
);

CREATE TABLE Courses (
    moduleCode varchar(50),
    name varchar(50) NOT NULL,
    departmentID varchar(50),
    adminID varchar(50) NOT NULL,
    isGraduateCourse boolean NOT NULL,
    currentSize int NOT NULL DEFAULT 0,
    quota int NOT NULL,
    PRIMARY KEY(moduleCode),
    FOREIGN KEY(adminID) REFERENCES Administrators,
    FOREIGN KEY(departmentID) REFERENCES Departments
);

CREATE TABLE Completed (
    accountID varchar(50),
    moduleCode varchar(50) NOT NULL,
    PRIMARY KEY(accountID, moduleCode),
    FOREIGN KEY(moduleCode) REFERENCES Courses
);

CREATE TABLE Prerequisites (
    moduleCode varchar(50) PRIMARY KEY,
    prereq varchar(50),
    FOREIGN KEY(moduleCode) REFERENCES Courses,
    FOREIGN KEY(prereq) REFERENCES Courses,
    CHECK (moduleCode <> prereq)
);

CREATE TABLE Teaches (
    teacherID varchar(50),
    moduleCode varchar(50),
    year int,
    semNum int,
    PRIMARY KEY(moduleCode, year, semNum),
    FOREIGN KEY(teacherID) REFERENCES Teachers(accountID),
    FOREIGN KEY(moduleCode) REFERENCES Courses,
    FOREIGN KEY(year, semNum) REFERENCES Semesters
);

CREATE TABLE Classes (
    classID int,
    moduleCode varchar(50),
    currentSize int NOT NULL DEFAULT 0,
    PRIMARY KEY(classID, moduleCode),
    FOREIGN KEY(moduleCode) REFERENCES Courses ON DELETE CASCADE
);

CREATE TABLE Enrolls (
    accountID varchar(50),
    moduleCode varchar(50),
    dateRegistered date NOT NULL,
    isSuccess boolean,
    PRIMARY KEY(accountID, moduleCode),
    FOREIGN KEY(accountID) REFERENCES Students,
    FOREIGN KEY(moduleCode) REFERENCES Courses
    -- have to check that the course currently has a teacher
);

CREATE TABLE Bypasses (
    studentID varchar(50),
    moduleCode varchar(50),
    adminID varchar(50) NOT NULL,
    isBypassed boolean DEFAULT NULL,
    PRIMARY KEY(studentID, moduleCode),
    FOREIGN KEY(studentID, moduleCode) REFERENCES Enrolls(accountID, moduleCode) ON DELETE CASCADE,
    FOREIGN KEY(adminID) REFERENCES Administrators(accountID)
);

CREATE TABLE Attends (
    accountID varchar(50),
    classID int,
    moduleCode varchar(50),
    PRIMARY KEY(accountID, moduleCode),
    FOREIGN KEY(accountID) REFERENCES Students,
    FOREIGN KEY(classID, moduleCode) REFERENCES Classes
);

CREATE TABLE TA (
    accountID varchar(50),
    classID int,
    moduleCode varchar(50),
    PRIMARY KEY(classID, moduleCode),
    FOREIGN KEY(accountID) REFERENCES Students,
    FOREIGN KEY(classID, moduleCode) REFERENCES Classes
);

CREATE TABLE CurrentAY (
    lock char(1) PRIMARY KEY,
    year int NOT NULL,
    semNum int NOT NULL,
    registrationDeadline date NOT NULL,
    FOREIGN KEY(year, semNum) REFERENCES Semesters,
    CHECK (lock = 'X' AND (semNum = 1 OR semNum = 2))
);
COMMIT;

CREATE OR REPLACE PROCEDURE add_student_account(id varchar(50), password varchar(50), name varchar(50), year int, dept varchar(50), isGraduate boolean)
AS $$
BEGIN
IF id NOT IN (SELECT accountID FROM Administrators) AND id NOT IN (SELECT accountID FROM Teachers)
THEN
INSERT INTO Accounts VALUES (id, password);
INSERT INTO Students VALUES (id, name, year, dept, isGraduate);
ELSE
END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_admin_account(id varchar(50), password varchar(50), name varchar(50))
AS $$
BEGIN
IF id NOT IN (SELECT accountID FROM Students) AND id NOT IN (SELECT accountID FROM Teachers)
THEN
INSERT INTO Accounts VALUES (id, password);
INSERT INTO Administrators VALUES (id, name);
ELSE
END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_teacher_account(id varchar(50), password varchar(50), name varchar(50), departmentID varchar(50), roomID int)
AS $$
BEGIN
IF id NOT IN (SELECT accountID FROM Administrators) AND id NOT IN (SELECT accountID FROM Students)
THEN
INSERT INTO Accounts VALUES (id, password);
INSERT INTO Teachers VALUES (id, name, departmentID, roomID);
ELSE
END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE add_enrollment(id varchar(50), mod varchar(50))
AS $$
DECLARE currSize numeric;
DECLARE n numeric;
BEGIN
SELECT currentSize INTO currSize
FROM Courses
WHERE mod = Courses.moduleCode;
SELECT quota INTO n
FROM Courses
WHERE mod = Courses.moduleCode;
IF currSize >= n THEN
INSERT INTO Enrolls VALUES(id, mod, CURRENT_DATE, NULL); -- means a bypass is required
ELSE
INSERT INTO Enrolls VALUES(id, mod, CURRENT_DATE, TRUE);
END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_enrollment_entry()
RETURNS TRIGGER AS $$
DECLARE adID varchar(50);
DECLARE classNum int;
BEGIN
RAISE NOTICE 'CHECKING IF BYPASS IS NEEDED';
SELECT adminID INTO adID
FROM Courses
WHERE NEW.moduleCode = Courses.moduleCode;
SELECT classID INTO classNum
FROM Classes NATURAL JOIN TA
WHERE NEW.moduleCode = Classes.moduleCode
ORDER BY currentSize ASC, classID ASC
LIMIT 1;
IF NEW.isSuccess IS NULL THEN
RAISE NOTICE 'BYPASS IS NEEDED';
INSERT INTO Bypasses VALUES (NEW.accountID, NEW.moduleCode, adID);
ELSIF NEW.isSuccess = TRUE THEN
RAISE NOTICE 'BYPASS IS NOT NEEDED, STUDENT CAN ATTEND';
INSERT INTO Attends VALUES (NEW.accountID, classNum, NEW.moduleCode);
UPDATE Courses SET currentSize = currentSize + 1 WHERE moduleCode = NEW.moduleCode;
UPDATE Classes SET currentSize = currentSize + 1 WHERE classID = classNum AND moduleCode = NEW.moduleCode;
END IF;
RETURN NULL;
END;
$$
LANGUAGE plpgsql;
CREATE TRIGGER new_enrollment_entry
AFTER INSERT OR UPDATE ON Enrolls
FOR EACH ROW
EXECUTE PROCEDURE process_enrollment_entry();

-- if true, set enroll entry to success
-- if false, then set enroll entry to fail
-- look thru Courses and set a successful enroll entry for the student to a course that he meets all prereqs for and also has lowest currentSize
CREATE OR REPLACE FUNCTION process_bypass_result()
RETURNS TRIGGER AS $$
DECLARE currentYear int;
DECLARE currentSem int;
DECLARE newModule varchar(50);
BEGIN
RAISE NOTICE 'PROCESSING BYPASS RESULT';
IF (NEW.isBypassed = TRUE)
THEN
RAISE NOTICE 'BYPASS IS ACCEPTED';
UPDATE Enrolls SET isSuccess = TRUE WHERE NEW.studentID = Enrolls.accountID AND NEW.moduleCode = Enrolls.moduleCode;
RETURN NEW;
ELSE
RAISE NOTICE 'BYPASS IS DENIED, STUDENT IS AUTO-ALLOCATED';
UPDATE Enrolls SET isSuccess = FALSE WHERE NEW.studentID = Enrolls.accountID AND NEW.moduleCode = Enrolls.moduleCode;
SELECT year INTO currentYear
FROM CurrentAY;
SELECT semNum INTO currentSem
FROM CurrentAY;
SELECT moduleCode INTO newModule
FROM Courses
WHERE 
NOT EXISTS (SELECT 1
FROM (SELECT * FROM Completed WHERE NEW.studentID = Completed.accountID) AS C RIGHT JOIN Prerequisites P
ON C.moduleCode = P.prereq
WHERE Courses.moduleCode = P.moduleCode
AND C.accountID IS NULL)
AND
(EXISTS (SELECT 1 FROM Teaches T WHERE Courses.moduleCode = T.moduleCode AND T.year = currentYear AND T.semNum = currentSem))
AND
(Courses.moduleCode NOT IN (SELECT moduleCode FROM Completed WHERE NEW.studentID = Completed.accountID))
AND
(Courses.moduleCode <> NEW.moduleCode)
AND
(Courses.moduleCode NOT IN (SELECT moduleCode FROM Attends WHERE NEW.studentID = Attends.accountID))
AND
(SELECT isGraduate FROM Students WHERE NEW.studentID = Students.accountID) = Courses.isGraduateCourse
ORDER BY currentSize ASC
LIMIT 1;
DELETE FROM Enrolls WHERE NEW.studentID = Enrolls.accountID AND newModule = Enrolls.moduleCode;
INSERT INTO Enrolls VALUES(NEW.studentID, newModule, CURRENT_DATE, TRUE);
END IF;
RETURN NEW;
END;
$$
LANGUAGE plpgsql;
CREATE TRIGGER new_bypass_result
AFTER UPDATE ON Bypasses
FOR EACH ROW
EXECUTE PROCEDURE process_bypass_result();

CREATE OR REPLACE FUNCTION allow_TA_entry_if_valid()
RETURNS TRIGGER AS $$
BEGIN
RAISE NOTICE 'CHECKING NEW TA ENTRY';
IF (EXISTS (SELECT 1 FROM Completed WHERE NEW.moduleCode = Completed.moduleCode AND NEW.accountID = Completed.accountID))
THEN
RAISE NOTICE 'VALID TA ENTRY';
RETURN NEW;
ELSE
RAISE NOTICE 'INVALID TA ENTRY';
RETURN NULL;
END IF;
END;
$$
LANGUAGE plpgsql;
CREATE TRIGGER new_TA_entry
BEFORE INSERT OR UPDATE ON TA
FOR EACH ROW
EXECUTE PROCEDURE allow_TA_entry_if_valid();

CREATE OR REPLACE PROCEDURE switch_to_new_semester()
AS $$
DECLARE oldYear int;
DECLARE oldSemNum int;
DECLARE newDeadline date;
DECLARE newYear int;
DECLARE newSemNum int;
BEGIN
SELECT year INTO oldYear
FROM CurrentAY;
SELECT semNum INTO oldSemNum
FROM CurrentAY;
SELECT (CASE WHEN oldSemNum = 2 THEN oldYear + 1 ELSE oldYear END) INTO newYear;
SELECT (CASE WHEN oldSemNum = 1 THEN 2 ELSE 1 END) INTO newSemNum;
SELECT (CASE WHEN newSemNum = 1 THEN newYear || '-12-31' ELSE newYear || '-07-31' END) INTO newDeadline;
INSERT INTO Completed
SELECT accountID, moduleCode
FROM Attends;
DELETE FROM Attends;
DELETE FROM Enrolls;
DELETE FROM Teaches WHERE year = oldYear AND semNum = oldSemNum;
UPDATE CurrentAY SET year = newYear, semNum = newSemNum, registrationDeadline = newDeadline;
DELETE FROM Semesters WHERE year = oldYear AND semNum = oldSemNum;
END;
$$
LANGUAGE plpgsql;

INSERT INTO SEMESTERS VALUES (2020, 1);
INSERT INTO SEMESTERS VALUES (2020, 2);
INSERT INTO SEMESTERS VALUES (2021, 1);
INSERT INTO SEMESTERS VALUES (2021, 2);
INSERT INTO SEMESTERS VALUES (2022, 1);
INSERT INTO SEMESTERS VALUES (2022, 2);
INSERT INTO SEMESTERS VALUES (2023, 1);
INSERT INTO SEMESTERS VALUES (2023, 2);

INSERT INTO CurrentAY VALUES ('X', 2020, 1, '2020-07-31');

INSERT INTO Departments VALUES ('soc', 'Computing');
INSERT INTO Departments VALUES ('egn', 'Engin');
INSERT INTO Departments VALUES ('sci', 'Science');
INSERT INTO Departments VALUES ('lgng', 'Language');
INSERT INTO Departments VALUES ('med', 'Medicine');
INSERT INTO Departments VALUES ('fass', 'Arts');
INSERT INTO Departments VALUES ('mgc', 'Magic');

CALL add_student_account('e12345', '123', 'Sam', 2, 'egn', false);
CALL add_student_account('e12346', '123', 'Bob', 2, 'egn', false);
CALL add_student_account('e12347', '123', 'Jack', 3, 'sci', false);
CALL add_student_account('e12348', '123', 'Dan', 4, 'sci', false);
CALL add_student_account('e12349', '123', 'Jon', 2, 'fass', false);
CALL add_student_account('e12350', '123', 'Bij', 1, 'soc', false);
CALL add_student_account('e12351', '123', 'Pok', 6, 'soc', true);
CALL add_student_account('e12352', '123', 'Bun', 1, 'soc', false);
CALL add_student_account('e12353', '123', 'Dan', 6, 'med', true);
CALL add_student_account('e12354', '123', 'Voldemort', 5, 'mgc', true);
CALL add_student_account('e12355', '123', 'Burg', 1, 'soc', false);
CALL add_student_account('e12356', '123', 'Saitama', 1, 'soc', false);

CALL add_admin_account('a006', '123', 'Sun');
CALL add_admin_account('a009', '123', 'Laksa');
CALL add_admin_account('a003', '123', 'Moon');
CALL add_admin_account('a012', '123', 'Crayfish');

CALL add_teacher_account('t012', '123', 'Prof Lim', 'soc', 1);
CALL add_teacher_account('t013', '123', 'Prof Ahmad', 'soc', 2); 
CALL add_teacher_account('t011', '123', 'Prof Kong', 'soc', 3);
CALL add_teacher_account('t010', '123', 'Prof Dude', 'lgng', 1);
CALL add_teacher_account('t098', '123', 'Dumbledore', 'mgc', 1);
CALL add_teacher_account('t099', '123', 'Prof Choo', 'fass', 1);

INSERT INTO Courses VALUES ('CS101', 'Intro to Programming', 'soc', 'a003', false, 90, 90); -- oversubscribed
INSERT INTO Courses VALUES ('CS102', 'Intermediate Programming', 'soc', 'a003', false, 70, 80);
INSERT INTO Courses VALUES ('CS103', 'Advanced Programming', 'soc', 'a006', true, 40, 50);
INSERT INTO Courses VALUES ('DS101', 'Intro to Data Science', 'sci', 'a006', false, 110, 130);
INSERT INTO Courses VALUES ('DS102', 'Intermediate Data Science', 'sci', 'a009', false, 120, 110); -- oversubscribed
INSERT INTO Courses VALUES ('FC101', 'French 1', 'lgng', 'a009', false, 50, 60);
INSERT INTO Courses VALUES ('FC102', 'French 2', 'lgng', 'a012', false, 0, 50);
INSERT INTO Courses VALUES ('MG101', 'Intro to Magic', 'mgc', 'a012', true, 3, 3); -- oversubscribed
INSERT INTO Courses VALUES ('CS201', 'Intro to Computational Bio', 'soc', 'a012', false, 0, 20);
INSERT INTO Courses VALUES ('PL101', 'Life, the Universe, and Everything', 'fass', 'a012', false, 0, 200);

INSERT INTO Completed VALUES ('e12348', 'DS101');
INSERT INTO Completed VALUES ('e12348', 'DS102');
INSERT INTO Completed VALUES ('e12354', 'MG101');
INSERT INTO Completed VALUES ('e12350', 'CS101');
INSERT INTO Completed VALUES ('e12351', 'CS101');
INSERT INTO Completed VALUES ('e12351', 'CS102');
INSERT INTO Completed VALUES ('e12351', 'CS103');
INSERT INTO Completed VALUES ('e12352', 'CS101');
INSERT INTO Completed VALUES ('e12352', 'CS102');
INSERT INTO Completed VALUES ('e12352', 'CS103');
INSERT INTO Completed VALUES ('e12355', 'DS101');
INSERT INTO Completed VALUES ('e12356', 'DS101');
INSERT INTO Completed VALUES ('e12356', 'DS102');
INSERT INTO Completed VALUES ('e12345', 'CS101');
INSERT INTO Completed VALUES ('e12346', 'CS101');
INSERT INTO Completed VALUES ('e12347', 'CS101');
INSERT INTO Completed VALUES ('e12347', 'CS102');
INSERT INTO Completed VALUES ('e12347', 'CS201');
INSERT INTO Completed VALUES ('e12354', 'FC101');
INSERT INTO Completed VALUES ('e12353', 'MG101');
INSERT INTO Completed VALUES ('e12349', 'PL101');

INSERT INTO Prerequisites VALUES ('CS102', 'CS101');
INSERT INTO Prerequisites VALUES ('CS103', 'CS102');
INSERT INTO Prerequisites VALUES ('CS201', 'CS102');
INSERT INTO Prerequisites VALUES ('DS102', 'DS101');
INSERT INTO Prerequisites VALUES ('FC102', 'FC101');

INSERT INTO Teaches VALUES('t011', 'CS101', 2020, 1);
INSERT INTO Teaches VALUES('t012', 'CS102', 2020, 1);
INSERT INTO Teaches VALUES('t013', 'CS103', 2020, 1);
INSERT INTO Teaches VALUES('t011', 'DS101', 2020, 1);
INSERT INTO Teaches VALUES('t012', 'DS102', 2020, 1);
INSERT INTO Teaches VALUES('t010', 'FC101', 2020, 1);
INSERT INTO Teaches VALUES('t010', 'FC102', 2020, 2);
INSERT INTO Teaches VALUES('t098', 'MG101', 2020, 1);
INSERT INTO Teaches VALUES('t099', 'PL101', 2020, 1);
INSERT INTO Teaches VALUES('t099', 'PL101', 2020, 2);

INSERT INTO Classes VALUES ('1', 'CS101');
INSERT INTO Classes VALUES ('2', 'CS101');
INSERT INTO Classes VALUES ('3', 'CS101');
INSERT INTO Classes VALUES ('1', 'CS102');
INSERT INTO Classes VALUES ('2', 'CS102');
INSERT INTO Classes VALUES ('3', 'CS102');
INSERT INTO Classes VALUES ('1', 'CS103');
INSERT INTO Classes VALUES ('2', 'CS103');
INSERT INTO Classes VALUES ('3', 'CS103');
INSERT INTO Classes VALUES ('1', 'DS101');
INSERT INTO Classes VALUES ('2', 'DS101');
INSERT INTO Classes VALUES ('3', 'DS101');
INSERT INTO Classes VALUES ('1', 'DS102');
INSERT INTO Classes VALUES ('2', 'DS102');
INSERT INTO Classes VALUES ('3', 'DS102');
INSERT INTO Classes VALUES ('1', 'FC101');
INSERT INTO Classes VALUES ('2', 'FC101');
INSERT INTO Classes VALUES ('3', 'FC101');
INSERT INTO Classes VALUES ('1', 'FC102');
INSERT INTO Classes VALUES ('2', 'FC102');
INSERT INTO Classes VALUES ('3', 'FC102');
INSERT INTO Classes VALUES ('1', 'MG101');
INSERT INTO Classes VALUES ('2', 'MG101');
INSERT INTO Classes VALUES ('3', 'MG101');
INSERT INTO Classes VALUES ('1', 'CS201');
INSERT INTO Classes VALUES ('2', 'CS201');
INSERT INTO Classes VALUES ('3', 'CS201');
INSERT INTO Classes VALUES ('1', 'PL101');
INSERT INTO Classes VALUES ('2', 'PL101');
INSERT INTO Classes VALUES ('3', 'PL101');
 
INSERT INTO TA VALUES ('e12350', '1', 'CS101');
INSERT INTO TA VALUES ('e12350', '2', 'CS101');
INSERT INTO TA VALUES ('e12350', '3', 'CS101');
INSERT INTO TA VALUES ('e12351', '1', 'CS102');
INSERT INTO TA VALUES ('e12351', '2', 'CS102');
INSERT INTO TA VALUES ('e12351', '3', 'CS102');
INSERT INTO TA VALUES ('e12352', '1', 'CS103');
INSERT INTO TA VALUES ('e12352', '2', 'CS103');
INSERT INTO TA VALUES ('e12352', '3', 'CS103');
INSERT INTO TA VALUES ('e12355', '1', 'DS101');
INSERT INTO TA VALUES ('e12355', '2', 'DS101');
INSERT INTO TA VALUES ('e12355', '3', 'DS101');
INSERT INTO TA VALUES ('e12356', '1', 'DS102');
INSERT INTO TA VALUES ('e12356', '2', 'DS102');
INSERT INTO TA VALUES ('e12356', '3', 'DS102');
INSERT INTO TA VALUES ('e12354', '1', 'FC101');
INSERT INTO TA VALUES ('e12354', '2', 'FC101');
INSERT INTO TA VALUES ('e12354', '3', 'FC101');
INSERT INTO TA VALUES ('e12353', '1', 'MG101');
INSERT INTO TA VALUES ('e12353', '2', 'MG101');
INSERT INTO TA VALUES ('e12353', '3', 'MG101');
INSERT INTO TA VALUES ('e12349', '1', 'PL101');
INSERT INTO TA VALUES ('e12349', '2', 'PL101');
INSERT INTO TA VALUES ('e12349', '3', 'PL101');

CALL add_enrollment('e12348', 'CS101');
CALL add_enrollment('e12350', 'DS101');
CALL add_enrollment('e12355', 'FC101');
CALL add_enrollment('e12348', 'FC101');