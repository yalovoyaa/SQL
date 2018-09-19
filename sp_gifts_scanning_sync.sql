USE [WMS]
GO

/****** Object:  StoredProcedure [dbo].[sp_gifts_scanning_sync]    Script Date: 19.09.2018 16:03:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*	A stored procedure that synchronizes
 *	ERP and warehouse nomenclature
 *	by Yalovoy Alexandr
 */


CREATE PROCEDURE [dbo].[sp_gifts_scanning_sync]
AS
BEGIN
	SET XACT_ABORT ON
	SET NOCOUNT ON

declare
	@fname		as varchar(500),
	@giftName	as varchar(500),
	@gifts		as varchar(50),
	@wmsGood	as int,
	@tetraGood	as int;

declare @gGifts as table (
	[wmsGood]	int,
	[tetraGood]	int,
	[fName]		varchar(500),
	[Gifts]		varchar(50)			
	)
/*
declare @Result as table (
	[wmsGoodId]			int,
	[tetraGoodId]		int,
	[NewGiftsFullName]	varchar(max),
	[date]				smalldatetime	
	)
*/
declare cur cursor for
	select
		[wmsGood],
		[tetraGood],
		[fName],
		[Gifts]
	from @gGifts

insert into @gGifts ([wmsGood], [tetraGood], [fName], [Gifts])
	select
		wms.wmsGoodId,
		wms.tetraGoodId,
		convert(varchar(500), wms.FullName) as FullName,
		hx.gift
	from (
	--склад
	select
		a.GoodID as wmsGoodId,
		b.OutObjectID as tetraGoodId,
		v.[Value] as [FullName]
	from  dbo.st_good as a
	inner join dbo.mn_ei_outer_id_v as b on b.ObjectID = a.GoodID
	inner join dbo.mn_object_property_vl as v on a.GoodID = v.ObjectID and v.PropertyID = 301
	where convert(varchar(500), v.[Value]) not like 'Gifts Scanning%'
	) as wms

	inner join (
	--ERP
	select 
		m.[Name] as [gift], 
		g.GoodID
	from dbo.gd_good as g with(nolock)
	inner join dbo.mn_directory as m with(nolock) on g.GGID = m.DirectoryID

	where g.GGID = 385916 
		and m.ClassID = 5190

	) as hx
	on hx.GoodID = wms.tetraGoodId

if exists (select top 1 * from @gGifts)
begin

open cur

fetch cur into
	@wmsGood,
	@tetraGood,
	@fname,
	@gifts

while @@FETCH_STATUS = 0
begin
	select @giftName = @gifts + ' ' + @fname
	
	begin transaction

	update dbo.mn_object_property_vl
	set [Value] = @giftName
	where ObjectID = @wmsGood and PropertyID = 301

	insert into dbo.sc_log ([ObjectID],[ActionID],[ObjectName],[Date],[K_err],[Machine],[User_NT],[UserID])
	select
		@wmsGood,
		2,
		@giftName,
		cast(getdate() as smalldatetime),
		'0000',
		'STN1',
		REPLACE(ORIGINAL_LOGIN(),'DOMAIN\',''),
		1

	commit transaction

/*
	insert into @Result (
		[wmsGoodId], 
		[tetraGoodId], 
		[NewGiftsFullName], 
		[date]
	)
	select 
		@wmsGood,
		@tetraGood,
		@giftName,
		cast(getdate()as smalldatetime)
*/

	fetch next from cur into @wmsGood, @tetraGood, @fname, @gifts
end

close cur
deallocate cur

/*
select 'Всего обновлено товаров: ' + cast((select count(*) from @Result) as varchar(50))
select * from @Result
*/
end

end
go