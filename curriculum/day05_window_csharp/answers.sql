-- ============================================================
-- Day 5 參考答案與解說
-- 建議：自己做完再看；視窗函數的結果建議在 sqlcmd 逐步加欄位觀察
--
-- 本檔全部是查詢，不會修改資料。
-- 所有題目只使用 2014 年的訂單（OrderDate < 2015-01-01），
-- 以避免 seed.sql 中 4 張動態日期訂單造成每次結果不同。
-- ============================================================

USE learning_db;
GO

-- 1. ROW_NUMBER()：2014 年訂單編號
SELECT
	OrderID,
	OrderDate,
	ROW_NUMBER() OVER (ORDER BY OrderDate, OrderID) AS 序號
FROM dbo.Orders
WHERE OrderDate < CAST('2015-01-01' AS DATE)
ORDER BY 序號;
GO
-- 預期：16 列，序號 1～16。
--   第 1 列 OrderID 1（2014-01-15）、第 16 列 OrderID 16（2014-12-30）。
-- ROW_NUMBER 的排序鍵加上 OrderID 是為了讓同一天的訂單也有穩定順序。

-- 2. 每位客戶最近一張 2014 年訂單
WITH Ranked AS (
	SELECT
		o.CustomerID,
		c.CompanyName,
		o.OrderID,
		o.OrderDate,
		ROW_NUMBER() OVER (
			PARTITION BY o.CustomerID
			ORDER BY o.OrderDate DESC, o.OrderID DESC
		) AS rn
	FROM dbo.Orders AS o
	INNER JOIN dbo.Customers AS c ON c.CustomerID = o.CustomerID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
)
SELECT CustomerID, CompanyName, OrderID, OrderDate
FROM Ranked
WHERE rn = 1
ORDER BY CustomerID;
GO
-- 預期：10 列（客戶 1～10；11、12 沒有任何訂單）
--   1 阿里巴巴貿易 14 2014-12-05
--   2 貝塔科技      2 2014-02-20
--   3 藍鵡食品     12 2014-11-11
--   4 大同工廠     16 2014-12-30
--   5 飛鷹物流     13 2014-11-28
--   6 高雄五金      7 2014-07-12
--   7 晨光文具      8 2014-08-05
--   8 星河電子     15 2014-12-19
--   9 台北咖啡坊   10 2014-10-02
--  10 台中機械     11 2014-10-25
-- 這是「每組最新一筆」的標準寫法；比 GROUP BY + MAX 再 join 更不容易出錯。

-- 3. 客戶 2014 訂單數與三種排名
SELECT
	CustomerID,
	COUNT(*) AS 訂單數,
	ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC, CustomerID) AS rn,
	RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk,
	DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS dense_rnk
FROM dbo.Orders
WHERE OrderDate < CAST('2015-01-01' AS DATE)
GROUP BY CustomerID
ORDER BY 訂單數 DESC, CustomerID;
GO
-- 預期：
--   客戶 1：3 筆，rn 1，rnk 1，dense 1
--   客戶 3、4、5、8：各 2 筆，rn 2～5，rnk 都是 2，dense 都是 2
--   客戶 2、6、7、9、10：各 1 筆，rn 6～10，rnk 都是 6，dense 都是 3
-- 觀察重點：
--   ROW_NUMBER 永遠是 1,2,3,...（並列時靠 CustomerID 決定先後）
--   RANK 在 4 個「2 筆」之後跳到 6（跳號）
--   DENSE_RANK 接 3（不跳號）
-- 若把 ORDER BY 的 CustomerID 拿掉，並列客戶的 rn 不保證誰先誰後。

-- 4. NTILE(3)：2014 年訂單金額分三組
WITH OrderTotals AS (
	SELECT
		o.OrderID,
		SUM(d.Quantity * d.UnitPrice) AS 訂單金額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY o.OrderID
),
Buckets AS (
	SELECT
		OrderID,
		訂單金額,
		NTILE(3) OVER (ORDER BY 訂單金額 DESC, OrderID) AS 組別
	FROM OrderTotals
)
SELECT OrderID, 訂單金額, 組別
FROM Buckets
ORDER BY 組別, 訂單金額 DESC, OrderID;
GO
-- 預期：16 筆，切成 6／5／5 三組
--   第 1 組（6 筆）：1740、1580、1090、1040、960、940
--   第 2 組（5 筆）：900、880、810、690、580
--   第 3 組（5 筆）：570、504、480、375、350
-- 16 不能被 3 整除，所以第一組多一筆；NTILE 的重點是「盡量平均」，
-- 不是「金額區間等寬」。若外層再 GROUP BY 組別，可得到每組筆數與金額範圍。

-- 5. 每月營業額與月成長
WITH MonthlyRevenue AS (
	SELECT
		DATEPART(MONTH, o.OrderDate) AS 月份,
		SUM(d.Quantity * d.UnitPrice) AS 營業額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.OrderDate >= CAST('2014-01-01' AS DATE)
		AND o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY DATEPART(MONTH, o.OrderDate)
)
SELECT
	月份,
	營業額,
	LAG(營業額) OVER (ORDER BY 月份) AS 上月營業額,
	營業額 - LAG(營業額) OVER (ORDER BY 月份) AS 月增減,
	CAST(
		100.0 * (營業額 - LAG(營業額) OVER (ORDER BY 月份))
			/ NULLIF(LAG(營業額) OVER (ORDER BY 月份), 0)
		AS DECIMAL(10,2)
	) AS 成長率百分比
FROM MonthlyRevenue
ORDER BY 月份;
GO
-- 預期：12 列
--   1 月 940.00，上月與成長率 NULL
--   2 月 690.00，-250.00，-26.60
--   3 月 960.00，+270.00，39.13
--   4 月 1090.00，+130.00，13.54
--   5 月 1040.00，-50.00，-4.59
--   6 月 900.00，-140.00，-13.46
--   7 月 375.00，-525.00，-58.33
--   8 月 570.00，+195.00，52.00
--   9 月 1580.00，+1010.00，177.19
--  10 月 1230.00，-350.00，-22.15
--  11 月 2244.00，+1014.00，82.44
--  12 月 1870.00，-374.00，-16.67
-- 第一個月沒有上月，LAG 回傳 NULL，成長率也是 NULL（不是 0）。
-- NULLIF 把分母的 0 變成 NULL，避免除以零。

-- 6. 累計營業額（running total）
WITH OrderTotals AS (
	SELECT
		o.OrderID,
		o.OrderDate,
		SUM(d.Quantity * d.UnitPrice) AS 訂單金額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY o.OrderID, o.OrderDate
)
SELECT
	OrderID,
	OrderDate,
	訂單金額,
	SUM(訂單金額) OVER (
		ORDER BY OrderDate, OrderID
		ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
	) AS 累計營業額
FROM OrderTotals
ORDER BY OrderDate, OrderID;
GO
-- 預期：累計值依序為
--   940、1630、2590、3680、4720、5620、5995、6565、
--   8145、8495、9375、9879、11619、12199、12679、13489
-- 最後一列就是 2014 年全年營業額 13489.00。
-- 這裡明寫 ROWS；若只寫 ORDER BY，預設是 RANGE，
-- 同一天的訂單會一起加，累計值會相同（本資料沒有同一天，所以結果剛好一樣）。

-- 7. 3 筆移動平均
WITH OrderTotals AS (
	SELECT
		o.OrderID,
		o.OrderDate,
		SUM(d.Quantity * d.UnitPrice) AS 訂單金額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY o.OrderID, o.OrderDate
)
SELECT
	OrderID,
	OrderDate,
	訂單金額,
	CAST(
		AVG(訂單金額) OVER (
			ORDER BY OrderDate, OrderID
			ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
		) AS DECIMAL(10,2)
	) AS 三筆移動平均
FROM OrderTotals
ORDER BY OrderDate, OrderID;
GO
-- 預期：前 5 列為 940.00、815.00、863.33、913.33、1030.00
--   第 7 列（OrderID 7，375.00）為 771.67
--   最後一列（OrderID 16，810.00）為 623.33
-- 前兩列只有 1、2 筆資料，所以平均是「目前為止」的平均，不是除以 3。
-- frame 的 2 PRECEDING 代表往前兩列，加上目前這一列共 3 筆。

-- 8. 每張訂單占該客戶總額的百分比
WITH OrderTotals AS (
	SELECT
		o.CustomerID,
		o.OrderID,
		SUM(d.Quantity * d.UnitPrice) AS 訂單金額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY o.CustomerID, o.OrderID
)
SELECT
	CustomerID,
	OrderID,
	訂單金額,
	CAST(
		100.0 * 訂單金額
			/ SUM(訂單金額) OVER (PARTITION BY CustomerID)
		AS DECIMAL(10,2)
	) AS 占客戶百分比
FROM OrderTotals
ORDER BY CustomerID, OrderID;
GO
-- 預期：客戶 1 的三張訂單為 36.02%、41.76%、22.22%（合計 100）
--   客戶 3：65.57%、34.43%
--   客戶 4：56.22%、43.78%
--   客戶 5：34.09%、65.91%
--   客戶 8：76.70%、23.30%
--   只有一張訂單的客戶（2、6、7、9、10）都是 100.00%
-- 分母是「該客戶所有訂單金額」；PARTITION BY 讓每張訂單只跟同一客戶比。
-- 若拿掉 PARTITION BY，分母會變成全體營業額，百分比加起來才是 100。

-- 9. 每個類別單價最高的前 2 名產品
WITH Ranked AS (
	SELECT
		Category,
		ProductName,
		UnitPrice,
		ROW_NUMBER() OVER (
			PARTITION BY Category
			ORDER BY UnitPrice DESC, ProductID
		) AS rn
	FROM dbo.Products
)
SELECT Category, ProductName, UnitPrice, rn
FROM Ranked
WHERE rn <= 2
ORDER BY Category, rn;
GO
-- 預期：8 列
--   文具：印表機耗材 890.00、筆記本 40.00
--   飲料：鐵觀音茶葉 350.00、蜂蜜 280.00
--   電子：進口耳機 1200.00、鍵盤 480.00
--   零食：巧克力 120.00、花生 60.00
-- 注意「文具」的第三名是圓珠筆 15.00，不是 40.00 之後才排；
-- ORDER BY 的 ProductID 只是同價時的穩定鍵。
-- 若把 ROW_NUMBER 換成 RANK，同價並列時可能回傳超過 2 筆。

-- 10. 每城市 2014 年營業額最高的客戶
WITH CityCustomer AS (
	SELECT
		c.City,
		c.CustomerID,
		c.CompanyName,
		SUM(d.Quantity * d.UnitPrice) AS 營業額
	FROM dbo.Customers AS c
	INNER JOIN dbo.Orders AS o ON o.CustomerID = c.CustomerID
	INNER JOIN dbo.OrderDetails AS d ON d.OrderID = o.OrderID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY c.City, c.CustomerID, c.CompanyName
),
Ranked AS (
	SELECT
		City,
		CompanyName,
		營業額,
		ROW_NUMBER() OVER (
			PARTITION BY City
			ORDER BY 營業額 DESC, CustomerID
		) AS rn
	FROM CityCustomer
)
SELECT City, CompanyName, 營業額
FROM Ranked
WHERE rn = 1
ORDER BY City;
GO
-- 預期：4 列
--   台中 飛鷹物流 2640.00
--   台北 阿里巴巴貿易 2610.00
--   高雄 藍鵡食品 1464.00
--   新竹 星河電子 2060.00
-- （依中文定序排序，所以台中的「台」排在台北前面）
-- 先聚合到「城市＋客戶」一層，再排名；若直接對訂單排名，
-- 同一客戶的多張訂單會佔掉多個名次。

-- 11. 同客戶相鄰訂單間隔天數
WITH Ordered AS (
	SELECT
		o.CustomerID,
		o.OrderID,
		o.OrderDate,
		LAG(o.OrderDate) OVER (
			PARTITION BY o.CustomerID
			ORDER BY o.OrderDate, o.OrderID
		) AS 前一張日期
	FROM dbo.Orders AS o
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
)
SELECT
	CustomerID,
	OrderID,
	OrderDate,
	DATEDIFF(DAY, 前一張日期, OrderDate) AS 間隔天數
FROM Ordered
ORDER BY CustomerID, OrderDate, OrderID;
GO
-- 預期：16 列，每人的第一張訂單間隔為 NULL
--   客戶 1：OrderID 1 → 4 間隔 76 天；4 → 14 間隔 248 天
--   客戶 3：3 → 12 間隔 248 天
--   客戶 4：5 → 16 間隔 225 天
--   客戶 5：6 → 13 間隔 151 天
--   客戶 8：9 → 15 間隔 93 天
-- 只有一張訂單的客戶（2、6、7、9、10）間隔都是 NULL。
-- DATEDIFF(DAY, 前一張, 這一張) 的參數順序不能顛倒，否則會變負數。

-- 12. 各類別營業額與占全年百分比
WITH CategoryRevenue AS (
	SELECT
		p.Category,
		SUM(d.Quantity * d.UnitPrice) AS 營業額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	INNER JOIN dbo.Products AS p ON p.ProductID = d.ProductID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY p.Category
)
SELECT
	Category,
	營業額,
	CAST(
		100.0 * 營業額 / SUM(營業額) OVER ()
		AS DECIMAL(10,2)
	) AS 占全年百分比
FROM CategoryRevenue
ORDER BY 營業額 DESC;
GO
-- 預期：
--   飲料 4304.00，31.91%
--   文具 3980.00，29.51%
--   電子 3650.00，27.06%
--   零食 1555.00，11.53%
-- 四者合計 13489.00，百分比合計約 100（四捨五入誤差）。
-- SUM(營業額) OVER () 的空白括號代表「整個結果集」，
-- 所以分母是全年總額，而不是類別自己的總額。

-- 13. 分頁：每頁 5 筆，取第 2 頁
WITH OrderTotals AS (
	SELECT
		o.OrderID,
		SUM(d.Quantity * d.UnitPrice) AS 訂單金額
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
	GROUP BY o.OrderID
)
SELECT OrderID, 訂單金額
FROM OrderTotals
ORDER BY 訂單金額 DESC, OrderID
OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;
GO
-- 預期：第 2 頁是 940.00、900.00、880.00、810.00、690.00
--   對應 OrderID 1、6、11、16、2
-- 第 1 頁（OFFSET 0，前 5 筆）是 1740、1580、1090、1040、960。
-- OFFSET/FETCH 一定要有 ORDER BY；ORDER BY 加上 OrderID 是為了同金額時的穩定分頁。
-- 深度分頁（OFFSET 很大）會愈來愈慢，實務上可改成 key-set pagination：
--   WHERE (訂單金額, OrderID) < (@上一頁最後金額, @上一頁最後ID)
