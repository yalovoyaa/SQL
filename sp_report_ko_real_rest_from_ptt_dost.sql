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

-- ������������� ����������
set @pDate = isnull(@pDate, cast(getdate() as date))
set @pDate = dateadd(second,-1, dateadd(day, 1, @pDate))

set @pDateS = isnull(@pDateS, cast(getdate() as date))
set @pDateS = dateadd(second,-1, dateadd(day, 1, @pDateS))

set @pDateE = isnull(@pDateE, cast(getdate() as date))
set @pDateE = dateadd(second,-1, dateadd(day, 1, @pDateE))


-- �������� �����
if object_id('tempdb.dbo.#tEmply') is not null drop table #tEmply
-- �������� �����
if object_id('tempdb.dbo.#tTMy') is not null drop table #tTMy
-- ����������
if object_id('tempdb.dbo.#tSupy') is not null drop table #tSupy
-- ��������� ����
if object_id('tempdb.dbo.#tISy') is not null drop table #tISy
-- ��������� ���� �������
if object_id('tempdb.dbo.#tISyh') is not null drop table #tISyh
-- �������
if object_id('tempdb.dbo.#tPry') is not null drop table #tPry
-- PTT
if object_id('tempdb.dbo.#tPTTy') is not null drop table #tPTTy
-- ������� �� 3-� ������ (�������)
if object_id('tempdb.dbo.#tAs3My') is not null drop table #tAs3My
-- �����������
if object_id('tempdb.dbo.#tIncomy') is not null drop table #tIncomy
-- ���-�� ���� � ������� ��������
if object_id('tempdb.dbo.#tNulResty') is not null drop table #tNulResty


if @pDebug = 1
begin
	select @pEmpl as pEmpl, @pTM as pTM, @pPTT as pPTT
end

-- ��������� ������ ��������� ����������� �� ���������
select * into  #tEmply from [dbo].[uf_SplitArrayStrings] (@pEmpl)
-- ��������� ������ ��������� �� �� ���������
select * into  #tTMy from [dbo].[uf_SplitArrayStrings] (@pTM)
-- ��������� ������ ��������� ��� �� ���������
select * into  #tPTTy from [dbo].[uf_SplitArrayStrings] (@pPTT)

-- ������ �������������
if exists (select 1 from #tEmply where [String] = '������� ����������')
begin
	insert into #tEmply values ('������� ����������1')
end
if exists (select 1 from #tEmply where [String] = '������� ����������2')
begin
	insert into #tEmply values ('������� ����������3')
end
		
if exists (select 1 from #tEmply where [String] = '������� ����������4')
begin
	insert into #tEmply values ('������� ����������5')
	insert into #tEmply values ('������� ����������6')
	insert into #tEmply values ('������� ����������7')
end

if exists(select 1 from #tTMy where [String] = '-1') or isnull(@pTM,'') = ''
begin
	set @allTM = 1
	delete from #tTMy 
-- ��� TM
	insert into #tTMy 
	select DirectoryID from [NodeBU].dbo.mn_directory where ClassID in (5211, 5212)	
end
-- �������� �������
if exists (select 1 from #tPTTy where [String] = '32047437' ) set @im = 1

if exists(select 1 from #tPTTy where [String] = '-1') or isnull(@pPTT,'') = ''
begin
	set @allPTT = 1
	delete from #tPTTy 
-- ��� ���
	insert into #tPTTy 
	select ShopId from sb_config_node_all where isActive = 1

	if @im = 1 insert into #tPTTy values (32047437)
end

-- ����������� ������� � ���������
create unique clustered index idx_tPTT on #tPTTy ([String])
create unique clustered index idx_tTM  on #tTMy  ([String])

if @pDebug = 1
begin
	select * from #tPTTy
	select * from #tTMy
end


-- ��������� ��������� ����

select 
	a.SubjectID as �����, 
	b.GoodID as �������, 
	b.Amount AS [��]
into #tISy
from          
	[NodeBU].dbo.gd_etalon_mx as a 
	inner join [NodeBU].dbo.gd_etalon_det as b ON a.ItemID = b.ItemID
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodId = b.GoodID and n.TMID = a.TMID
-- �������
	inner join #tTMy  as tm on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.SubjectID
where
	rtt.[String] <> 32047437
union all
select 
	32047437 as �����, 
	b.GoodID as �������, 
	b.Amount AS [��]
from          
	[NodeBU].dbo.gd_etalon_det as b
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodId = b.GoodID
-- �������
	inner join #tTMy  as tm on tm.[String] = n.TMID
where
	@im = 1
	and b.ItemID in (32179199, 32203810)


-- ��������� ������� ���������� �����
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
       a.SubjectID as �����
       ,i1.GoodID as �������
       ,b1.Amount AS [�� �� ������ �������]
       ,b2.Amount AS [�� �� ����� �������]
into #tISyh

from          
	[NodeBU].dbo.gd_etalon_mx_history as a 
	inner join cteS as i1 ON i1.[ItemID] = a.ItemId
	inner join [NodeBU].dbo.[gd_good_v] as n1 on n1.GoodId = i1.GoodID and n1.TMID = a.TMID
	inner join [NodeBU].dbo.gd_etalon_det_history as b1 ON b1.ID = i1.Id
	inner join cteE as i2 ON i2.[ItemID] = i1.ItemId and i2.GoodID = i1.GoodID
	inner join [NodeBU].dbo.gd_etalon_det_history as b2 ON b2.ID = i2.Id
-- �������
	inner join #tTMy  as tm on tm.[String] = n1.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.SubjectID

----------------------------
-- ��������� �������
select
		a.�����, 
--		a.������� AS [�������],
		n.GoodID as �������, 
		sum(�������) AS �������
into #tPry
from
(
	select 
		l.�����, 
--		s.������� AS [�������],
		�������, 
		������� AS �������
	from 
		dim_pos_product_lots AS l WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.����� = l.����� AND s.������� = l.�������
	union all
	select 
		o.�����, 
--		����������  AS [�������],
		�������, 
		- ���������� AS �������
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.����� = o.����� AND s.������� = ����������
	where
		���� >= @pDate
	union all
	select 
		o.�����, 
--		�����������  AS [�������],
		�������, 
		���������� AS �������
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.����� = o.����� AND s.������� = �����������
	where
		���� >= @pDate
-- �������� ������� (������ ����������)
	union all
	select 
		32047437 as �����, 
		gp.GoodId as �������, 
		o.Rest AS �������
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
-- �������
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = a.������� and n.ClassID = 3101	-- ����� ��� �������
	inner join #tTMy  as tm  on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.�����
group by
		a.�����, 
--		a.������� AS [�������],
		n.GoodID
having 
	sum(�������) <> 0
----------------------------



-- ��������� �������
select 
	a.����� as �����, 
	b.��������� as �������,
	SUM(b.�����������������) as [���-�� ������]
into #tAs3My
from          
	[dbo].dim_pos_sales as a
	inner join [dbo].dim_pos_sales_detail as b on b.����� = a.����� and b.���������� = a.����������
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = b.��������� and n.ClassID = 3101	-- ����� ��� �������
	
	inner join #tTMy  as tm  on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.�����
where
	a.������������� between @pDateS and @pDateE
group by
	a.�����, 
	b.���������

-- �������� �������
union all
select  
	32047437 as �����,
	o.GoodID as �������,
	SUM(o.Amount) as [���-�� ������]
from 
	[NodeBU].dbo.dc_oper_good_a o (nolock)
	inner join [NodeBU].dbo.dc_doc_good dg (nolock) on dg.DocGoodID=o.DocGoodID 
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = o.GoodID and n.ClassID = 3101	-- ����� ��� �������
	inner join #tTMy  as tm  on tm.[String] = n.TMID

where 
	o.SubjectID in (select ObjectID_Slave from [NodeBU].dbo.mn_object_agregation where ObjectID_Master in (32047446))  
	and dg.StateID = 44 
	and dg.TypeID <> 1 
	and dg.DateOD between @pDateS and @pDateE
	and dg.DocTemplateID = 32047541
	and @im = 1
group by o.GoodID

--delete from #tISy where [��] = 0
--delete from #tPry where [������� �� ������] = 0
delete from #tAs3My where [���-�� ������] = 0


-- ��������� ������������� ������ �������� � ��������� ����
insert into #tISy
select 
	�����,
	�������,
	0 as [��]
from #tPry 
except
select 
	�����,
	�������,
	0 as [��]
from #tISy

-- ��������� ������������� ������ �������� � ��������� ���� : �������
insert into #tISyh
select 
	�����,
	�������,
	0 as [�� �� ������ �������],
	0 as [�� �� ����� �������]

from #tPry 
except
select 
	�����,
	�������,
	0 as [�� �� ������ �������],
	0 as [�� �� ����� �������]
from #tISyh


-- ��������� ������������� ������ ������ � ��������� ����
insert into #tISy
select 
	�����,
	�������,
	0 as [��]
from #tAs3My 
except
select 
	�����,
	�������,
	0 as [��]
from #tISy

-- ��������� ������������� ������ ������ � ��������� ���� : �������
insert into #tISyh
select 
	�����,
	�������,
	0 as [�� �� ������ �������],
	0 as [�� �� ����� �������]
from #tAs3My 
except
select 
	�����,
	�������,
	0 as [�� �� ������ �������],
	0 as [�� �� ����� �������]
from #tISyh


-- ��������� �����������
SELECT
	idt.����� AS �����,
	idt.��������� AS �������,
	COUNT(DISTINCT idt.����������) as [���-�� �����������],
	SUM(idt.�����������������) as [���-�� ������������ ������]
INTO #tIncomy

FROM [dim_pos_product_income] i

JOIN [dim_pos_product_income_detail] idt
ON i.���������� = idt.���������� AND i.����� = idt.�����

inner join [NodeBU].dbo.[gd_good_v] AS n 
ON n.GoodID = idt.��������� and n.ClassID = 3101
	
inner join #tTMy  AS tm ON tm.[String] = n.TMID
inner join #tPTTy AS rtt ON rtt.[String] = idt.�����

WHERE i.������������� between @pDateS and @pDateE
GROUP BY idt.�����, idt.���������

-- ���-�� ���� � ������� ��������
;WITH Nul_CTE([�����], [�������], [Name], [����], [�������])
AS
(
select
	a.�����, 
	n.GoodID as [�������],
	n.[Name] as [Name],
	CAST(a.���� AS DATE) as [����],
	SUM(a.�������) AS [�������]
from
(
	select 
		l.�����, 
		l.�������,
		l.����,
		l.�������
	from 
		dim_pos_product_lots AS l WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.����� = l.����� AND s.������� = l.�������

	union all
	select 
		o.�����, 
		o.�������,
		o.����, 
		- o.���������� AS �������
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.����� = o.����� AND s.������� = ����������
	where
		o.���� >= @pDateS

	union all
	select 
		o.�����, 
		o.�������,
		o.����, 
		o.���������� AS �������
	from
		dim_pos_product_oper AS o WITH (NOLOCK)
		INNER JOIN dim_pos_store AS s ON s.����� = o.����� AND s.������� = �����������
	where
		o.���� >= @pDateS

) AS a
-- �������
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = a.������� and n.ClassID = 3101	-- ����� ��� �������
	inner join #tTMy  as tm on tm.[String] = n.TMID
	inner join #tPTTy as rtt on rtt.[String] = a.�����
GROUP BY
		a.�����, 
		n.GoodID,
		n.[Name],
		CAST(a.���� AS DATE)
HAVING 
	SUM(a.�������) = 0
)
SELECT
	�����,
	�������,
	COUNT(DISTINCT ����) AS [���-�� ���� � ������� ��������]
INTO #tNulResty

FROM Nul_CTE
GROUP BY �����, �������

-- ����������� ������� � �������
create clustered index idx_tISh   on #tISyh (�����, �������)
create clustered index idx_tIS   on #tISy (�����, �������)
create clustered index idx_tPr   on #tPry (�����, �������)
create clustered index idx_tAs3M on #tAs3My (�����, �������)
create clustered index idx_tIncom on #tIncomy (�����, �������)
create clustered index idx_tNulResty on #tNulResty (�����, �������)

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

-- �������� �������
select
	ih.����� as �����, 
	case
		when ih.����� = 32047437 then '(*) ��������-�������'
		else s.Name 
	end as ���,
	n.TMID as ����,
	m.Name as [�������� �����],
-- �����
	n.[GoodID]  as �������, 
	n.[ArticulProducer] as [�������],
	n.[Weight]  as [�����],
	n.[Name]    as [�����],
	op203.Value	as [��������],
--*******************************************
-- �����������	
	inc.[���-�� �����������],
	inc.[���-�� ������������ ������],

-- �������
	s3.[���-�� ������],

-- ���-�� ���� � �������� ��������
	nr.[���-�� ���� � ������� ��������],

-- ������� ���������� �����
	ih.[�� �� ������ �������],
	ih.[�� �� ����� �������],

-- ��������� ����
	i.�� as [��]

from
	#tISyh as ih
	inner join [NodeBU].dbo.[gd_good_v] as n on n.GoodID = ih.������� and n.ClassID = 3101	-- ����� ��� �������
	inner join [NodeBU].dbo.mn_directory as m on m.DirectoryID = n.TMID and m.ClassID in (5211, 5212)
	inner join [NodeBU].dbo.mn_subject s (nolock) on s.SubjectID = ih.�����
	inner join [NodeBU].dbo.cl_class_all_v c 
		on c.ClassId=s.ClassID and c.ClassID_Master = case when ih.����� = 32047437 then 2112 else 2168 end

-- �������
	inner join #tAs3My as s3 on s3.����� = ih.����� and s3.������� = ih.�������

-- �����������
	inner join #tIncomy as inc
	on inc.����� = ih.����� and inc.������� = ih.�������

-- ���-�� ���� � ������� ��������
	inner join #tNulResty as nr
	on nr.����� = ih.����� and nr.������� = ih.�������

-- �� ���������
	left join #tISy as i 
	on ih.����� = i.����� and ih.������� = i.�������

-- ��������
	left outer join [NodeBU].dbo.mn_object_property op203 (nolock) ON op203.ObjectID=ih.������� and op203.PropertyID=203


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