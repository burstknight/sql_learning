-- ============================================================
-- Day 3 參考答案與解說
-- 建議：自己做完再看；看不懂的 SQL 貼回 sqlcmd 逐步實驗
--
-- ⚠️ 第 10 題以後會執行 DML。每題都在交易中，結尾一律 ROLLBACK，
--    正常執行完不會留下資料變更；若中途自行 COMMIT 或連線中斷，
--    重新執行 common/seed.sql 即可還原 learning_db。
-- ============================================================

USE learning_db;
GO

-- 1. 單價高於全體平均的產品
SELECT ProductName, UnitPrice
FROM dbo.Products
WHERE UnitPrice > (
	SELECT AVG(UnitPrice)
	FROM dbo.Products
)
ORDER BY UnitPrice DESC;
GO
-- 預期：進口耳機 1200.00、印表機耗材 890.00、鍵盤 480.00、鐵觀音茶葉 350.00
-- 全體平均是 313.75；純量子查詢只能回傳 1 列 1 欄。

-- 2. 買過電子類產品的客戶
SELECT c.CompanyName
FROM dbo.Customers AS c
WHERE c.CustomerID IN (
	SELECT o.CustomerID
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	INNER JOIN dbo.Products AS p ON d.ProductID = p.ProductID
	WHERE p.Category = N'電子'
)
ORDER BY c.CustomerID;
GO
-- 預期：3 家——貝塔科技、飛鷹物流、星河電子
-- IN 子查詢等於一連串 OR；外層不需要 DISTINCT，因為 IN 只判斷「存不存在」。

-- 3. 有下過訂單的客戶
SELECT c.CustomerID, c.CompanyName
FROM dbo.Customers AS c
WHERE EXISTS (
	SELECT 1
	FROM dbo.Orders AS o
	WHERE o.CustomerID = c.CustomerID
)
ORDER BY c.CustomerID;
GO
-- 預期：客戶 1～10 共 10 家（新竹生技、高雄運通沒有訂單）
-- EXISTS 只回傳 TRUE/FALSE，子查詢的 SELECT 1 只是佔位。

-- 4. 沒有接過訂單的員工：NOT IN 的 NULL 地雷
-- 4-1 錯誤示範：NOT IN 會因為 Orders.EmployeeID 有 NULL 而回傳 0 筆
SELECT e.EmployeeID, e.LastName + e.FirstName AS 姓名
FROM dbo.Employees AS e
WHERE e.EmployeeID NOT IN (
	SELECT o.EmployeeID
	FROM dbo.Orders AS o
);
GO
-- 預期：0 筆。EmployeeID <> NULL 的結果是 UNKNOWN，WHERE 不會保留。

-- 4-2 正確寫法：NOT EXISTS
SELECT e.EmployeeID, e.LastName + e.FirstName AS 姓名
FROM dbo.Employees AS e
WHERE NOT EXISTS (
	SELECT 1
	FROM dbo.Orders AS o
	WHERE o.EmployeeID = e.EmployeeID
)
ORDER BY e.EmployeeID;
GO
-- 預期：5 筆——黃志強、吳雅婷、張俊傑、劉美玲、王建國
-- 規則：找「不存在」優先用 NOT EXISTS；NOT IN 只適合子查詢欄位保證 NOT NULL 的情況。

-- 5. 每類別中高於該類別平均的產品
SELECT
	p.Category,
	p.ProductName,
	p.UnitPrice,
	(
		SELECT CAST(AVG(p2.UnitPrice) AS DECIMAL(10,2))
		FROM dbo.Products AS p2
		WHERE p2.Category = p.Category
	) AS 類別平均
FROM dbo.Products AS p
WHERE p.UnitPrice > (
	SELECT AVG(p2.UnitPrice)
	FROM dbo.Products AS p2
	WHERE p2.Category = p.Category
)
ORDER BY p.Category, p.UnitPrice DESC;
GO
-- 預期 5 筆：
--   飲料：鐵觀音茶葉 350（平均 225.00）、蜂蜜 280
--   零食：巧克力 120（平均 71.67）
--   文具：印表機耗材 890（平均 315.00）
--   電子：進口耳機 1200（平均 643.33）
-- 相關子查詢的 p2.Category = p.Category 是關鍵；少了它就會變成全體平均。

-- 6. 高於全體員工平均接單金額的員工
SELECT x.姓名, x.接單總金額
FROM (
	SELECT
		e.EmployeeID,
		e.LastName + e.FirstName AS 姓名,
		SUM(COALESCE(d.Quantity * d.UnitPrice, 0)) AS 接單總金額
	FROM dbo.Employees AS e
	LEFT JOIN dbo.Orders AS o ON e.EmployeeID = o.EmployeeID
	LEFT JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	GROUP BY e.EmployeeID, e.LastName, e.FirstName
) AS x
WHERE x.接單總金額 > (
	SELECT AVG(y.接單總金額)
	FROM (
		SELECT
			e.EmployeeID,
			SUM(COALESCE(d.Quantity * d.UnitPrice, 0)) AS 接單總金額
		FROM dbo.Employees AS e
		LEFT JOIN dbo.Orders AS o ON e.EmployeeID = o.EmployeeID
		LEFT JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
		GROUP BY e.EmployeeID
	) AS y
)
ORDER BY x.接單總金額 DESC;
GO
-- 預期：陳大明 6245.00、林小芳 5144.00、李惠雯 3520.00
-- 全體 8 位員工平均 = 14909 / 8 = 1863.625（沒接單的人以 0 計）
-- 這裡一定要用 LEFT JOIN，否則 0 元的員工不會進平均，平均會變成 4969.67。

-- 7. 高於全體城市平均訂單金額的城市
WITH CityRevenue AS (
	SELECT
		c.City,
		SUM(COALESCE(d.Quantity * d.UnitPrice, 0)) AS 總金額
	FROM dbo.Customers AS c
	LEFT JOIN dbo.Orders AS o ON c.CustomerID = o.CustomerID
	LEFT JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	GROUP BY c.City
)
SELECT City, 總金額
FROM CityRevenue
WHERE 總金額 > (
	SELECT AVG(總金額)
	FROM CityRevenue
)
ORDER BY 總金額 DESC;
GO
-- 預期：台北 6980.00、台中 4340.00
-- 全部城市平均 = (6980 + 4340 + 3130 + 1839) / 4 = 4072.25
-- 新竹 3130、高雄 1839 低於平均。

-- 8. 總金額 >= 1000 且訂單數 <= 2 的客戶
WITH OrderTotal AS (
	SELECT
		o.OrderID,
		o.CustomerID,
		SUM(d.Quantity * d.UnitPrice) AS 訂單金額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	GROUP BY o.OrderID, o.CustomerID
),
CustomerStats AS (
	SELECT
		CustomerID,
		COUNT(*) AS 訂單數,
		SUM(訂單金額) AS 總金額
	FROM OrderTotal
	GROUP BY CustomerID
)
SELECT
	c.CompanyName,
	s.訂單數,
	s.總金額
FROM CustomerStats AS s
INNER JOIN dbo.Customers AS c ON s.CustomerID = c.CustomerID
WHERE s.總金額 >= 1000
	AND s.訂單數 <= 2
ORDER BY s.總金額 DESC;
GO
-- 預期：星河電子 2 筆 2060.00、大同工廠 2 筆 1850.00、
--       藍鵡食品 2 筆 1464.00、貝塔科技 2 筆 1070.00
-- 第二個 CTE 引用第一個 CTE，這是 CTE 比巢狀子查詢好讀的地方。

-- 9. 2014 年 1～12 月訂單數（含 0 的月份）
WITH Months AS (
	SELECT CAST('2014-01-01' AS DATE) AS MonthStart
	UNION ALL
	SELECT DATEADD(MONTH, 1, MonthStart)
	FROM Months
	WHERE MonthStart < CAST('2014-12-01' AS DATE)
)
SELECT
	DATEPART(MONTH, m.MonthStart) AS 月份,
	COUNT(o.OrderID) AS 訂單數
FROM Months AS m
LEFT JOIN dbo.Orders AS o
	ON o.OrderDate >= m.MonthStart
	AND o.OrderDate < DATEADD(MONTH, 1, m.MonthStart)
GROUP BY m.MonthStart
ORDER BY m.MonthStart
OPTION (MAXRECURSION 12);
GO
-- 預期：1～9 月各 1 筆，10 月 2 筆，11 月 2 筆，12 月 3 筆
-- 注意是 COUNT(o.OrderID) 不是 COUNT(*)：LEFT JOIN 沒配到的月份會補一列 NULL。
-- 若改用 COUNT(*)，沒有訂單的月份會顯示 1。

-- 10. 新增客戶與訂單
BEGIN TRANSACTION;

INSERT INTO dbo.Customers (CompanyName, City)
VALUES (N'交易測試客戶', N'台北');
DECLARE @CustomerID INT = SCOPE_IDENTITY();

INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipFee)
VALUES (@CustomerID, 1, CAST('2014-06-01' AS DATE), 50.00);
DECLARE @OrderID INT = SCOPE_IDENTITY();

SELECT
	@CustomerID AS 新客戶編號,
	@OrderID AS 新訂單編號,
	c.CompanyName,
	o.OrderDate,
	o.ShipFee
FROM dbo.Customers AS c
INNER JOIN dbo.Orders AS o ON c.CustomerID = o.CustomerID
WHERE c.CustomerID = @CustomerID;

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：1 列，兩張表透過新的 CustomerID 正確關聯
-- 新編號由 SCOPE_IDENTITY() 取得；在乾淨的 seed 上是 13／21，
-- 但重複執行或曾中斷交易後會遞增（Identity 值不會因 ROLLBACK 而回收）。
-- 這也是為什麼答案不寫死 13／21，而是顯示變數值。

-- 11. 零食類單價調漲 10%
BEGIN TRANSACTION;

SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products
WHERE Category = N'零食'
ORDER BY ProductID;

UPDATE dbo.Products
SET UnitPrice = UnitPrice * 1.1
WHERE Category = N'零食';

SELECT @@ROWCOUNT AS 受影響筆數;

SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products
WHERE Category = N'零食'
ORDER BY ProductID;

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：受影響 3 筆
--   洋芋片 35.00 → 38.50
--   花生   60.00 → 66.00
--   巧克力 120.00 → 132.00
-- DECIMAL(10,2) 會自動四捨五入到小數 2 位。
-- 結尾 ROLLBACK 後再查一次，應該恢復原價；這就是「先看、再改、可回滾」。

-- 12. 台北客戶的 NULL 運費補成 100
BEGIN TRANSACTION;

SELECT o.OrderID, c.CompanyName, o.ShipFee
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c ON o.CustomerID = c.CustomerID
WHERE c.City = N'台北'
	AND o.ShipFee IS NULL
ORDER BY o.OrderID;

UPDATE o
SET o.ShipFee = 100.00
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c ON o.CustomerID = c.CustomerID
WHERE c.City = N'台北'
	AND o.ShipFee IS NULL;

SELECT @@ROWCOUNT AS 受影響筆數;

SELECT o.OrderID, c.CompanyName, o.ShipFee
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c ON o.CustomerID = c.CustomerID
WHERE c.City = N'台北'
	AND o.ShipFee IS NOT NULL
ORDER BY o.OrderID;

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：受影響 2 筆（訂單 16、19）
-- UPDATE + JOIN 的語法：UPDATE 後面接別名，SET 用該別名，FROM 再接 JOIN。
-- 不要寫成 UPDATE dbo.Orders SET ... FROM ...（雖然有時可跑，但容易誤解）。

-- 13. 外鍵與刪除順序
BEGIN TRANSACTION;

-- 測試資料（不用改）
INSERT INTO dbo.Customers (CompanyName, ContactName, Phone, City)
VALUES (N'刪除測試客戶', N'測試', N'02-0000-0000', N'台北');
DECLARE @CustomerID INT = SCOPE_IDENTITY();

INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipFee)
VALUES (@CustomerID, 1, CAST('2014-06-01' AS DATE), 50.00);
DECLARE @OrderID INT = SCOPE_IDENTITY();

INSERT INTO dbo.OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
VALUES (@OrderID, 1, 1, 350.00);

-- 13-1 直接刪客戶：會被外鍵擋下
BEGIN TRY
	DELETE FROM dbo.Customers WHERE CustomerID = @CustomerID;
END TRY
BEGIN CATCH
	SELECT
		ERROR_NUMBER() AS 錯誤編號,
		ERROR_MESSAGE() AS 錯誤訊息;
END CATCH;

-- 13-2 正確順序：明細 → 訂單 → 客戶
DELETE FROM dbo.OrderDetails WHERE OrderID = @OrderID;
DELETE FROM dbo.Orders WHERE OrderID = @OrderID;
DELETE FROM dbo.Customers WHERE CustomerID = @CustomerID;

SELECT
	(SELECT COUNT(*) FROM dbo.Customers WHERE CustomerID = @CustomerID) AS 客戶,
	(SELECT COUNT(*) FROM dbo.Orders WHERE OrderID = @OrderID) AS 訂單,
	(SELECT COUNT(*) FROM dbo.OrderDetails WHERE OrderID = @OrderID) AS 明細;

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：CATCH 顯示錯誤編號 547（REFERENCE constraint），
--       最後三張表的計數都是 0。
-- 外鍵是保護資料一致性的機制，不是「擋路」；正確做法是照相依順序刪除。
-- 若公司 schema 有 ON DELETE CASCADE，刪父表會自動刪子表，但影響範圍更大，要特別小心。

-- 14.（挑戰）MERGE upsert
BEGIN TRANSACTION;

MERGE dbo.Products WITH (HOLDLOCK) AS t
USING (
	VALUES
		(N'進口耳機', CAST(1100.00 AS DECIMAL(10,2))),
		(N'藍牙喇叭', CAST(990.00 AS DECIMAL(10,2)))
) AS s (ProductName, UnitPrice)
	ON t.ProductName = s.ProductName
WHEN MATCHED THEN
	UPDATE SET t.UnitPrice = s.UnitPrice
WHEN NOT MATCHED THEN
	INSERT (ProductName, Category, UnitPrice, Discontinued)
	VALUES (s.ProductName, N'電子', s.UnitPrice, 0)
OUTPUT
	$action AS 動作,
	inserted.ProductID,
	inserted.ProductName,
	inserted.UnitPrice;

SELECT ProductID, ProductName, Category, UnitPrice, Discontinued
FROM dbo.Products
WHERE ProductName IN (N'進口耳機', N'藍牙喇叭')
ORDER BY ProductID;

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
-- 預期：1 筆 UPDATE（進口耳機 1200 → 1100）、
--       1 筆 INSERT（藍牙喇叭，新的 ProductID）
-- MERGE 的目標表加 HOLDLOCK 是為了降低併發時的 race condition；
-- 簡單的單筆 upsert 也可以用 IF EXISTS + UPDATE/INSERT 分開寫，通常更好懂。
