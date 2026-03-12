--4.	Criar uma procedure que atualizada as tabelas Dimensões e Fato.
CREATE PROCEDURE [dbo].[STP_Carga_DataWarehouse]
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1;
    SET LANGUAGE Portuguese;

SET DATEFIRST 1;
SET LANGUAGE Portuguese;


--2.	Criar tabelas dimensões com base na tabela [histCasosTrabalhados] criada anteriormente no SQL.
--2.a.	Tabela [dimCalendario] com base na coluna [Data_Hora_Criação].
DROP TABLE IF EXISTS [BD].[dbo].[dimCalendario]
SELECT DISTINCT
	CAST(Data_Hora_Criação AS DATE) AS DATE,
	YEAR(Data_Hora_Criação) AS ANO,
	MONTH(Data_Hora_Criação) AS MES,
	YEAR(Data_Hora_Criação)*100+MONTH(Data_Hora_Criação) AS ANOMES, --> PREFIRO USAR ESSA OPERAÇÃO PARA ANOMES POIS É MAIS RÁPIDA EM GRANDES VOLUMES DE DADOS
	DATENAME(MONTH,Data_Hora_Criação) AS MES_NOM,
	CONCAT(YEAR(Data_Hora_Criação),LEFT(DATENAME(MONTH,Data_Hora_Criação),3)) AS [ANO/MES],
	DATENAME(WEEKDAY,Data_Hora_Criação) AS NOM_DIA_SEMANA,
	DATEPART(WEEKDAY, [Data_Hora_Criação]) AS NUM_DIA_SEMANA,
	DATEPART(QUARTER, [Data_Hora_Criação]) AS TRIMESTRE,
	DATEPART(WEEK, [Data_Hora_Criação]) AS SEMANA_ANO
INTO [BD].[dbo].[dimCalendario]
FROM [BD].[dbo].[histCasosTrabalhados]

--2.b.	Tabela [dimFuncionario] com base na coluna [NomeAgen].
DROP TABLE IF EXISTS [BD].[dbo].[dimFuncionario];
WITH NOMES AS (
SELECT DISTINCT
	NomeAgen
FROM [BD].[dbo].[histCasosTrabalhados])
SELECT 
	ROW_NUMBER() OVER (ORDER BY (SELECT NomeAgen)) AS ID_FUNC,
	NomeAgen AS NOME_COMPLETO,
	LEFT(NomeAgen,CHARINDEX(' ',NomeAgen)-1) AS PRIMEIRO_NOME,
	REVERSE(LEFT(REVERSE(NomeAgen),CHARINDEX(' ',REVERSE(NomeAgen))-1)) AS ULTIMO_NOME
INTO [BD].[dbo].[dimFuncionario]
FROM NOMES

DROP TABLE IF EXISTS #NOMES_FUNC

--2.c.	Tabela [dimSupervisor] com base na coluna [NomeSupe].
DROP TABLE IF EXISTS [BD].[dbo].[dimSupervisor];
WITH NOMES AS (
SELECT DISTINCT
	NomeSupe
FROM [BD].[dbo].[histCasosTrabalhados])
SELECT 
	ROW_NUMBER() OVER (ORDER BY (SELECT NomeSupe)) AS ID_SUP,
	NomeSupe AS NOME_COMPLETO,
	LEFT(NomeSupe,CHARINDEX(' ',NomeSupe)-1) AS PRIMEIRO_NOME,
	REVERSE(LEFT(REVERSE(NomeSupe),CHARINDEX(' ',REVERSE(NomeSupe))-1)) AS ULTIMO_NOME
INTO [BD].[dbo].[dimSupervisor]
FROM NOMES

--2.d.	Tabela [dimMotiChamador] com base na coluna [Motivo_Chamador].
DROP TABLE IF EXISTS [BD].[DBO].[dimMotiChamador];
WITH MOTIVOS AS (
	SELECT DISTINCT
	Motivo_Chamador
FROM [BD].[dbo].[histCasosTrabalhados])
SELECT 
	ROW_NUMBER() OVER (ORDER BY (SELECT Motivo_Chamador)) AS ID_MOT_CHAM,
	Motivo_Chamador,
	CASE WHEN LEFT(Motivo_Chamador,2) = 'Ad' THEN 'Anúncios'
		 WHEN Motivo_Chamador LIKE '%Facebook%' THEN 'Facebook'
		 WHEN Motivo_Chamador LIKE '%FB%' THEN 'Facebook'
		 WHEN Motivo_Chamador LIKE '%Instagram%' THEN 'Instagram'
		 WHEN Motivo_Chamador LIKE '%Pay%' THEN 'Payments/Payouts'
		 WHEN Motivo_Chamador LIKE '%Ad%' THEN 'Anúncios'
		 WHEN Motivo_Chamador LIKE '%Ads%' THEN 'Anúncios'
		 WHEN Motivo_Chamador LIKE '%Business%' THEN 'Business'
		 WHEN Motivo_Chamador LIKE '%Pages%' THEN 'Pages'
		 ELSE 'Outros'
	END AS CATEGORIA
INTO [BD].[DBO].[dimMotiChamador]
FROM MOTIVOS
ORDER BY Motivo_Chamador

--SELECT
--COUNT(*) AS QTD,
--CATEGORIA
--FROM [BD].[dbo].[histCasosTrabalhados] AS A
--LEFT JOIN BD.DBO.dimMotiChamador AS B
--ON A.Motivo_Chamador = B.Motivo_Chamador
--GROUP BY CATEGORIA
--ORDER BY QTD DESC


--2.e.	Tabela [dimStatus] com base na coluna [Status].
DROP TABLE IF EXISTS [BD].[DBO].[dimStatus];
SELECT DISTINCT
	CASE WHEN Status = 'New' THEN 1
		 WHEN Status = 'Working' THEN 2
		 WHEN Status = 'Escalated' THEN 3
		 WHEN Status = 'Pending Response' THEN 4
		 WHEN Status = 'Response Received' THEN 5
		 WHEN Status = 'Done' THEN 6
	 ELSE 0
	 END AS ID_STATUS,
	STATUS
INTO [BD].[DBO].[dimStatus]
FROM [BD].[dbo].[histCasosTrabalhados]

--2.f.	Tabela [dimCanalEntrada] com base na coluna [Canal_Entrada].
DROP TABLE IF EXISTS [BD].[dbo].[dimCanalEntrada]
SELECT DISTINCT 
Canal_Entrada,
CASE WHEN Canal_Entrada = 'CHAT' THEN 1 
	 WHEN Canal_Entrada = 'EMAIL' THEN 2
	 ELSE 0
END AS ID_CANAL
INTO [BD].[dbo].[dimCanalEntrada]
FROM [BD].[dbo].[histCasosTrabalhados]

--2.g.	Tabela [dimPais] com base na coluna [País].
DROP TABLE IF EXISTS [BD].[dbo].[dimPais];
WITH PAISES AS(
SELECT DISTINCT 
	País
FROM [BD].[dbo].[histCasosTrabalhados]
WHERE País IS NOT NULL)
SELECT DISTINCT 
	País,
	ROW_NUMBER() OVER (ORDER BY (SELECT País)) AS ID_PAIS
INTO [BD].[dbo].[dimPais]
FROM PAISES
--3.	Criar tabela fato no SQL Server com base na [histCasosTrabalhados], a mesma deve conter os campos identificadores das dimensões criadas anteriormente e os campos necessários para calcular os indicadores abaixo:
DROP TABLE IF EXISTS [BD].[dbo].[FatoCasosTrabalhados]
SELECT 
	COUNT(Id_Caso) AS QTD_CASOS,
	ID_CANAL,
	ID_STATUS,
	CASE WHEN Resolução IS NULL 
		 THEN (CASE WHEN id_status = 6 THEN '1' ELSE '0' END)  
		  ELSE Resolução
	END AS Resolução,
	ID_MOT_CHAM,
	CATEGORIA AS CAT_MOT_CHAM,
	ID_FUNC,
	ID_SUP,
	Data_Hora_Criação,
	Data_Hora_Atualização,
	Data_Hora_Fechamento ,
	ID_PAIS	
INTO [BD].[dbo].[FatoCasosTrabalhados]
FROM [BD].[dbo].[histCasosTrabalhados] AS A
LEFT JOIN [BD].[dbo].dimCalendario AS B
	ON A.Data_Hora_Criação = B.DATE
LEFT JOIN [BD].[dbo].dimCanalEntrada AS C
	ON A.Canal_Entrada = C.Canal_Entrada
LEFT JOIN [BD].[dbo].dimFuncionario AS D
	ON A.NomeAgen = D.NOME_COMPLETO
LEFT JOIN [BD].[dbo].dimMotiChamador AS E
	ON A.Motivo_Chamador = E.Motivo_Chamador
LEFT JOIN [BD].[dbo].dimPais AS F
	ON A.País = F.País
LEFT JOIN [BD].[dbo].dimSupervisor AS G
	ON A.NomeSupe = G.NOME_COMPLETO
LEFT JOIN [BD].[dbo].dimStatus AS H
	ON A.Status = H.Status
GROUP BY ID_CANAL,	ID_STATUS,	ID_MOT_CHAM,	CATEGORIA,	ID_FUNC,	ID_SUP,	Data_Hora_Criação,	Data_Hora_Atualização,	Data_Hora_Fechamento ,	ID_PAIS,	
	     CASE WHEN Resolução IS NULL THEN (CASE WHEN id_status = 6 THEN '1' ELSE '0' END) ELSE Resolução END
END