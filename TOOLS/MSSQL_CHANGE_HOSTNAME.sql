IF SERVERPROPERTY('ServerName')<>@@SERVERNAME
​
BEGIN
​
  DECLARE @srvname sysname
​
  SET @srvname=@@SERVERNAME
​
  EXEC sp_dropserver @server=@srvname
​
  SET @srvname=CAST(SERVERPROPERTY('ServerName') as sysname)
​
  EXEC sp_addserver @server = @srvname , @local = 'LOCAL'
​
END