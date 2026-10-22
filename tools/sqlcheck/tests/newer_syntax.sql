-- 測試用：故意混入 SQL Server 2016+ 才有的語法，檢查工具必須全部抓出來
-- 這份檔案「不該」被修正成 2014 語法，它是 tools/test.sh 的預期失敗案例。
USE learning_db;
GO

DROP TABLE IF EXISTS dbo.Products;
GO

CREATE OR ALTER VIEW dbo.v AS SELECT 1 AS x;
GO

SELECT STRING_AGG(ProductName, N'、') WITHIN GROUP (ORDER BY ProductName) AS 產品
FROM dbo.Products;
GO

SELECT ProductName, TRIM(ProductName) AS 去空白
FROM dbo.Products
FOR JSON PATH;
GO

SELECT ProductName FROM dbo.Products
WHERE ProductID IN (SELECT value FROM STRING_SPLIT(N'1,2,3', N','));
GO

SELECT 1 AS x WHERE 1 IS DISTINCT FROM 2;
GO

SELECT DATETRUNC(month, GETDATE()) AS 月初;
GO
