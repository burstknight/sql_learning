-- ============================================================
-- Day 4 練習：交易、隔離級別、索引與執行計畫、T-SQL 程式
-- 執行方式同前幾天：
--   互動式：sqlcmd -S localhost\SQLEXPRESS -E -d learning_db
--   整份跑：sqlcmd -S localhost\SQLEXPRESS -E -d learning_db -i exercises.sql
--
-- ⚠️ 本檔會執行 UPDATE、INSERT、CREATE INDEX 等操作。
--    需要修改資料或建立索引的題目都包在交易裡，結尾一律 ROLLBACK。
--    請不要自行把 ROLLBACK 改成 COMMIT；若不小心 COMMIT 或中斷，
--    重新執行 common/seed.sql 即可還原 learning_db。
-- ============================================================

USE learning_db;
GO

-- ------------------------------------------------------------
-- 1. 最基本的交易：修改客戶 11 的電話，驗證後回滾
--      - 查詢客戶 11 目前的電話（應該是 NULL）
--      - UPDATE 成 '02-1111-2222'
--      - 查詢確認已變更
--      - ROLLBACK
--      - 再查一次，確認回復 NULL
-- 提示：BEGIN TRANSACTION ... ROLLBACK TRANSACTION
-- ------------------------------------------------------------

BEGIN TRANSACTION;

-- 你的答案寫在這裡：

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;

-- 你的答案：ROLLBACK 後再查一次，確認電話回到 NULL

GO

-- ------------------------------------------------------------
-- 2. TRY/CATCH 與外鍵錯誤：
--      新增一張 CustomerID = 999 的訂單（這個客戶不存在），
--      用 TRY/CATCH 捕捉錯誤，顯示 ERROR_NUMBER() 與 ERROR_MESSAGE()，
--      最後確認交易已回滾、沒有留下訂單。
-- 提示：SET XACT_ABORT ON;
--       BEGIN TRY ... BEGIN TRANSACTION ... COMMIT ... END TRY
--       BEGIN CATCH IF XACT_STATE() <> 0 ROLLBACK; SELECT ... END CATCH
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 3. SAVE TRANSACTION：只回滾一部分
--      - 把 ProductID 1 的單價 +10
--      - SAVE TRANSACTION AfterFirst
--      - 把 ProductID 2 的單價 +10
--      - ROLLBACK TRANSACTION AfterFirst（只取消第二個更新）
--      - SELECT 驗證：ProductID 1 已變、ProductID 2 沒變
--      - 最後 ROLLBACK 整個交易，資料恢復原狀
-- 提示：SAVE TRANSACTION 不會改變 @@TRANCOUNT
-- ------------------------------------------------------------

BEGIN TRANSACTION;

-- 你的答案寫在這裡：

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 4. 建立索引並比較執行計畫／IO：
--      - 在 OrderDetails(ProductID) 上建立非叢集索引，
--        INCLUDE (Quantity, UnitPrice)
--      - SET STATISTICS IO ON
--      - 查 ProductID = 7 的明細（一般查詢）
--      - 再查一次，強制使用新建的索引：WITH (INDEX(IX_OrderDetails_ProductID))
--      - SET STATISTICS IO OFF
--      - ROLLBACK（索引會消失）
-- 提示：資料只有 27 筆，最佳化工具可能仍選 scan；
--       重點是觀察 logical reads 與計畫，不是期待大幅加速。
-- ------------------------------------------------------------

BEGIN TRANSACTION;
GO

-- 你的答案：CREATE INDEX ...

GO

-- 你的答案：SET STATISTICS IO ON; 兩次 SELECT；SET STATISTICS IO OFF;

GO

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 5. SARGable 改寫：
--      - 在 Orders(OrderDate) 建立索引（交易內，最後回滾）
--      - 用 SET STATISTICS IO ON
--      - 查詢 A：WHERE YEAR(OrderDate) = 2014 的訂單數
--      - 查詢 B：WHERE OrderDate >= '20140101' AND OrderDate < '20150101' 的訂單數
--      - 比較兩個計畫與 logical reads，說明為什麼 B 比較 SARGable
-- 提示：兩個查詢都應得到 16 筆；資料量小，IO 可能差不多。
-- ------------------------------------------------------------

BEGIN TRANSACTION;
GO

-- 你的答案：CREATE INDEX ...

GO

-- 你的答案：SET STATISTICS IO ON; 查詢 A；查詢 B；SET STATISTICS IO OFF;

GO

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 6. 變數：用 @Category 與 @MinPrice 查產品
--      - 類別 = N'電子'
--      - 單價 >= 300
--      - 顯示產品名稱、單價，依單價由高到低
-- 提示：DECLARE @Category NVARCHAR(50) = N'電子';
--       DECLARE @MinPrice DECIMAL(10,2) = 300;
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 7. IF/ELSE：計算客戶 1 的訂單總金額，依金額分級
--      >= 4000：VIP
--      >= 2000：重要客戶
--      其餘：一般客戶
--      顯示等級與總金額
-- 提示：先用 SELECT @Total = COALESCE(SUM(...), 0) 算總金額，
--       再用 IF / ELSE IF / ELSE
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 8. WHILE：計算 1 + 2 + ... + 100
--      - 用變數 @i 與 @sum
--      - 迴圈結束後 SELECT @sum
-- 提示：WHILE @i <= 100 BEGIN ... END
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 9. 預存程序與 OUTPUT 參數：
--      - 建立 dbo.usp_GetCustomerStats
--          輸入 @CustomerID INT
--          輸出 @OrderCount INT、@Total DECIMAL(12,2)
--      - 計算指定客戶的訂單數與訂單總金額（沒有訂單時總金額為 0）
--      - 用 EXEC 取得客戶 1 的結果
--      - ROLLBACK（交易內建立的預存程序會消失）
-- 提示：CREATE PROCEDURE 必須是批次的第一個陳述式，
--       所以先 BEGIN TRANSACTION; GO，再 CREATE PROCEDURE ...
--       COUNT(DISTINCT o.OrderID)、COALESCE(SUM(...), 0)
-- ------------------------------------------------------------

BEGIN TRANSACTION;
GO

-- 你的答案：CREATE PROCEDURE dbo.usp_GetCustomerStats ...

GO

-- 你的答案：DECLARE 變數、EXEC ... OUTPUT、SELECT 結果

GO

IF @@TRANCOUNT > 0
	ROLLBACK TRANSACTION;
GO

-- ------------------------------------------------------------
-- 10. 動態 SQL：用 sys.sp_executesql 參數化查詢
--      - @Category = N'電子'
--      - 用 sys.sp_executesql 查出該類別的產品名稱與單價
--      - 再故意把 @Category 設成 N'電子'' OR 1=1 --'
--        觀察參數化後仍然只會把它當成一個字串（結果 0 筆）
-- 提示：DECLARE @sql NVARCHAR(MAX) = N'SELECT ... WHERE Category = @Category;';
--       EXEC sys.sp_executesql @sql, N'@Category NVARCHAR(50)', @Category = @Category;
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 11. CASE 分級：列出每位客戶的訂單總金額與等級
--      總金額 >= 4000：VIP
--      總金額 >= 2000：重要
--      總金額 > 0：一般
--      總金額 = 0：新客
--      顯示公司名稱、總金額、等級，依總金額由高到低
-- 提示：Customers LEFT JOIN Orders LEFT JOIN OrderDetails，
--       GROUP BY 客戶，SUM(COALESCE(...))；CASE 不能直接用 SELECT 別名，
--       要在 CASE 裡重寫一次聚合或包一層 CTE
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO

-- ------------------------------------------------------------
-- 12.（挑戰）交易 + TRY/CATCH 的完整流程：
--      1) 新增一張訂單（客戶 1、員工 1、日期 2014-06-15、運費 50）
--      2) 明細故意用不存在的 ProductID = 999 → 外鍵錯誤
--      3) CATCH 捕捉錯誤、確認交易回滾、訂單沒有留下
--      4) 重新開交易，明細改用 ProductID = 1，成功後 SELECT 驗證
--      5) 最後 ROLLBACK，讓資料恢復原狀
-- 提示：SET XACT_ABORT ON; TRY/CATCH 樣板請參考 lesson 1.4；
--       用 SCOPE_IDENTITY() 取得 OrderID；結尾 SET XACT_ABORT OFF;
-- ------------------------------------------------------------

-- 你的答案寫在這裡：

GO
