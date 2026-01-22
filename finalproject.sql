
-- Create the database if it doesn't exist
IF DB_ID('MentalHealthTrackerDB') IS NULL
BEGIN
    CREATE DATABASE MentalHealthTrackerDB;
END
GO

USE MentalHealthTrackerDB;
GO


-- ============================
-- Drop tables if exist 
-- ============================

IF OBJECT_ID('dbo.MHT_ResponseLogs', 'U') IS NOT NULL DROP TABLE dbo.MHT_ResponseLogs;
IF OBJECT_ID('dbo.MHT_UserAnswers', 'U') IS NOT NULL DROP TABLE dbo.MHT_UserAnswers;
IF OBJECT_ID('dbo.MHT_LifestyleRecords', 'U') IS NOT NULL DROP TABLE dbo.MHT_LifestyleRecords;
IF OBJECT_ID('dbo.MHT_QuestionsList', 'U') IS NOT NULL DROP TABLE dbo.MHT_QuestionsList;
IF OBJECT_ID('dbo.MHT_QuestionnaireList', 'U') IS NOT NULL DROP TABLE dbo.MHT_QuestionnaireList;
IF OBJECT_ID('dbo.MHT_UserAccounts', 'U') IS NOT NULL DROP TABLE dbo.MHT_UserAccounts;
IF OBJECT_ID('dbo.MHT_QuestionaireAnswers', 'U') IS NOT NULL DROP TABLE dbo.MHT_QuestionaireAnswers;

GO
-- ============================
-- Create Tables
-- ============================

CREATE TABLE dbo.MHT_UserAccounts
(
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    username NVARCHAR(50) UNIQUE NOT NULL,
    password_hash VARBINARY(64) NOT NULL,
    created_at DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.MHT_QuestionnaireList
(
    questionnaire_id INT IDENTITY(1,1) PRIMARY KEY,
    questionnaire_name NVARCHAR(100) NOT NULL
);
GO

CREATE TABLE dbo.MHT_QuestionsList
(
    question_id INT IDENTITY(1,1) PRIMARY KEY,
    questionnaire_id INT NOT NULL,
    question_text NVARCHAR(255) NOT NULL,
    max_score INT NOT NULL CHECK (max_score BETWEEN 1 AND 10),
    CONSTRAINT FK_QuestionsList_QuestionnaireList FOREIGN KEY (questionnaire_id) REFERENCES dbo.MHT_QuestionnaireList(questionnaire_id)
);
GO

CREATE TABLE dbo.MHT_UserAnswers
(
    answer_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    question_id INT NOT NULL,
    answer_date DATE NOT NULL,
    score INT NOT NULL CHECK (score >= 0),
    CONSTRAINT FK_UserAnswers_UserAccounts FOREIGN KEY (user_id) REFERENCES dbo.MHT_UserAccounts(user_id),
    CONSTRAINT FK_UserAnswers_QuestionsList FOREIGN KEY (question_id) REFERENCES dbo.MHT_QuestionsList(question_id)
);
GO

CREATE TABLE dbo.MHT_LifestyleRecords
(
    lifestyle_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    record_date DATE NOT NULL,
    sleep_hours FLOAT CHECK (sleep_hours BETWEEN 0 AND 24),
    exercise_minutes INT CHECK (exercise_minutes >= 0),
    CONSTRAINT FK_LifestyleRecords_UserAccounts FOREIGN KEY (user_id) REFERENCES dbo.MHT_UserAccounts(user_id)
);
GO

CREATE TABLE dbo.MHT_ResponseLogs
(
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    log_date DATETIME DEFAULT GETDATE(),
    message NVARCHAR(255)
);
GO

CREATE TABLE dbo.MHT_LoginHistory (
    login_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    login_time DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES dbo.MHT_UserAccounts(user_id)
);
GO

CREATE TABLE dbo.MHT_QuestionnaireAnswers (
    AnswerID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    QuestionNumber INT NOT NULL,
    AnswerValue INT NOT NULL,
    SubmissionDate DATETIME DEFAULT GETDATE()
);
GO


-- ============================
-- Insert Sample Questionnaire and Questions (PHQ-9)
-- ============================

INSERT INTO dbo.MHT_QuestionnaireList (questionnaire_name) VALUES ('PHQ-9');
GO

DECLARE @phq9_id INT;
SET @phq9_id = SCOPE_IDENTITY();

INSERT INTO dbo.MHT_QuestionsList (questionnaire_id, question_text, max_score)
VALUES
(@phq9_id, 'Little interest or pleasure in doing things', 3),
(@phq9_id, 'Feeling down, depressed, or hopeless', 3),
(@phq9_id, 'Trouble falling or staying asleep, or sleeping too much', 3),
(@phq9_id, 'Feeling tired or having little energy', 3),
(@phq9_id, 'Poor appetite or overeating', 3),
(@phq9_id, 'Feeling bad about yourself — or that you are a failure or have let yourself or your family down', 3),
(@phq9_id, 'Trouble concentrating on things, such as reading the newspaper or watching television', 3),
(@phq9_id, 'Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving a lot more than usual', 3),
(@phq9_id, 'Thoughts that you would be better off dead, or of hurting yourself in some way', 3);
GO

-- ============================
-- Stored Procedure: Signup User
-- ============================

IF OBJECT_ID('dbo.MHT_SignupUser', 'P') IS NOT NULL DROP PROCEDURE dbo.MHT_SignupUser;
GO
CREATE PROCEDURE dbo.MHT_SignupUser
    @username NVARCHAR(50),
    @password NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.MHT_UserAccounts WHERE username = @username)
    BEGIN
        THROW 50000, 'Username already exists.', 1;
        RETURN;
    END

    DECLARE @password_hash VARBINARY(64);
    SET @password_hash = HASHBYTES('SHA2_256', CONVERT(VARBINARY(100), @password));

    INSERT INTO dbo.MHT_UserAccounts (username, password_hash)
    VALUES (@username, @password_hash);

    SELECT 'Signup successful' AS Message;
END;
GO

-- ============================
-- Stored Procedure: Login User
-- ============================


ALTER PROCEDURE dbo.MHT_LoginUser
    @username NVARCHAR(50),
    @password NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @password_hash VARBINARY(64);
    SET @password_hash = HASHBYTES('SHA2_256', CONVERT(VARBINARY(100), @password));

    DECLARE @user_id INT;

    SELECT @user_id = user_id 
    FROM dbo.MHT_UserAccounts 
    WHERE username = @username AND password_hash = @password_hash;

    IF @user_id IS NULL
    BEGIN
        SELECT 'Invalid username or password.' AS Message;
    END
    ELSE
    BEGIN
      
        INSERT INTO dbo.MHT_LoginHistory (user_id, login_time) VALUES (@user_id, GETDATE());

        SELECT @user_id AS UserID, 'Login successful' AS Message;
    END
END;
GO


-- ============================
-- Stored Procedure: Insert User Answer
-- ============================

IF OBJECT_ID('dbo.MHT_InsertUserAnswer', 'P') IS NOT NULL DROP PROCEDURE dbo.MHT_InsertUserAnswer;
GO
CREATE PROCEDURE dbo.MHT_InsertUserAnswer
    @user_id INT,
    @question_id INT,
    @answer_date DATE,
    @score INT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.MHT_UserAnswers (user_id, question_id, answer_date, score)
    VALUES (@user_id, @question_id, @answer_date, @score);

    SELECT 'Answer recorded successfully.' AS Message;
END;
GO

-- ============================
-- Stored Procedure: Insert Lifestyle Record
-- ============================

IF OBJECT_ID('dbo.MHT_InsertLifestyleRecord', 'P') IS NOT NULL DROP PROCEDURE dbo.MHT_InsertLifestyleRecord;
GO
CREATE PROCEDURE dbo.MHT_InsertLifestyleRecord
    @user_id INT,
    @record_date DATE,
    @sleep_hours FLOAT,
    @exercise_minutes INT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.MHT_LifestyleRecords (user_id, record_date, sleep_hours, exercise_minutes)
    VALUES (@user_id, @record_date, @sleep_hours, @exercise_minutes);

    SELECT 'Lifestyle data recorded successfully.' AS Message;
END;
GO

-- ============================
-- Stored Procedure: Predict Mood
-- ============================

IF OBJECT_ID('dbo.MHT_PredictMood', 'P') IS NOT NULL DROP PROCEDURE dbo.MHT_PredictMood;
GO
CREATE PROCEDURE dbo.MHT_PredictMood
    @user_id INT,
    @record_date DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @total_score INT;
    DECLARE @sleep FLOAT;
    DECLARE @exercise INT;
    DECLARE @adjusted_score FLOAT;

    SELECT @total_score = SUM(score)
    FROM dbo.MHT_UserAnswers
    WHERE user_id = @user_id AND answer_date = @record_date;

    IF @total_score IS NULL
    BEGIN
        SELECT 'No answers found for the given date.' AS Mood;
        RETURN;
    END

    SELECT TOP 1 @sleep = sleep_hours, @exercise = exercise_minutes
    FROM dbo.MHT_LifestyleRecords
    WHERE user_id = @user_id AND record_date = @record_date;

    IF @sleep IS NULL SET @sleep = 7;       
    IF @exercise IS NULL SET @exercise = 30;

    SET @adjusted_score = @total_score - (@sleep * 0.1) - (@exercise * 0.05);
    IF @adjusted_score < 0 SET @adjusted_score = 0;

    IF @adjusted_score <= 4
        SELECT 'Minimal or No Depression' AS Mood, @adjusted_score AS AdjustedScore;
    ELSE IF @adjusted_score <= 9
        SELECT 'Mild Depression' AS Mood, @adjusted_score AS AdjustedScore;
    ELSE IF @adjusted_score <= 14
        SELECT 'Moderate Depression' AS Mood, @adjusted_score AS AdjustedScore;
    ELSE IF @adjusted_score <= 19
        SELECT 'Moderately Severe Depression' AS Mood, @adjusted_score AS AdjustedScore;
    ELSE
        SELECT 'Severe Depression' AS Mood, @adjusted_score AS AdjustedScore;
END;
GO

-- ============================
-- Sample Data Inserts for Testing
-- ============================

-- Insert answers for Ali
INSERT INTO dbo.MHT_UserAnswers (user_id, question_id,answer_date,score)
VALUES
(
  (SELECT user_id FROM dbo.MHT_UserAccounts WHERE username = 'ali_khan'),
  (SELECT TOP 1 question_id FROM dbo.MHT_QuestionsList WHERE question_text LIKE '%pleasure%'),
  '2025-05-30',
  2
),
(
  (SELECT user_id FROM dbo.MHT_UserAccounts WHERE username = 'ali_khan'),
  (SELECT TOP 1 question_id FROM dbo.MHT_QuestionsList WHERE question_text LIKE '%hopeless%'),
  '2025-05-30',
  3
);

-- Insert lifestyle data for Ali
INSERT INTO dbo.MHT_LifestyleRecords (user_id, record_date, sleep_hours, exercise_minutes)
VALUES
(
  (SELECT user_id FROM dbo.MHT_UserAccounts WHERE username = 'ali_khan'),
  '2025-05-30',
  6.5,
  20
);

-- Insert answers for Sara
INSERT INTO dbo.MHT_UserAnswers (user_id, question_id, answer_date, score)
VALUES
(
  (SELECT user_id FROM dbo.MHT_UserAccounts WHERE username = 'sara_ahmed'),
  (SELECT TOP 1 question_id FROM dbo.MHT_QuestionsList WHERE question_text LIKE '%pleasure%'),
  '2025-05-30',
  1
),
(
  (SELECT user_id FROM dbo.MHT_UserAccounts WHERE username = 'sara_ahmed'),
  (SELECT TOP 1 question_id FROM dbo.MHT_QuestionsList WHERE question_text LIKE '%hopeless%'),
  '2025-05-30',
  0
);

-- Insert lifestyle data for Sara
INSERT INTO dbo.MHT_LifestyleRecords (user_id, record_date, sleep_hours, exercise_minutes)
VALUES
(
  (SELECT user_id FROM dbo.MHT_UserAccounts WHERE username = 'sara_ahmed'),
  '2025-05-30',
  7.5,
  40
);

--=======================================
--Transactions
=========================================


DECLARE @today DATE = CAST(GETDATE() AS DATE);

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC dbo.MHT_SignupUser @username = 'test_user', @password = 'testpass123';

    DECLARE @new_user_id INT;
    SELECT @new_user_id = user_id FROM dbo.MHT_UserAccounts WHERE username = 'test_user';

    EXEC dbo.MHT_InsertUserAnswer 
        @user_id = @new_user_id, 
        @question_id = 1, 
        @answer_date = @today, 
        @score = 2;

    EXEC dbo.MHT_InsertUserAnswer 
        @user_id = @new_user_id, 
        @question_id = 2, 
        @answer_date = @today, 
        @score = 3;

    EXEC dbo.MHT_InsertLifestyleRecord 
        @user_id = @new_user_id, 
        @record_date = @today, 
        @sleep_hours = 7.0, 
        @exercise_minutes = 30;

    COMMIT TRANSACTION;

    PRINT 'All operations completed successfully.';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;

    PRINT 'Transaction rolled back due to error:';
    PRINT ERROR_MESSAGE();
END CATCH;



-- Trigger: Log user answers insertion
CREATE TRIGGER trg_LogUserAnswerInsert
ON dbo.MHT_UserAnswers
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.MHT_ResponseLogs (user_id, message)
    SELECT DISTINCT user_id, 'New answer recorded on ' + CONVERT(varchar, GETDATE(), 120)
    FROM inserted;
END;
GO


-- View: Daily summary of user answers
CREATE VIEW dbo.vw_UserDailyAnswerSummary
AS
SELECT 
    u.user_id,
    u.username,
    ua.answer_date,
    COUNT(ua.answer_id) AS total_answers,
    SUM(ua.score) AS total_score
FROM dbo.MHT_UserAccounts u
JOIN dbo.MHT_UserAnswers ua ON u.user_id = ua.user_id
GROUP BY u.user_id, u.username, ua.answer_date;
GO




-- ============================
-- Sample Queries to Test
-- ============================

-- Login Test
EXEC dbo.MHT_LoginUser @username='ali_khan', @password='password123';

-- View all users
SELECT * FROM dbo.MHT_UserAccounts;

-- View All Questions With Questionnaire Name
SELECT q.question_id, q.question_text, q.max_score, qt.questionnaire_name
FROM dbo.MHT_QuestionsList q
JOIN dbo.MHT_QuestionnaireList qt ON q.questionnaire_id = qt.questionnaire_id;

--View All Answers From All Users
SELECT a.answer_id, u.username, q.question_text, a.answer_date, a.score
FROM dbo.MHT_UserAnswers a
JOIN dbo.MHT_UserAccounts u ON a.user_id = u.user_id
JOIN dbo.MHT_QuestionsList q ON a.question_id = q.question_id
ORDER BY a.answer_date DESC;

--View Lifestyle Records
SELECT l.lifestyle_id, u.username, l.record_date, l.sleep_hours, l.exercise_minutes
FROM dbo.MHT_LifestyleRecords l
JOIN dbo.MHT_UserAccounts u ON l.user_id = u.user_id
ORDER BY l.record_date DESC;

 --Check if Login Works (returns ID and message)
EXEC dbo.MHT_LoginUser @username='ali_khan', @password='password123';
EXEC dbo.MHT_LoginUser @username='ahmend_khan', @password='password123';

--Try Signup for a New Use
EXEC dbo.MHT_SignupUser @username='new_user1', @password='newpass123';


SELECT TOP 9 * FROM dbo.MHT_Questionslist;

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'MHT_QuestionnaireAnswers';

SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'MHT_QuestionnaireAnswers';

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'MHT_QuestionnaireAnswers';

EXEC sp_help 'dbo.MHT_QuestionnaireAnswers';

--check tables
SELECT name FROM sys.tables;


