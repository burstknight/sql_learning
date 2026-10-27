-- ============================================================
-- Day 3 練習：子查詢、CTE、型別轉換、DML 安全實務
-- 執行方式同 Day 1／Day 2：
--   互動式：sqlcmd -S localhost\SQLEXPRESS -E -d learning_db
--   整份跑：sqlcmd -S localhost\SQLEXPRESS -E -d learning_db -i exercises.sql
--
-- ⚠️ 第 10 題以後會執行 INSERT／UPDATE／DELETE。
--    每一題都包在交易裡，結尾一律 ROLLBACK，正常情況下不會留下資料變更。
--    請不要自行把 ROLLBACK 改成 COMMIT；若不小心 COMMIT 或中斷，
--    重新執行 common/seed.sql 即可把 learning_db 還原。
-- ============================================================

USE learning_db;
GO

-- ------------------------------------------------------------
-- 1. 找出單價高於「全體產品平均單價」的產品：
--     產品名稱、單價，依單價由高到低
-- 提示：WHERE UnitPrice > (SELECT AVG(...) FROM ...)
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 2. 找出「買過電子類產品」的客戶：公司名稱（重複的只留一個）
-- 提示：Customers → Orders → OrderDetails → Products 四表串接，
--       或先用子查詢找出符合的 CustomerID 再用 IN
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 3. 找出「有下過訂單」的客戶：客戶編號、公司名稱
-- 提示：EXISTS（子查詢裡用 o.CustomerID = c.CustomerID 相關起來）
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 4. 找出「沒有接過任何訂單」的員工：員工編號、姓名
--     先用 NOT IN 寫一次，觀察結果是不是 0 筆；
--     再改用 NOT EXISTS，確認得到 5 筆。
-- 提示：Orders.EmployeeID 有 NULL，想想 NOT IN 遇到 NULL 會怎樣
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 5. 每個類別中，單價高於「該類別平均單價」的產品：
--     類別、產品名稱、單價、該類別平均（平均取到小數 2 位）
-- 提示：相關子查詢，內層 WHERE p2.Category = p.Category；
--       平均用 CAST(AVG(...) AS DECIMAL(10,2))
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 6. 每位員工的接單總金額，列出「高於全體員工平均接單金額」的員工：
--     姓名、接單總金額，依金額由高到低
--     沒有接單的員工也要算進平均（金額視為 0）
-- 提示：Employees LEFT JOIN Orders LEFT JOIN OrderDetails，
--       先做成派生資料表（FROM (...) AS x），再跟平均比較
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 7. 每個城市的訂單總金額，只列出「高於全體城市平均」的城市：
--     城市、總金額，依金額由高到低
-- 提示：用 CTE 先算每城市總金額，外層再跟 AVG(總金額) 比較
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 8. 客戶訂單數與總金額，找出「總金額 >= 1000 且訂單數 <= 2」的客戶：
--     公司名稱、訂單數、總金額
-- 提示：用兩個 CTE：第一個算每張訂單金額，第二個依客戶聚合
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 9. 2014 年 1～12 月，每個月的訂單數（沒有訂單的月份也要顯示 0）：
--     月份（1～12）、訂單數
-- 提示：遞迴 CTE 產生 12 個月的第一天，LEFT JOIN Orders，
--       COUNT(o.OrderID)；記得加 OPTION (MAXRECURSION 12)
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 10. 新增一位客戶與一張訂單，並用 SCOPE_IDENTITY() 取得新編號：
--       - 客戶：公司名「交易測試客戶」、城市「台北」
--       - 訂單：客戶編號用剛才新增的、員工編號 1、日期 2014-06-01、運費 50
--     最後 SELECT 新客戶與新訂單，確認關聯正確
-- 提示：INSERT 客戶 → DECLARE @CustomerID INT = SCOPE_IDENTITY()
--       → INSERT 訂單（用 @CustomerID）→ SELECT
--       本題已在交易中，結尾會自動 ROLLBACK
-- ------------------------------------------------------------

BEGIN TRANSACTION;

-- 你的答案寫在這裡：

-- 驗證：SELECT ... FROM dbo.Customers / dbo.Orders

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 11. 把「零食」類產品的單價調漲 10%：
--       - 先 SELECT 調漲前的價格
--       - UPDATE 後再 SELECT 一次
--       - 顯示 @@ROWCOUNT（受影響筆數）
--     最後 ROLLBACK，資料要恢復原狀
-- 提示：UPDATE ... SET UnitPrice = UnitPrice * 1.1 WHERE Category = N'零食'
-- ------------------------------------------------------------

BEGIN TRANSACTION;

-- 你的答案寫在這裡：

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 12. 把「台北」客戶、且運費為 NULL 的訂單，運費補成 100：
--       - 先用 SELECT 找出符合條件的訂單
--       - 用 UPDATE + JOIN（或 CTE）更新
--       - 顯示 @@ROWCOUNT，再 SELECT 驗證
--     最後 ROLLBACK
-- 提示：UPDATE o SET o.ShipFee = 100.00 FROM dbo.Orders AS o
--       INNER JOIN dbo.Customers AS c ON o.CustomerID = c.CustomerID
--       WHERE c.City = N'台北' AND o.ShipFee IS NULL
-- ------------------------------------------------------------

BEGIN TRANSACTION;

-- 你的答案寫在這裡：

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 13. 外鍵與刪除順序：
--       下面已經建好一位測試客戶、一張測試訂單、一筆明細（不用改）。
--       1) 先直接 DELETE 客戶，用 TRY/CATCH 觀察外鍵錯誤（547）
--       2) 再依正確順序刪除：明細 → 訂單 → 客戶
--       3) SELECT 確認三張表都查不到這筆測試資料
-- 提示：DELETE FROM dbo.Customers WHERE CustomerID = @CustomerID;
--       CATCH 裡可用 ERROR_NUMBER()、ERROR_MESSAGE()
-- ------------------------------------------------------------

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

-- 你的答案寫在這裡：

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 14.（挑戰）用 MERGE 對 Products 做 upsert：
--       - 若產品名稱「進口耳機」已存在 → 把單價改成 1100
--       - 若產品名稱「藍牙喇叭」不存在 → 新增（類別：電子、單價 990、未停產）
--       - 用 OUTPUT $action 顯示每列是 INSERT 還是 UPDATE
--     最後 SELECT 這兩個產品，再 ROLLBACK
-- 提示：MERGE dbo.Products AS t USING (VALUES ...) AS s(...)
--       ON t.ProductName = s.ProductName
--       WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT ...
-- ------------------------------------------------------------

BEGIN TRANSACTION;

-- 你的答案寫在這裡：

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO
