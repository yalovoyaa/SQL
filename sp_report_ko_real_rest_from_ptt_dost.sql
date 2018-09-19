USE [OFFICE]
GO

/****** Object:  StoredProcedure [dbo].[sp_report_ko_real_rest_from_ptt_dost]    Script Date: 19.09.2018 16:26:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*	Stored procedure for creating
 *	report on scarce goods in
 *	chain stores
 *	by Yalovoy Alexandr
 */


CREATE procedure [dbo].[sp_report_ko_real_rest_from_ptt_dost]
(
	@pDateS	datetime = NULL,
	@pDateE	datetime = NULL,
	@pEmpl	varchar(max) = NULL,
	@pTM	varchar(max) = NULL,
	@pPTT	varchar(max) = NULL,
	@pDebug	smallint	 = 0
)
as
begin
set nocount on
declare @coef smallmoney
declare @allPTT smallint = 0
declare @allTM  smallint = 0
declare @allSup smallint = 0
declare @im		smallint = 0
declare @pDateOut	datetime
declare @pDate3M	datetime
declare @pDate datetime

-- инициализация переменных
set @pDate = isnull(@pDate, cast(getdate() as date))
set @pDate = dateadd(second,-1, dateadd(day, 1, @pDate))

set @pDateS = isnull(@pDateS, cast(getdate() as date))
set @pDateS = dateadd(second,-1, dateadd(day, 1, @pDateS))

set @pDateE = isnull(@pDateE, cast(getdate() as date))
set @pDateE = dateadd(second,-1, dateadd(day, 1, @pDateE))


-- торговые марки
if object_id('tempdb.dbo.#tEmply') is not null drop table #tEmply
-- торговые марки
if object_id('tempdb.dbo.#tTMy') is not null drop table #tTMy
-- поставщики
if object_id('tempdb.dbo.#tSupy') is not null drop table #tSupy
-- идеальный сток
if object_id('tempdb.dbo.#tISy') is not null drop table #tISy
-- идеальный сток история
if object_id('tempdb.dbo.#tISyh') is not null drop table #tISyh
-- остатки
if object_id('tempdb.dbo.#tPry') is not null drop table #tPry
-- PTT
if object_id('tempdb.dbo.#tPTTy') is not null drop table #tPTTy
-- продажи за 3-и месяца (среднее)
if object_id('tempdb.dbo.#tAs3My') is not null drop table #tAs3My
-- поступления
if object_id('tempdb.dbo.#tIncomy') is not null drop table #tIncomy
-- кол-во дней с нулевым остатком
if object_id('tempdb.dbo.#tNulResty') is not null drop table #tNulResty


if @pDebug = 1
begin
	select @pEmpl as pEmpl, @pTM as pTM, @pPTT as pPTT
end

-- заполняем список выбранных сотрудников из параметра
select * into  #tEmply from [dbo].[uf_SplitArrayStrings] (@pEmpl)
-- заполняем список выбранных ТМ из параметра
select * into  #tTMy from [dbo].[uf_SplitArrayStrings] (@pTM)
-- заполняем список выбранных РТТ из параметра
select * into  #tPTTy from [dbo].[uf_SplitArrayStrings] (@pPTT)

-- ручная корректировка
if exists (select 1 from #tEmply where [String] = 'Иванова Александра')
begin
	insert into #tEmply values ('Иванова Александра1')
end
if exists (select 1 from #tEmply where [String] = 'Иванова Александра2')
begin
	insert into #tEmply values ('Иванова Александра3')
end
		
if exists (select 1 from #tEmply where [String] = 'Иванова Александра4')
begin
	insert into #tEmply values ('Иванова Александра5')
	insert into #tEmply values ('Иванова Александра6')
	insert into #tEmply values ('Иванова Александра7')
end

if exists(select 1 from #tTMy where [String] = '-1') or isnull(@pTM,'') = ''
begin
	set @allTM = 1
	delete from #tTMy 
-- все TM
	insert into #tTMy 
	select DirectoryID from [NodeBU].dbo.mn_directory where ClassID in (5211, 5212)	
end
-- интернет магазин
if exists (select 1 from #tPTTy where [String] = '32047437' ) set @im = 1

if exists(select 1 from #tPTTy where [String] = '-1') or isnull(@pPTT,'') = ''
begin
	set @allPTT = 1
	delete from #tPTTy 
-- все РТТ
	insert into #tPTTy 
	select ShopId from sb_config_node_all where isActive = 1

	if @im = 1 insert into #tPTTy values (32047437)
end

-- индексируем таблицы с фильтрами
create unique clustered index idx_tPTT on #tPTTy ([String])
create unique clustered index idx_tTM  on #tTMy  ([String])

if @pDebug = 1
begin
	select * from #tPTTy
	select * from #tTMy
end


-- формируем идеальный сток

select 
	a.SubjectID as РТТИд, 
	b.GoodID as ТоварИд, 
	b.Amount AS [ИС]
into #tISy
from          
	[NodeBU].dbo.gd_etalon_mx as a 
	inner join [NodeBU].dbo.gd_etalon_det as b ON a.ItemID = b.ItemID
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodId = b.GoodID and n.TMID = a.TMID
-- фильтры
	inner join #tTMy  as tm on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.SubjectID
where
	rtt.[String] <> 32047437
union all
select 
	32047437 as РТТИд, 
	b.GoodID as ТоварИд, 
	b.Amount AS [ИС]
from          
	[NodeBU].dbo.gd_etalon_det as b
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodId = b.GoodID
-- фильтры
	inner join #tTMy  as tm on tm.[String] = n.TMID
where
	@im = 1
	and b.ItemID in (32179199, 32203810)


-- формируем историю идеального стока
;with cteS
as
(
       select
             ItemId,
             GoodId,
             max(Id) as Id
       from
             [NodeBU].dbo.gd_etalon_det_history
       where
             [Date] <= @pDateS
			 and [Oper] <> 'D'
       group by
             ItemId,
             GoodId
)
,cteE
as
(
       select
             ItemId,
             GoodId,
             max(Id) as Id
       from
             [NodeBU].dbo.gd_etalon_det_history
       where
             [Date] <= @pDateE
			 and [Oper] <> 'D'
       group by
             ItemId,
             GoodId
)
select 
       a.SubjectID as РТТИд
       ,i1.GoodID as ТоварИд
       ,b1.Amount AS [ИС на начало периода]
       ,b2.Amount AS [ИС на конец периода]
into #tISyh

from          
	[NodeBU].dbo.gd_etalon_mx_history as a 
	inner join cteS as i1 ON i1.[ItemID] = a.ItemId
	inner join [NodeBU].dbo.[gd_good_v] as n1 on n1.GoodId = i1.GoodID and n1.TMID = a.TMID
	inner join [NodeBU].dbo.gd_etalon_det_history as b1 ON b1.ID = i1.Id
	inner join cteE as i2 ON i2.[ItemID] = i1.ItemId and i2.GoodID = i1.GoodID
	inner join [NodeBU].dbo.gd_etalon_det_history as b2 ON b2.ID = i2.Id
-- фильтры
	inner join #tTMy  as tm on tm.[String] = n1.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.SubjectID

----------------------------
-- формируем остатки
select
		a.РТТИд, 
--		a.СкладИд AS [СкладИд],
		n.GoodID as ТоварИд, 
		sum(Остаток) AS Остаток
into #tPry
from
(
	select 
		l.РТТИд, 
--		s.СкладИд AS [СкладИд],
		ТоварИд, 
		Остаток AS Остаток
	from 
		dim_pos_product_lots AS l WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.РТТИд = l.РТТИд AND s.СкладИд = l.СкладИд
	union all
	select 
		o.РТТИд, 
--		Получатель  AS [СкладИд],
		ТоварИд, 
		- Количество AS Остаток
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.РТТИд = o.РТТИд AND s.СкладИд = Получатель
	where
		Дата >= @pDate
	union all
	select 
		o.РТТИд, 
--		Отправитель  AS [СкладИд],
		ТоварИд, 
		Количество AS Остаток
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.РТТИд = o.РТТИд AND s.СкладИд = Отправитель
	where
		Дата >= @pDate
-- интернет магазин (только актуальные)
	union all
	select 
		32047437 as РТТИд, 
		gp.GoodId as ТоварИд, 
		o.Rest AS Остаток
		from
		(
		select 
			o.SubjectID, 
			o.PartyID, 
			sum(o.Amount) Rest 
		from [NodeBU].dbo.f_p_oper_rest_a(@pDate) o
		where o.SubjectID in (select ObjectID_Slave from [NodeBU].dbo.mn_object_agregation where ObjectID_Master = 32047437) 
		group by o.SubjectID, o.PartyID 
		) as o
		inner join [NodeBU].dbo.gd_good_party_a gp (nolock) on gp.PartyID=o.PartyID
	where
	@im = 1
	and o.Rest <> 0
) as a
-- фильтры
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = a.ТоварИд and n.ClassID = 3101	-- товар для продажи
	inner join #tTMy  as tm  on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.РТТИд
group by
		a.РТТИд, 
--		a.СкладИд AS [СкладИд],
		n.GoodID
having 
	sum(Остаток) <> 0
----------------------------



-- формируем продажи
select 
	a.РТТИд as РТТИд, 
	b.ПозицияИд as ТоварИд,
	SUM(b.ПозицияКоличество) as [Кол-во продаж]
into #tAs3My
from          
	[dbo].dim_pos_sales as a
	inner join [dbo].dim_pos_sales_detail as b on b.РТТИд = a.РТТИд and b.ДокументИд = a.ДокументИд
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = b.ПозицияИд and n.ClassID = 3101	-- товар для продажи
	
	inner join #tTMy  as tm  on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.РТТИд
where
	a.ДатаДокумента between @pDateS and @pDateE
group by
	a.РТТИд, 
	b.ПозицияИд

-- интернет магазин
union all
select  
	32047437 as РТТИд,
	o.GoodID as ТоварИд,
	SUM(o.Amount) as [Кол-во продаж]
from 
	[NodeBU].dbo.dc_oper_good_a o (nolock)
	inner join [NodeBU].dbo.dc_doc_good dg (nolock) on dg.DocGoodID=o.DocGoodID 
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = o.GoodID and n.ClassID = 3101	-- товар для продажи
	inner join #tTMy  as tm  on tm.[String] = n.TMID

where 
	o.SubjectID in (select ObjectID_Slave from [NodeBU].dbo.mn_object_agregation where ObjectID_Master in (32047446))  
	and dg.StateID = 44 
	and dg.TypeID <> 1 
	and dg.DateOD between @pDateS and @pDateE
	and dg.DocTemplateID = 32047541
	and @im = 1
group by o.GoodID

--delete from #tISy where [ИС] = 0
--delete from #tPry where [Остаток на начало] = 0
delete from #tAs3My where [Кол-во продаж] = 0


-- добавляем отсутствующие записи остатков в идеальный сток
insert into #tISy
select 
	РТТИд,
	ТоварИд,
	0 as [ИС]
from #tPry 
except
select 
	РТТИд,
	ТоварИд,
	0 as [ИС]
from #tISy

-- добавляем отсутствующие записи остатков в идеальный сток : история
insert into #tISyh
select 
	РТТИд,
	ТоварИд,
	0 as [ИС на начало периода],
	0 as [ИС на конец периода]

from #tPry 
except
select 
	РТТИд,
	ТоварИд,
	0 as [ИС на начало периода],
	0 as [ИС на конец периода]
from #tISyh


-- добавляем отсутствующие записи продаж в идеальный сток
insert into #tISy
select 
	РТТИд,
	ТоварИд,
	0 as [ИС]
from #tAs3My 
except
select 
	РТТИд,
	ТоварИд,
	0 as [ИС]
from #tISy

-- добавляем отсутствующие записи продаж в идеальный сток : история
insert into #tISyh
select 
	РТТИд,
	ТоварИд,
	0 as [ИС на начало периода],
	0 as [ИС на конец периода]
from #tAs3My 
except
select 
	РТТИд,
	ТоварИд,
	0 as [ИС на начало периода],
	0 as [ИС на конец периода]
from #tISyh


-- формируем поступления
SELECT
	idt.РТТИд AS РТТИд,
	idt.ПозицияИд AS ТоварИд,
	COUNT(DISTINCT idt.ДокументИд) as [Кол-во поступлений],
	SUM(idt.ПозицияКоличество) as [Кол-во поступившего товара]
INTO #tIncomy

FROM [dim_pos_product_income] i

JOIN [dim_pos_product_income_detail] idt
ON i.ДокументИд = idt.ДокументИд AND i.РТТИд = idt.РТТИд

inner join [NodeBU].dbo.[gd_good_v] AS n 
ON n.GoodID = idt.ПозицияИд and n.ClassID = 3101
	
inner join #tTMy  AS tm ON tm.[String] = n.TMID
inner join #tPTTy AS rtt ON rtt.[String] = idt.РТТИд

WHERE i.ДатаДокумента between @pDateS and @pDateE
GROUP BY idt.РТТИд, idt.ПозицияИд

-- Кол-во дней с нулевым остатком
;WITH Nul_CTE([РТТИд], [ТоварИд], [Name], [Дата], [Остаток])
AS
(
select
	a.РТТИд, 
	n.GoodID as [ТоварИд],
	n.[Name] as [Name],
	CAST(a.Дата AS DATE) as [Дата],
	SUM(a.Остаток) AS [Остаток]
from
(
	select 
		l.РТТИд, 
		l.ТоварИд,
		l.Дата,
		l.Остаток
	from 
		dim_pos_product_lots AS l WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.РТТИд = l.РТТИд AND s.СкладИд = l.СкладИд

	union all
	select 
		o.РТТИд, 
		o.ТоварИд,
		o.Дата, 
		- o.Количество AS Остаток
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.РТТИд = o.РТТИд AND s.СкладИд = Получатель
	where
		o.Дата >= @pDateS

	union all
	select 
		o.РТТИд, 
		o.ТоварИд,
		o.Дата, 
		o.Количество AS Остаток
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.РТТИд = o.РТТИд AND s.СкладИд = Отправитель
	where
		o.Дата >= @pDateS

) AS a
-- фильтры
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = a.ТоварИд and n.ClassID = 3101	-- товар для продажи
	inner join #tTMy  as tm on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.РТТИд
GROUP BY
		a.РТТИд, 
		n.GoodID,
		n.[Name],
		CAST(a.Дата AS DATE)
HAVING 
	SUM(a.Остаток) = 0
)
SELECT
	РТТИд,
	ТоварИд,
	COUNT(DISTINCT Дата) AS [Кол-во дней с нулевым остатком]
INTO #tNulResty

FROM Nul_CTE
GROUP BY РТТИд, ТоварИд

-- индексируем таблицы с данными
create clustered index idx_tISh   on #tISyh (РТТИд, ТоварИд)
create clustered index idx_tIS   on #tISy (РТТИд, ТоварИд)
create clustered index idx_tPr   on #tPry (РТТИд, ТоварИд)
create clustered index idx_tAs3M on #tAs3My (РТТИд, ТоварИд)
create clustered index idx_tIncom on #tIncomy (РТТИд, ТоварИд)
create clustered index idx_tNulResty on #tNulResty (РТТИд, ТоварИд)

/*
if @pDebug = 1
begin
	select @im
	select * from #tISyh
--	select * from #tPry
	select * from #tAs3My

	if object_id('tIS') is not null drop table tIS 
	select * into tIS from #tISyh
--	if object_id('tPr') is not null drop table tPr
--	select * into tPr from #tPry
	if object_id('tAs3M') is not null drop table tAs3M
	select * into tAs3M from #tAs3My
end
*/

-- итоговая выборка
select
	ih.РТТИд as РТТИд, 
	case
		when ih.РТТИд = 32047437 then '(*) Интернет-магазин'
		else s.Name 
	end as РТТ,
	n.TMID as ТМИд,
	m.Name as [Торговая марка],
-- товар
	n.[GoodID]  as ТоварИд, 
	n.[ArticulProducer] as [Артикул],
	n.[Weight]  as [Объем],
	n.[Name]    as [Товар],
	op203.Value	as [Штрихкод],
--*******************************************
-- поступления	
	inc.[Кол-во поступлений],
	inc.[Кол-во поступившего товара],

-- продажи
	s3.[Кол-во продаж],

-- кол-во дней с нулемвым остатком
	nr.[Кол-во дней с нулевым остатком],

-- история идеального стока
	ih.[ИС на начало периода],
	ih.[ИС на конец периода],

-- идеальный сток
	i.ИС as [ИС]

from
	#tISyh as ih
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = ih.ТоварИд and n.ClassID = 3101	-- товар для продажи
	inner join [NodeBU].dbo.mn_directory as m on m.DirectoryID = n.TMID and m.ClassID in (5211, 5212)
	inner join [NodeBU].dbo.mn_subject s (nolock) on s.SubjectID = ih.РТТИд
	inner join [NodeBU].dbo.cl_class_all_v c 
		on c.ClassId=s.ClassID and c.ClassID_Master = case when ih.РТТИд = 32047437 then 2112 else 2168 end

-- продажи
	inner join #tAs3My as s3 on s3.РТТИд = ih.РТТИд and s3.ТоварИд = ih.ТоварИд

-- поступления
	inner join #tIncomy as inc
	on inc.РТТИд = ih.РТТИд and inc.ТоварИд = ih.ТоварИд

-- кол-во дней с нулевым остатком
	inner join #tNulResty as nr
	on nr.РТТИд = ih.РТТИд and nr.ТоварИд = ih.ТоварИд

-- ИС эталонный
	left join #tISy as i 
	on ih.РТТИд = i.РТТИд and ih.ТоварИд = i.ТоварИд

-- штрихкод
	left outer join [NodeBU].dbo.mn_object_property op203 (nolock) ON op203.ObjectID=ih.ТоварИд and op203.PropertyID=203


if object_id('tempdb.dbo.#tEmply') is not null drop table #tEmply
if object_id('tempdb.dbo.#tTMy') is not null drop table #tTMy
if object_id('tempdb.dbo.#tSupy') is not null drop table #tSupy
if object_id('tempdb.dbo.#tISy') is not null drop table #tISy
if object_id('tempdb.dbo.#tISyh') is not null drop table #tISyh
if object_id('tempdb.dbo.#tPry') is not null drop table #tPry
if object_id('tempdb.dbo.#tPTTy') is not null drop table #tPTTy
if object_id('tempdb.dbo.#tAs3My') is not null drop table #tAs3My
if object_id('tempdb.dbo.#tIncomy') is not null drop table #tIncomy
if object_id('tempdb.dbo.#tNulResty') is not null drop table #tNulResty
end
GO