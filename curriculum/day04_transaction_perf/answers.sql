-- ============================================================
-- Day 4 參考答案與解說
-- 建議：自己做完再看；交易與索引題請務必確認結尾有 ROLLBACK
--
-- ⚠️ 本檔需要修改資料或建立索引的題目都包在交易中，結尾一律 ROLLBACK。
--    正常執行完不會留下資料變更或索引；若中途 COMMIT 或連線中斷，
--    重新執行 common/seed.sql 即可還原 learning_db。
-- ============================================================

USE learning_db;
GO

-- 1. 最基本的交易：修改客戶 11 的電話再回滾
BEGIN TRANSACTION;

SELECT CustomerID, CompanyName, Phone
FROM dbo.Customers
WHERE CustomerID = 11;

UPDATE dbo.Customers
SET Phone = N'02-1111-2222'
WHERE CustomerID = 11;

SELECT CustomerID, CompanyName, Phone
FROM dbo.Customers
WHERE CustomerID = 11;

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

SELECT CustomerID, CompanyName, Phone
FROM dbo.Customers
WHERE CustomerID = 11;
GO
-- 預期：修改前 Phone 是 NULL（新竹生技），交易內變成 02-1111-2222，
--       ROLLBACK 後又回到 NULL。
-- 若最後一次查詢還是 02-1111-2222，代表你不小心 COMMIT 了。

-- 2. TRY/CATCH 與外鍵錯誤
SET XACT_ABORT ON;

BEGIN TRY
	BEGIN TRANSACTION;

	INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipFee)
	VALUES (999, 1, CAST('2014-06-01' AS DATE), 50.00);

	COMMIT TRANSACTION;
END TRY
BEGIN CATCH
	IF XACT_STATE() <> 0
		ROLLBACK TRANSACTION;

	SELECT
		ERROR_NUMBER() AS 錯誤編號,
		ERROR_MESSAGE() AS 錯誤訊息;
END CATCH;

SET XACT_ABORT OFF;

SELECT COUNT(*) AS 測試訂單數
FROM dbo.Orders
WHERE CustomerID = 999;
GO
-- 預期：錯誤編號 547（FOREIGN KEY constraint），測試訂單數 0。
-- 外鍵錯誤是執行期錯誤，不會被 DacFx／離線檢查抓到，只能靠實際執行或測試。

-- 3. SAVE TRANSACTION：只回滾第二個更新
BEGIN TRANSACTION;

UPDATE dbo.Products
SET UnitPrice = UnitPrice + 10
WHERE ProductID = 1;

SAVE TRANSACTION AfterFirst;

UPDATE dbo.Products
SET UnitPrice = UnitPrice + 10
WHERE ProductID = 2;

ROLLBACK TRANSACTION AfterFirst;

SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products
WHERE ProductID IN (1, 2)
ORDER BY ProductID;

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：ProductID 1 從 350 變成 360；ProductID 2 仍是 45（第二個更新被取消）。
-- 最後的 ROLLBACK 讓兩個產品都回到原價。
-- SAVE TRANSACTION 不會改變 @@TRANCOUNT；ROLLBACK 到保存點後交易仍然存在。

-- 4. 建立索引並比較 IO／執行計畫
BEGIN TRANSACTION;
GO

CREATE INDEX IX_OrderDetails_ProductID
ON dbo.OrderDetails (ProductID)
INCLUDE (Quantity, UnitPrice);
GO

SET STATISTICS IO ON;
GO

-- 一般查詢：最佳化工具自己決定要不要用索引
SELECT OrderDetailID, OrderID, ProductID, Quantity, UnitPrice
FROM dbo.OrderDetails
WHERE ProductID = 7;
GO

-- 強制使用剛建立的索引，觀察 Index Seek 與 logical reads
SELECT OrderDetailID, OrderID, ProductID, Quantity, UnitPrice
FROM dbo.OrderDetails WITH (INDEX(IX_OrderDetails_ProductID))
WHERE ProductID = 7;
GO

SET STATISTICS IO OFF;
GO

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：2 筆（OrderDetailID 6：20 個、單價 12；OrderDetailID 18：30 個、單價 13）。
-- 資料只有 27 筆，最佳化工具可能對一般查詢仍選 Clustered Index Scan
--（全表掃描比 seek + key lookup 便宜）； forced index 查詢則會看到 Index Seek。
-- 本機實測：一般查詢 logical reads 2，強制索引反而 6（seek 後還要回表拿其他欄位）。
-- 重點是學會看 logical reads 與計畫，而不是期待小資料表有巨大差異。

-- 5. SARGable：YEAR() vs 範圍條件
BEGIN TRANSACTION;
GO

CREATE INDEX IX_Orders_OrderDate
ON dbo.Orders (OrderDate);
GO

SET STATISTICS IO ON;
GO

-- 查詢 A：欄位被 YEAR() 包住，通常無法用索引 seek
SELECT COUNT(*) AS 訂單數
FROM dbo.Orders
WHERE YEAR(OrderDate) = 2014;
GO

-- 查詢 B：範圍條件，較有機會用 Index Seek
SELECT COUNT(*) AS 訂單數
FROM dbo.Orders
WHERE OrderDate >= CAST('2014-01-01' AS DATE)
	AND OrderDate < CAST('2015-01-01' AS DATE);
GO

SET STATISTICS IO OFF;
GO

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：兩個查詢都是 16 筆。
-- 資料量太小，logical reads 可能一樣（本機實測兩者都是 2）；把資料量放大或看執行計畫，
-- 就會看到 YEAR() 造成 scan、範圍條件可以用 OrderDate 索引 seek。
-- 規則：不要把欄位包在函數或運算裡。

-- 6. 用變數查產品
DECLARE @Category NVARCHAR(50) = N'電子';
DECLARE @MinPrice DECIMAL(10,2) = 300.00;

SELECT ProductName, UnitPrice
FROM dbo.Products
WHERE Category = @Category
	AND UnitPrice >= @MinPrice
ORDER BY UnitPrice DESC;
GO
-- 預期：進口耳機 1200.00、鍵盤 480.00（ORDER BY 單價 DESC）
-- 滑鼠 250 低於 300，所以不出現。

-- 7. IF/ELSE 分級
DECLARE @Total DECIMAL(12,2);

SELECT @Total = COALESCE(SUM(d.Quantity * d.UnitPrice), 0)
FROM dbo.Orders AS o
INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
WHERE o.CustomerID = 1;

IF @Total >= 4000
	SELECT N'VIP' AS 等級, @Total AS 總金額;
ELSE IF @Total >= 2000
	SELECT N'重要客戶' AS 等級, @Total AS 總金額;
ELSE
	SELECT N'一般客戶' AS 等級, @Total AS 總金額;
GO
-- 預期：VIP，4380.00
-- 客戶 1 的四張訂單金額：940 + 1090 + 580 + 1770 = 4380。

-- 8. WHILE 計算 1 到 100
DECLARE @i INT = 1;
DECLARE @sum INT = 0;

WHILE @i <= 100
BEGIN
	SET @sum = @sum + @i;
	SET @i = @i + 1;
END;

SELECT @sum AS 總和;
GO
-- 預期：5050
-- 實務上能用集合式寫法就不要用迴圈；這題只是練語法。

-- 9. 預存程序與 OUTPUT 參數
BEGIN TRANSACTION;
GO

CREATE PROCEDURE dbo.usp_GetCustomerStats
	@CustomerID INT,
	@OrderCount INT OUTPUT,
	@Total DECIMAL(12,2) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		@OrderCount = COUNT(DISTINCT o.OrderID),
		@Total = COALESCE(SUM(d.Quantity * d.UnitPrice), 0)
	FROM dbo.Orders AS o
	LEFT JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.CustomerID = @CustomerID;
END;
GO

DECLARE @count INT;
DECLARE @total DECIMAL(12,2);

EXEC dbo.usp_GetCustomerStats
	@CustomerID = 1,
	@OrderCount = @count OUTPUT,
	@Total = @total OUTPUT;

SELECT @count AS 訂單數, @total AS 總金額;
GO

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：訂單數 4、總金額 4380.00
-- 預存程序是在交易內建立的，ROLLBACK 後會消失；這也示範了 DDL 可以包在交易裡。
-- SQL Server 2014 沒有 CREATE OR ALTER；實務上可先 DROP 再 CREATE，或用 ALTER PROCEDURE。

-- 10. 動態 SQL：參數化 vs 字串拼接
DECLARE @Category NVARCHAR(50) = N'電子';
DECLARE @sql NVARCHAR(MAX) = N'
	SELECT ProductName, UnitPrice
	FROM dbo.Products
	WHERE Category = @Category
	ORDER BY UnitPrice DESC;';

EXEC sys.sp_executesql
	@sql,
	N'@Category NVARCHAR(50)',
	@Category = @Category;
GO

DECLARE @Category NVARCHAR(50) = N'電子'' OR 1=1 --';
DECLARE @sql NVARCHAR(MAX) = N'
	SELECT ProductName, UnitPrice
	FROM dbo.Products
	WHERE Category = @Category
	ORDER BY UnitPrice DESC;';

EXEC sys.sp_executesql
	@sql,
	N'@Category NVARCHAR(50)',
	@Category = @Category;
GO
-- 預期：第一次 3 筆（進口耳機 1200.00、鍵盤 480.00、滑鼠 250.00，依單價 DESC）；
--       第二次 0 筆。
-- 第二次的 @Category 是一個完整的字串值，不是 SQL 片段；
-- 參數化讓 OR 1=1 失效，這就是防 SQL injection 的核心。
-- 若把 @Category 直接串進 @sql，第二次就會變成查全部。

-- 11. CASE 分級
WITH CustomerTotals AS (
	SELECT
		c.CustomerID,
		c.CompanyName,
		COALESCE(SUM(d.Quantity * d.UnitPrice), 0) AS 總金額
	FROM dbo.Customers AS c
	LEFT JOIN dbo.Orders AS o ON c.CustomerID = o.CustomerID
	LEFT JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	GROUP BY c.CustomerID, c.CompanyName
)
SELECT
	CompanyName,
	總金額,
	CASE
		WHEN 總金額 >= 4000 THEN N'VIP'
		WHEN 總金額 >= 2000 THEN N'重要'
		WHEN 總金額 > 0 THEN N'一般'
		ELSE N'新客'
	END AS 等級
FROM CustomerTotals
ORDER BY 總金額 DESC;
GO
-- 預期：
--   VIP：阿里巴巴貿易 4380.00
--   重要：飛鷹物流 2890.00、星河電子 2060.00
--   一般：大同工廠 1850.00、藍鵡食品 1464.00、貝塔科技 1070.00、
--         台中機械 880.00、台北咖啡坊 750.00、晨光文具 570.00、高雄五金 375.00
--   新客：新竹生技 0.00、高雄運通 0.00
-- CASE 不能在同一個 SELECT 直接引用「總金額」別名，所以先包一層 CTE。

-- 12.（挑戰）交易 + TRY/CATCH：失敗回滾，成功後再回滾
SET XACT_ABORT ON;

BEGIN TRY
	BEGIN TRANSACTION;

	INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipFee)
	VALUES (1, 1, CAST('2014-06-15' AS DATE), 50.00);

	DECLARE @OrderID INT = SCOPE_IDENTITY();

	-- 故意用不存在的 ProductID，觸發外鍵錯誤 547
	INSERT INTO dbo.OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
	VALUES (@OrderID, 999, 1, 100.00);

	COMMIT TRANSACTION;
END TRY
BEGIN CATCH
	IF XACT_STATE() <> 0
		ROLLBACK TRANSACTION;

	SELECT
		ERROR_NUMBER() AS 錯誤編號,
		ERROR_MESSAGE() AS 錯誤訊息;
END CATCH;

SELECT COUNT(*) AS 失敗交易留下的訂單
FROM dbo.Orders
WHERE OrderDate = CAST('2014-06-15' AS DATE);
GO

BEGIN TRY
	BEGIN TRANSACTION;

	INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipFee)
	VALUES (1, 1, CAST('2014-06-15' AS DATE), 50.00);

	DECLARE @OrderID2 INT = SCOPE_IDENTITY();

	INSERT INTO dbo.OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
	VALUES (@OrderID2, 1, 2, 350.00);

	SELECT
		o.OrderID,
		o.CustomerID,
		o.OrderDate,
		d.ProductID,
		d.Quantity,
		d.UnitPrice
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.OrderID = @OrderID2;

	ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
	IF XACT_STATE() <> 0
		ROLLBACK TRANSACTION;

	SELECT
		ERROR_NUMBER() AS 錯誤編號,
		ERROR_MESSAGE() AS 錯誤訊息;
END CATCH;

SET XACT_ABORT OFF;
GO
-- 預期：
--   第一次 CATCH 顯示 547，失敗交易留下的訂單 0 筆；
--   第二次 SELECT 顯示 1 筆訂單與 1 筆明細，然後 ROLLBACK（資料不變）。
-- 重點：交易不是「有 BEGIN 就好」，例外時一定要確認 XACT_STATE() 並回滾。
