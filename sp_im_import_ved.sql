USE [OFFICE]
GO

/****** Object:  StoredProcedure [dbo].[sp_im_import_ved]    Script Date: 19.09.2018 15:47:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*	Хранимая процедура, отправляющая
 *	уведомление ответственным сотрудникам 
 *	об отсутствующих в Тетре кодах ВЭД до начала 
 *	процесса импорта ежедневных отгрузок ИМ 
 *	автор Yalovoy Alexandr
 */

CREATE procedure [dbo].[sp_im_import_ved]
as

declare
--xml
	@sqlstmt		nvarchar(max),
	@StringXML		nvarchar(max),
--ftp
	@FTPServer		varchar(128)	= '192.168.1.1',
	@FTPUser		varchar(128)	= 'user',
	@FTPPWD			varchar(128)	= 'pass',
	@FTPPath		varchar(128)	= '/work/solutions/',
	@SourceFile		varchar(500)	= 'dispatch*.xml',
	@DestPath		varchar(128)	= 'c:\system',
	@workfilename	varchar(128)	= 'c:\system\ftpcon.txt',
--cmd
	@cmd			varchar(1000),
	@isExists		int,
	@fullPath		varchar(200),
	@file			varchar(128),
--notify
	@errorText		as nvarchar(max),
	@profileName	as varchar(100)	= 'MAILER',
	@tema			as varchar(100)	= 'Импорт отгрузок Интернет-магазина за ',
	@tema_Date		as varchar(200),
	@mailOper		as varchar(100)	= 'mail@ukr.net',
	@recip			as varchar(500) = 'receiver1@ukr.net;receiver2@ukr.net',
	@fileDate		as varchar(200);

declare @dirFile as table (
	[file]			varchar(500));

declare	@isEx as table (
	[file]			varchar(128), 
	[directory]		varchar(128), 
	[disk]			varchar(128));

declare @resXml as table (
	[result]		xml);

--проверка на существование каталога для работы с файлом
insert into @isEx 
	exec master.dbo.xp_fileexist @DestPath

if (select top 1 [directory] from @isEx) = 1
begin
	select @cmd = 'rmdir /s/q ' + @DestPath
	exec master..xp_cmdshell @cmd, no_output
end 

select @cmd = 'mkdir ' + @DestPath
exec master..xp_cmdshell @cmd, no_output

--работа с FTP 
select @FTPServer = replace(replace(replace(@FTPServer, '|', '^|'),'<','^<'),'>','^>')
select @FTPUser = replace(replace(replace(@FTPUser, '|', '^|'),'<','^<'),'>','^>')
select @FTPPWD = replace(replace(replace(@FTPPWD, '|', '^|'),'<','^<'),'>','^>')
select @FTPPath = replace(replace(replace(@FTPPath, '|', '^|'),'<','^<'),'>','^>')

select	@cmd = 'echo '	+ 'open ' + @FTPServer + ' > ' + @workfilename
exec master..xp_cmdshell @cmd, no_output
select	@cmd = 'echo '	+ @FTPUser + '>> ' + @workfilename
exec master..xp_cmdshell @cmd, no_output
select	@cmd = 'echo '	+ @FTPPWD + '>> ' + @workfilename
exec master..xp_cmdshell @cmd, no_output
select @cmd = 'echo ' + 'prompt ' + ' >> ' + @workfilename  
exec master..xp_cmdshell @cmd, no_output
select @cmd = 'echo ' + 'lcd ' + @DestPath + ' >> ' + @workfilename  
exec master..xp_cmdshell @cmd, no_output
select @cmd = 'echo ' + 'cd ' + @FTPPath + ' >> ' + @workfilename  
exec master..xp_cmdshell @cmd, no_output
select @cmd = 'echo ' + 'mget ' + @FTPPath + @SourceFile + ' >> ' + @workfilename  
exec master..xp_cmdshell @cmd, no_output
select	@cmd = 'echo '	+ 'quit' + ' >> ' + @workfilename
exec master..xp_cmdshell @cmd, no_output
select @cmd = 'ftp -s:' + @workfilename
exec master..xp_cmdshell @cmd, no_output
select @cmd = 'del /q ' + @workfilename
exec master..xp_cmdshell @cmd, no_output

--проверка существования файла импорта
select @cmd = 'dir ' + @DestPath
insert into @dirFile([file])
	exec master..xp_cmdshell @cmd

delete from @dirFile
where [file] not like '%dispatch%' or [file] is null

if exists (select top 1 * from @dirFile)
begin
	update @dirFile
	set [file] = ltrim(rtrim(substring([file], charindex('dispatch', [file]), 100))) from @dirFile

	declare cur cursor for
		select [file] from @dirFile

		open cur

	fetch next from cur into @file
	while @@fetch_status = 0
	begin
		--формируем тему письма
		select @fileDate = cast(convert(varchar, cast(substring(@file, 9, 8) as date), 104) as varchar(20))

		select @tema_Date = @tema + @fileDate
	
		delete from @isEx
		select @fullPath = @DestPath + '\' + @file

		insert into @isEx 
			exec master.dbo.xp_fileexist @fullPath

		if (select top 1 [file] from @isEx) = 1
		begin
		--грузим продажи из файла импорта
		set @sqlstmt= 'SELECT * FROM OPENROWSET ( BULK ''' + @fullPath + ''', SINGLE_CLOB) AS xmlData'
	
		insert into @resXml 
			execute (@sqlstmt)

		select @StringXML = convert(nvarchar(max), result) from @resXml

		truncate table [WEB].dim.sale

		insert into [WEB].dim.sale([GoodID])
			execute OFFICE.dbo.sp_InternetStoreShipping_Import @StringXML

		--формируем тело уведомления об отсутствующих кодах ВЭД
		select @errorText = 'Добрый день! Отсутствуют коды УКТВЭД по следующим товарам:' + 
			N'<br>' + 
			N'<table border="1">' +  
			N'<tr>
				<th>ТоварИД</th>
				<th>Товар</th>
				<th>Штрихкод</th>
				<th>Код УКТВЭД</th>
			</tr>' + 
			cast((
			select 
			td =   m.GoodID,	'',
			td =   m.[Name],	'', 
			td =   op203.[Value],	'', 
			td =   opv336.[Name],	''
			from NodeBU.dbo.gd_good as m with(nolock)
				left join NodeBU.dbo.mn_object_property op203 with(nolock) on op203.ObjectID=m.GoodID and op203.PropertyID=203 
				left join NodeBU.dbo.mn_object_property op336 with(nolock) on op336.ObjectID=m.GoodID and op336.PropertyID=336 
				left join NodeBU.dbo.mn_directory opv336 with(nolock) on opv336.DirectoryID = cast(op336.[Value] as int) 
			where m.GoodID in (	--проверка отсутствующих в Тетре кодов ВЭД
								select
								s.GoodID
								--,t.VED
								from [WEB].dim.sale as s
								left join (
									select 
									gg.GoodID, 
									cast(md.[Name] as nvarchar(20)) VED 
									from [NodeBU].dbo.gd_good as gg with(nolock)
									JOIN [NodeBU].dbo.mn_object_property as mop with(nolock) on mop.ObjectID = gg.GoodID and mop.PropertyID = 336
									JOIN [NodeBU].dbo.mn_directory as md with(nolock) on md.DirectoryID = mop.[Value]
								) as t on s.GoodID = t.GoodID
								where t.VED is null)
			for xml path('tr'), type   
			) as nvarchar(max) ) +  
			N'</table>'; 

		--отправка письма
		if @errorText is not null
			exec msdb.dbo.sp_send_dbmail 
			@profile_name = @profileName,
			@recipients = @recip,
			@subject = @tema_Date,  
			@body = @errorText,  
			@body_format = 'HTML';
		end

		--удаляем файл импорта из врменной папки
		select @cmd = 'del /q' + @fullPath
		exec master..xp_cmdshell @cmd, no_output

		fetch next from cur into @file
	end;

	close cur
	deallocate cur
end

--удаляем временный каталог
select @cmd = 'rmdir /s/q ' + @DestPath
exec master..xp_cmdshell @cmd, no_output
go