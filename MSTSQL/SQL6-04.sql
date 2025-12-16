-- 查詢每一個資料庫，資料檔案實際所使用的空間、資料檔案使用的磁碟空間、交易記錄檔案實際所使用的空間、交易記錄檔案使用的磁碟空間。
USE master
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tDBSize]') AND type in (N'U'))
DROP TABLE [dbo].[tDBSize]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tLogSize]') AND type in (N'U'))
DROP TABLE [dbo].[tLogSize]
GO
CREATE TABLE tDBSize
([DBName] [nchar](128) NULL DEFAULT (db_name()),
Fileid INT, FileGroup INT, TotalExtents INT,
UsedExtents INT, Name SYSNAME, FileName NVARCHAR(4000)
)
GO
CREATE TABLE tLogSize
(DBName sysname, logsize float, used float, status int)
GO
--
SET NOCOUNT ON
DECLARE @mydb sysname,@mystr nvarchar(4000)
  
DECLARE allDB CURSOR FOR
SELECT name FROM master..sysdatabases
  
OPEN allDB
  
FETCH NEXT FROM allDB INTO @mydb
  
WHILE (@@FETCH_STATUS=0)
BEGIN
SET @mystr='USE ['+ @mydb +'] INSERT master.dbo.tDBSize(Fileid,FileGroup,TotalExtents,UsedExtents,Name,FileName) EXEC (''DBCC showfilestats'')'
EXECUTE (@mystr)
  
FETCH NEXT FROM allDB INTO @mydb
END
  
CLOSE allDB
DEALLOCATE allDB
  
--
INSERT INTO master.dbo.tLogSize
EXECUTE ('DBCC SQLPERF(LOGSPACE)')
  
-- 精確到小數點第二位
SELECT D.DBName N'資料庫',
CAST(TotalExtents AS decimal(18,2)) N'資料使用硬碟空間(MB)',
CAST(UsedExtents AS decimal(18,2)) N'資料實際使用(MB)',
CAST(logsize AS decimal(18,2)) '交易記錄檔使用硬碟空間(MB)',
CAST((logsize*used/100) AS decimal(18,2)) '交易記錄檔實際使用(MB)'
FROM tLogSize L INNER JOIN (
SELECT DBName ,
SUM(TotalExtents*64.0/1024) N'TotalExtents',
SUM(UsedExtents*64.0/1024) N'UsedExtents'
FROM tDBSize
GROUP BY DBName) D
ON L.DBName=D.DBName
  
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tDBSize]') AND type in (N'U'))
DROP TABLE [dbo].[tDBSize]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tLogSize]') AND type in (N'U'))
DROP TABLE [dbo].[tLogSize]
GO