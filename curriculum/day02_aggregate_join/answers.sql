-- ============================================================
-- Day 2 參考答案與解說
-- 附常見預期結果，方便自我驗證（數字對不上先檢查 JOIN 條件）
-- ============================================================

USE learning_db;
GO

-- 1. 每個類別的產品數
SELECT Category, COUNT(*) AS 產品數
FROM dbo.Products
GROUP BY Category;
GO
-- 預期：飲料 3、零食 3、文具 3、電子 3（各 3 筆）

-- 2. 每個類別的平均單價（正確十進位）與最高單價
SELECT
	Category,
	AVG(CAST(UnitPrice AS DECIMAL(10,2))) AS 平均單價,
	MAX(UnitPrice) AS 最高單價
FROM dbo.Products
GROUP BY Category;
GO
-- 預期平均：飲料 225.00、零食 71.66、文具 315.00、電子 643.33
-- 若平均變成 225、71、315、643（無小數），就是忘了 CAST：
-- AVG 對 INT/部分型別會回傳整數，小數直接被砍。

-- 3. 客戶分佈在幾個城市
SELECT COUNT(DISTINCT City) AS 城市數
FROM dbo.Customers;
GO
-- 預期：4（台北、新竹、高雄、台中）
-- 注意：COUNT(DISTINCT City) 不會把 NULL 算成一種城市。

-- 4. 有電話與沒電話的客戶各幾家
SELECT
	COUNT(Phone) AS 有電話,
	COUNT(*) - COUNT(Phone) AS 沒電話
FROM dbo.Customers;
GO
-- 預期：有電話 10、沒電話 2
-- 原理：COUNT(欄位) 只數非 NULL；這是「數 NULL」的標準技巧。

-- 5. 每個客戶的訂單數（含 0 筆的客戶）
SELECT
	c.CustomerID,
	c.CompanyName,
	COUNT(o.OrderID) AS 訂單數		-- 關鍵：不能用 COUNT(*)
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o
	ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID, c.CompanyName
ORDER BY 訂單數 DESC;
GO
-- 預期：阿里巴巴貿易 4、飛鷹物流 3、貝塔/藍鵡/大同/星河/台北咖啡坊 各 2、
--       高雄五金/晨光文具/台中機械 各 1、新竹生技與高雄運通 0
-- 為什麼 COUNT(o.OrderID) 而不是 COUNT(*)：
--   LEFT JOIN 沒配到的客戶會補一列 NULL 佔位，COUNT(*) 會把它數成 1。
--   COUNT(欄位) 忽略 NULL，所以沒訂單的客戶正確顯示 0。
GO

-- 6. 沒有任何訂單的客戶
SELECT c.CompanyName
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o
	ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;
GO
-- 預期：新竹生技、高雄運通
-- WHERE o.OrderID IS NULL 的語義是「右表沒配到」，不是「訂單編號是 NULL」
--（Orders.OrderID 是主鍵，不可能 NULL）。

-- 7. 每個產品被訂購的總數量與總金額（只列買過的）
SELECT
	p.ProductName,
	SUM(d.Quantity) AS 總數量,
	SUM(d.Quantity * d.UnitPrice) AS 總金額
FROM dbo.OrderDetails AS d
INNER JOIN dbo.Products AS p
	ON d.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY 總數量 DESC;
GO
-- 說明：金額務必用「明細自己的 UnitPrice」（成交價），不是產品現價。
-- 現實系統中歷史成交價與現價幾乎必然不同，seed.sql 刻意做成不同。

-- 8. 從未出現在訂單明細的產品
SELECT p.ProductName
FROM dbo.Products AS p
LEFT JOIN dbo.OrderDetails AS d
	ON p.ProductID = d.ProductID
WHERE d.OrderDetailID IS NULL;
GO
-- 預期：空結果集（這份資料中 12 項產品都被訂過，包含已停產的進口耳機）。
-- 空結果集也是完全合法的查詢結果——代表「這個問題的答案是沒有」。
-- 在 sqlcmd 中「查無資料列」不代表 SQL 錯誤，別急著改條件。

-- 9. 每個員工接單數（含 0 張）
SELECT
	e.LastName + e.FirstName AS 姓名,
	COUNT(o.OrderID) AS 接單數
FROM dbo.Employees AS e
LEFT JOIN dbo.Orders AS o
	ON e.EmployeeID = o.EmployeeID
GROUP BY e.LastName, e.FirstName
ORDER BY 接單數 DESC;
GO
-- 預期：林小芳 5、李惠雯 5、陳大明 4、黃志強/吳雅婷/張俊傑/劉美玲/王建國 各 0
-- GROUP BY 要放 LastName 和 FirstName 兩欄（SELECT 非聚合欄位都進 GROUP BY）。

-- 10. 訂單數 ≥ 2 的客戶
SELECT
	c.CompanyName,
	COUNT(*) AS 訂單數
FROM dbo.Customers AS c
INNER JOIN dbo.Orders AS o
	ON c.CustomerID = o.CustomerID
GROUP BY c.CompanyName
HAVING COUNT(*) >= 2
ORDER BY 訂單數 DESC;
GO
-- 預期：7 家（阿里巴巴 4、飛鷹 3，其餘 5 家各 2）
-- 這裡用 INNER JOIN 是對的：本題只要「有訂單的客戶」。
-- HAVING COUNT(*) >= 2 不能寫成 WHERE COUNT(*) >= 2（WHERE 執行時尚未分組）。

-- 11. 每個城市的訂單總金額（含沒訂單的城市）
SELECT
	c.City,
	SUM(COALESCE(d.Quantity * d.UnitPrice, 0)) AS 總金額
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o
	ON c.CustomerID = o.CustomerID
LEFT JOIN dbo.OrderDetails AS d
	ON o.OrderID = d.OrderID
GROUP BY c.City
ORDER BY 總金額 DESC;
GO
-- 三表 LEFT JOIN：客戶 → 訂單 → 明細，一路 LEFT 才不會漏掉「沒訂單的城市」。
-- COALESCE(..., 0)：沒配到的列運算結果是 NULL，SUM 忽略 NULL 沒錯，
-- 但若某城市「完全沒有訂單」，SUM 會回傳 NULL 而不是 0——
-- 報表上要顯示 0 就補 COALESCE。NULL 與 0 的選擇是報表語意問題，要意識到。

-- 12.（挑戰）接單總金額最高的前 3 名員工
SELECT TOP 3
	e.LastName + e.FirstName AS 姓名,
	SUM(d.Quantity * d.UnitPrice) AS 接單總金額
FROM dbo.Employees AS e
INNER JOIN dbo.Orders AS o
	ON e.EmployeeID = o.EmployeeID
INNER JOIN dbo.OrderDetails AS d
	ON o.OrderID = d.OrderID
GROUP BY e.LastName, e.FirstName
ORDER BY 接單總金額 DESC;
GO
-- 預期：林小芳 4334、陳大明 3780、李惠雯 3160
-- 從沒接單的員工不會出現（INNER JOIN 配不到就被過濾）——
-- 這正是 INNER 與 LEFT 的語意差異：本題問「實際有業績的前三名」，
-- 沒業績的人本來就不在候選名單內。
GO
