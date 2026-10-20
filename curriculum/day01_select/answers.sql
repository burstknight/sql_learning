-- ============================================================
-- Day 1 參考答案與解說
-- 建議：自己做完再看；看不懂的題目把 SQL 貼回 sqlcmd 逐步實驗
-- ============================================================

USE learning_db;
GO

-- 1. 列出所有產品的名稱與單價
SELECT ProductName, UnitPrice
FROM dbo.Products;
GO
-- 說明：正式環境盡量避免 SELECT *：欄位增減時下游程式容易壞，
--       也浪費 I/O。明確列出需要的欄位是好習慣。

-- 2. 客戶分佈在哪些不同城市
SELECT DISTINCT City
FROM dbo.Customers;
GO
-- 說明：DISTINCT 作用在「SELECT 出來的整組欄位」，重複的列只留一列。
--       City 有 NULL 的客戶也會算一種「城市」（NULL 也會出現）。

-- 3. 單價最高的 3 個產品
SELECT TOP 3 ProductName, UnitPrice
FROM dbo.Products
ORDER BY UnitPrice DESC;
GO
-- 說明：TOP 不搭配 ORDER BY 時「取哪 3 筆是不保證的」，
--       想要「最高的 3 個」一定要先 ORDER BY。

-- 4. 單價高於 300 的產品
SELECT ProductName, Category, UnitPrice
FROM dbo.Products
WHERE UnitPrice > 300
ORDER BY UnitPrice DESC;
GO
-- 說明：WHERE 在 SELECT 之前執行，所以先篩選再挑欄位。

-- 5. 文具類且單價小於 100
SELECT ProductName, UnitPrice
FROM dbo.Products
WHERE Category = N'文具' AND UnitPrice < 100;
GO
-- 說明：N 前綴代表 Unicode 字串，對 NVARCHAR 欄位是保險的寫法。

-- 6. 沒留電話的客戶
SELECT CompanyName, ContactName, Phone
FROM dbo.Customers
WHERE Phone IS NULL;
GO
-- 說明：NULL 代表「未知」，不能用 = 比較。WHERE Phone = NULL 永遠查不到資料，
--       這是 SQL 新手第一名常見錯誤。

-- 7. 台北與高雄的客戶
SELECT CompanyName, City
FROM dbo.Customers
WHERE City IN (N'台北', N'高雄');
GO
-- 說明：IN 是多個 OR 的簡寫，可讀性較好、效能通常相同。

-- 8. 單價 100～300 的產品
SELECT ProductName, UnitPrice
FROM dbo.Products
WHERE UnitPrice BETWEEN 100 AND 300;
GO
-- 說明：BETWEEN 含頭含尾，等價 WHERE UnitPrice >= 100 AND UnitPrice <= 300。

-- 9. 名稱開頭是「進口」的產品
SELECT ProductName
FROM dbo.Products
WHERE ProductName LIKE N'進口%';
GO
-- 說明：% 在字尾代表「後面任意字數」。若寫 '%進口%'，則字串任意位置含「進口」都算。
--       開頭固定的 LIKE 可用索引（Day 4 講效能時會看到）。

-- 10. 2014 年下半年的訂單
SELECT OrderID, CustomerID, OrderDate
FROM dbo.Orders
WHERE OrderDate >= '2014-07-01' AND OrderDate < '2015-01-01'
ORDER BY OrderDate;
GO
-- 說明：「左閉右開」(>= 起日、< 次日起) 是日期範圍的標準寫法。
--       若欄位是 DATETIME（含時間部分），BETWEEN '...' AND '2014-12-31'
--       會漏掉 12/31 當天 00:00 之後的資料，用 < 次日才安全。

-- 11. 最近 30 天的訂單
SELECT OrderID, CustomerID, OrderDate
FROM dbo.Orders
WHERE OrderDate >= DATEADD(DAY, -30, GETDATE())
ORDER BY OrderDate;
GO
-- 說明：GETDATE() 是「現在」，DATEADD 往前推 30 天。
--       寫死日期在任何正式系統都是錯的：明天資料就不對了。
--       （seed.sql 有幾筆「最近的訂單」就是為這題準備的）

-- 12. 出現過的產品編號（去重）
SELECT DISTINCT ProductID
FROM dbo.OrderDetails;
GO
-- 說明：訂單明細中同一 ProductID 會重複出現（不同訂單買過），
--       DISTINCT 把它壓成一份，是「這個欄位有哪些值」最快的問法。

-- 13.（挑戰）公司名（電話），沒電話顯示未提供
SELECT CompanyName + N'（' + COALESCE(Phone, N'未提供') + N'）' AS info
FROM dbo.Customers;
GO
-- 說明：
--   1) COALESCE(x, y)：x 不是 NULL 就用 x，否則用 y（兩邊都 NULL 才回 NULL）。
--      SQLite 的 IFNULL 是它的子集。
--   2) 若不用 COALESCE 直接用 +：Phone 為 NULL 時整個 info 會變 NULL，
--      這就是 lesson 裡說的「NULL 用 + 串接會吃掉一切」。
--   3) AS info 給結果欄位一個標題，C# 程式抓欄位時也會用這個名字。
GO
