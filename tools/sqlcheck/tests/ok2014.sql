-- 測試用：這些全部是 SQL Server 2014 可用的語法，檢查工具不該報錯
USE learning_db;
GO

SELECT ProductName, LTRIM(RTRIM(ProductName)) AS 去空白,
	   IIF(UnitPrice > 300, N'高價', N'一般') AS 等級,
	   CONVERT(NVARCHAR(10), GETDATE(), 120) AS 日期,
	   FORMAT(UnitPrice, 'N2') AS 格式化
FROM dbo.Products;
GO

SELECT * FROM dbo.Products WHERE ProductName LIKE N'%茶%' ESCAPE '\';
GO

WITH 客戶訂單 AS (
	SELECT c.CustomerID, c.CompanyName, COUNT(o.OrderID) AS 訂單數
	FROM dbo.Customers AS c
	LEFT JOIN dbo.Orders AS o ON o.CustomerID = c.CustomerID
	GROUP BY c.CustomerID, c.CompanyName
)
SELECT CompanyName, 訂單數
FROM 客戶訂單
ORDER BY 訂單數 DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
GO

SELECT EmployeeID, MONTH(OrderDate) AS 月份, SUM(ShipFee) AS 金額,
	   LAG(SUM(ShipFee)) OVER (PARTITION BY EmployeeID ORDER BY MONTH(OrderDate)) AS 上月
FROM dbo.Orders
GROUP BY EmployeeID, MONTH(OrderDate);
GO

DECLARE @sum TABLE (id INT PRIMARY KEY, amount DECIMAL(10,2));
INSERT INTO @sum (id, amount) VALUES (1, 100.00);
SELECT * FROM @sum;
GO

BEGIN TRY
	SELECT 1 / 0;
END TRY
BEGIN CATCH
	THROW;
END CATCH;
GO

MERGE dbo.Products AS target
USING (SELECT ProductID, UnitPrice FROM dbo.Products WHERE ProductID = 1) AS source
	ON target.ProductID = source.ProductID
WHEN MATCHED THEN UPDATE SET target.UnitPrice = source.UnitPrice;
GO
