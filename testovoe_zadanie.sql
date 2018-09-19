/*
�������� ������� ���������:

1) ����� ������� ���� ������ � ����� ���������.

1� TFact � ������ TFactID (��������� ���� INT, IDENTITY(1,1)),  Year (INT), Month (INT),  SomeINTData (INT), SomeTextData (varchar(MAX))

� ��� ������� ����� ������������� ��� �������� �� �������� ��������� 100 000 ������� � ������������ �����������. ���� Year � Month ��������� �  5 - 10  ������ ��������
.

2� THash ������� � ������ Year, Month, HashCode varchar(400). ��� ������ ���� ���������� ���������� ��������� ����.


2) ������� �������� ���������, ������� �������� �� ���� ��������� @Year, @Month

������ ������� �� ������� TFact ���� ������� �� ���� ���������� � ������� ������ �� ���� ����� ���� ������ �������. 
(���������: ��� ������� ������� ������� ��������������� �������� HASHBYTES)

����� ���������� ��� ��� ��������� � ������� THash ������ �� ���������� ���������� ��������. 
(���� � ������� THash ������ �������������� �������� �� ���� ����� @Year � @Month ��� ����������, �� �������� ��)

3) �������� ��������� ������� usp_Check ������� �� ���� �������� ��� � ����� �

����������� ��� (���������� �� ��������� �.2) � ���� ��� ���������� ���� � ������
���� ������ � ������� THash � ����������� �������� � �������� � ������� ���������,

�� ���������� 1  ����� ���������� 0

4) ������� �������� ��������� usp_init ��� ����������, 
� ����� �������� �� ���� ����� � ������� ��������� � ������� TFact 
� ��� ������� ����������� ��������� ��������� �������� ��������� �� ���� 2
(����� ������� ����������� ������� THash)

5) ������� SQL-������ ������� �������� �� ���� ������, ������������ ������ ���� � ������ ��.

������� ������ ������ ��������� ��� ������ ������� usp_Check ���������� �� ������ � ������� TFact 
� ������ �� ����� ������ (��� +�����) ����������.

���� ���������� ���� �� ���� ������ -  �� ��������� �����,

������ �� ��������� �������� ��������� ������ (����� ����� ������������ �������� EXCEPT) ����� ������� ������� TFact ������� �� � ��� �� �������� �� �������� �� ������. ��������� ������ ������ �� �������� �� ������� �������� �����������.
 ������� ������������ ���������� �����������.


�������� ������������ ����� ���������:

�) ��������� usp_Init
�) ������ ����� ����
�) ����������� ������ ������ � ������� TFact
�) ��������� ������ �������� (��� 5) - ������ ������ ������ ���������� ������.
*/

/************************************* ���������� **********************************************/
--1. �������� �� � ������
USE [master]  
GO
  
IF DB_ID (N'DBNAME') IS NOT NULL
DROP DATABASE [DBNAME];
GO
CREATE DATABASE [DBNAME];  
GO 

USE [DBNAME]
GO

CREATE TABLE [dbo].[TFact](
	[TFactID]		INT IDENTITY(1,1) NOT NULL,
	[Year]			INT NOT NULL,
	[Month]			INT NOT NULL,
	[SomeINTData]	INT NULL,
	[SomeTextData]	VARCHAR(MAX),
	CONSTRAINT [PK_TFact] PRIMARY KEY CLUSTERED
	(
		[TFactID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[THash](
	[Year]		INT NOT NULL,
	[Month]		INT NOT NULL,
	[HashCode]	VARCHAR(400),
	PRIMARY KEY ([Year], [Month])
) ON [PRIMARY]
GO


--��������� ������� TFact
USE [DBNAME]
GO

DECLARE
	@CountIn	AS INT = 1,
	@CountOut	AS INT = 1,
	@year		AS INT = 2012,
	@month		AS INT = 3;

WHILE @CountOut <= 100000
BEGIN
	SET @CountIn = 1
	WHILE @CountIn <= 20000
	BEGIN
		INSERT INTO [TFact]([Year], [Month], [SomeINTData], [SomeTextData])
		SELECT 
		@year, 
		@month,
		(SELECT TOP 1 ABS(CHECKSUM(NEWID())) % 100000 FROM sysobjects A CROSS JOIN sysobjects B),	--��������� �����
		(SELECT CONVERT(VARCHAR(255), NEWID()))														--��������� ������									
		SET @CountIn = @CountIn + 1
	END
	SET @CountOut = @CountOut + 20000
	SET @year = @year + 1
	SET @month = @month + 1
END


--2. �������� �������� ��������� usp_GetHash
USE [DBNAME]
GO

CREATE PROCEDURE [dbo].[usp_GetHash]
	@Year INT, @Month INT

AS
SET NOCOUNT ON

DECLARE @hash AS VARCHAR(400)

SET @hash = (SELECT HASHBYTES('SHA2_512', (SELECT '' + [TFactID], [Year], [Month], [SomeINTData], [SomeTextData] 
											FROM TFact 
											WHERE [Year] = t.[Year] and [Month] = t.[Month] 
											ORDER BY [Year], [Month] ASC FOR XML PATH(''))) HashNames
			FROM TFact t
			WHERE t.[Year] = @Year AND t.[Month] = @Month 
			GROUP BY t.[Year], t.[Month])

--update
IF EXISTS (SELECT TOP 1 * FROM THash WHERE [Year] = @Year AND [Month] = @Month)
BEGIN
	UPDATE THash
	SET [HashCode] = @hash
	WHERE [Year] = @Year AND [Month] = @Month
END

--insert
IF NOT EXISTS(SELECT TOP 1 * FROM THash WHERE [Year] = @Year AND [Month] = @Month) AND @hash IS NOT NULL
BEGIN
	INSERT INTO THash ([Year],[Month],[HashCode])
	SELECT
	@Year,
	@Month,
	@hash
END
GO


--3. �������� ������� usp_Check
USE [DBNAME]
GO

CREATE FUNCTION dbo.usp_Check
(
	@year	INT,
	@month	INT
)
RETURNS INT
AS
BEGIN

DECLARE
	@hash	VARCHAR(400),
	@res	BIT

SET @hash = (SELECT HASHBYTES('SHA2_512', (SELECT '' + [TFactID], [Year], [Month], [SomeINTData], [SomeTextData] 
											FROM TFact 
											WHERE [Year] = t.[Year] and [Month] = t.[Month] 
											ORDER BY [Year], [Month] ASC FOR XML PATH(''))) HashNames
			FROM TFact t
			WHERE t.[Year] = @Year AND t.[Month] = @Month 
			GROUP BY t.[Year], t.[Month])

IF EXISTS (SELECT TOP 1 * FROM THash WHERE [Year] = @year AND [Month] = @month AND [HashCode] = @hash)
	SET @res = 1

IF NOT EXISTS (SELECT TOP 1 * FROM THash WHERE [Year] = @year AND [Month] = @month AND [HashCode] = @hash)
	SET @res = 0

RETURN(@res)

END
GO


--4. �������� �������� ��������� usp_Init
USE [DBNAME]
GO

CREATE PROCEDURE [dbo].[usp_Init]

AS
SET NOCOUNT ON

DECLARE
	@year	AS INT,
	@month	AS INT;

DECLARE hf_Cur CURSOR FOR
	SELECT DISTINCT [Year], [Month] FROM [TFact];

OPEN hf_Cur;

FETCH NEXT FROM hf_Cur INTO @year, @month
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC [dbo].[usp_GetHash] @year, @month
	FETCH NEXT FROM hf_Cur INTO @year, @month
END;

CLOSE hf_Cur;
DEALLOCATE hf_Cur;

GO


--5. �������� SQL-�������
USE [DBNAME]
GO

DECLARE
	@path		AS VARCHAR(200),
	@year		AS INT,
	@month		AS INT;

SET @path = N'C:\MSSQL_2017\Backup\DBNAME.BAK'

DECLARE @Diff AS TABLE (
	DYear	INT, 
	DMonth	INT, 
	DRes	BIT		-- 0-������ ����������, 1-�� ����������
	)

DECLARE Dif_cur CURSOR FOR
	SELECT DISTINCT [Year], [Month] FROM [TFact];

OPEN Dif_cur;

FETCH NEXT FROM Dif_cur INTO @year, @month
WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO @Diff(DYear, DMonth, DRes)
	SELECT 
		@year,
		@month,
		(SELECT dbo.usp_Check(@year, @month))
	FETCH NEXT FROM Dif_cur INTO @year, @month
END;

CLOSE Dif_cur;
DEALLOCATE Dif_cur;

IF EXISTS(SELECT TOP 1 * FROM @Diff WHERE DRes = 0)
BEGIN
	RESTORE DATABASE DBNAME_REST
	FROM DISK = @path
	  WITH REPLACE, 
	  RECOVERY,
	  MOVE 'DBNAME' TO N'C:\MSSQL_2017\Data\DBNAME_REST.mdf',
	  MOVE 'DBNAME_log' TO N'C:\MSSQL_2017\Log\DBNAME_REST_log.ldf';

	SELECT f.[TFactID], f.[Year], f.[Month], f.[SomeINTData], f.[SomeTextData] 
	FROM [DBNAME].[dbo].[TFact] AS f
	INNER JOIN @Diff AS d 
	ON f.[Year] = d.DYear AND f.[Month] = d.[DMonth]
	WHERE d.DRes =  0

	EXCEPT

	SELECT f1.[TFactID], f1.[Year], f1.[Month], f1.[SomeINTData], f1.[SomeTextData] 
	FROM [DBNAME_REST].[dbo].[TFact] AS f1
	INNER JOIN @Diff AS d1 ON f1.[Year] = d1.DYear AND f1.[Month] = d1.[DMonth]
	WHERE d1.DRes =  0
END