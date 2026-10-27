# Day 3：子查詢、CTE、型別轉換與 DML 安全實務

建議時間分配（約 4.5 小時）：

| 時間 | 內容 |
|------|------|
| 60 分 | 子查詢（scalar／IN／EXISTS／相關子查詢／派生資料表） |
| 60 分 | CTE 與遞迴 CTE |
| 40 分 | 型別轉換與 NULL 再深入 |
| 80 分 | INSERT／UPDATE／DELETE 的安全流程 |
| 其餘 | 做 `exercises.sql` |

---

## 1. 子查詢：把查詢結果當成另一個查詢的原料

子查詢（subquery）就是包在括號裡的 `SELECT`。依回傳形狀分成三類：

| 形狀 | 回傳 | 常見位置 |
|------|------|----------|
| 純量（scalar） | 1 列 1 欄 | `WHERE`、`SELECT`、`HAVING` 的比較值 |
| 多列單欄 | 多列 1 欄 | `IN`／`NOT IN`、`ANY`／`ALL` |
| 多列多欄 | 一張小表 | `FROM` 後面的派生資料表、`EXISTS` |

### 1.1 純量子查詢

```sql
-- 單價高於「全體平均」的產品
SELECT ProductName, UnitPrice
FROM dbo.Products
WHERE UnitPrice > (
	SELECT AVG(UnitPrice)
	FROM dbo.Products
)
ORDER BY UnitPrice DESC;
```

- 子查詢先算出一個值（這裡是 313.75），外層再拿這個值比較
- 純量子查詢**只能回傳 1 列 1 欄**。回傳多列會報 `Subquery returned more than 1 value`；回傳多欄會報語法錯誤
- 子查詢回傳 NULL 時，外層比較結果是 UNKNOWN，`WHERE` 不會保留任何列

也可以放在 `SELECT` 清單，讓每一列附上一個全域數字：

```sql
SELECT
	ProductName,
	UnitPrice,
	(SELECT AVG(UnitPrice) FROM dbo.Products) AS 全體平均,
	UnitPrice - (SELECT AVG(UnitPrice) FROM dbo.Products) AS 價差
FROM dbo.Products;
```

同一段子查詢重複寫很醜，實務上會用 CTE 或 `CROSS APPLY` 整理（後面會看到）。

### 1.2 IN／NOT IN：多列單欄

```sql
-- 買過「電子」類產品的客戶
SELECT DISTINCT c.CompanyName
FROM dbo.Customers AS c
INNER JOIN dbo.Orders AS o
	ON c.CustomerID = o.CustomerID
INNER JOIN dbo.OrderDetails AS d
	ON o.OrderID = d.OrderID
INNER JOIN dbo.Products AS p
	ON d.ProductID = p.ProductID
WHERE p.Category = N'電子';
```

改寫成子查詢，有時比四表 JOIN 好讀：

```sql
SELECT c.CompanyName
FROM dbo.Customers AS c
WHERE c.CustomerID IN (
	SELECT o.CustomerID
	FROM dbo.Orders AS o
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	INNER JOIN dbo.Products AS p ON d.ProductID = p.ProductID
	WHERE p.Category = N'電子'
);
```

`IN` 等於一連串 `OR`，`NOT IN` 等於一連串 `AND <>`。**`NOT IN` 有一個經典地雷**，下一節用實際資料示範。

### 1.3 EXISTS／NOT EXISTS：只問「有沒有」

`EXISTS` 不回傳值，只回傳 TRUE／FALSE。它通常和「相關子查詢」一起用：

```sql
-- 有下過單的客戶
SELECT c.CustomerID, c.CompanyName
FROM dbo.Customers AS c
WHERE EXISTS (
	SELECT 1
	FROM dbo.Orders AS o
	WHERE o.CustomerID = c.CustomerID
);
```

- 子查詢裡的 `SELECT 1` 只是佔位，寫 `SELECT *` 也一樣；引擎只在乎「有沒有列」
- 找到第一列就停止，不需要把整個子查詢跑完
- `NOT EXISTS` 是「找不到」的意思，和 `LEFT JOIN ... IS NULL` 等價，但通常更好讀

**和 Day 2 的 LEFT JOIN 對照：**

```sql
-- 沒有訂單的客戶：LEFT JOIN 寫法
SELECT c.CompanyName
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;

-- 沒有訂單的客戶：NOT EXISTS 寫法（語意相同）
SELECT c.CompanyName
FROM dbo.Customers AS c
WHERE NOT EXISTS (
	SELECT 1 FROM dbo.Orders AS o WHERE o.CustomerID = c.CustomerID
);
```

### 1.4 ⚠️ NOT IN 的 NULL 地雷（必看）

先看 `Orders.EmployeeID`：它有兩筆是 NULL（接單員工離職後被清空）。
現在想找「沒有接過單的員工」，很容易寫成：

```sql
SELECT EmployeeID, LastName + FirstName AS 姓名
FROM dbo.Employees
WHERE EmployeeID NOT IN (
	SELECT EmployeeID FROM dbo.Orders
);
```

結果是 **0 筆**，但明明有 5 位員工沒接過單。為什麼？

把 `NOT IN` 想成：

```
EmployeeID <> 1 AND EmployeeID <> 2 AND ... AND EmployeeID <> NULL
```

任何值和 NULL 用 `<>` 比較，結果都是 UNKNOWN；整串 `AND` 只要有一個 UNKNOWN，
就不會是 TRUE，`WHERE` 自然一列都不留。

**正確寫法：**

```sql
SELECT e.EmployeeID, e.LastName + e.FirstName AS 姓名
FROM dbo.Employees AS e
WHERE NOT EXISTS (
	SELECT 1
	FROM dbo.Orders AS o
	WHERE o.EmployeeID = e.EmployeeID
);
```

`NOT EXISTS` 只問「子查詢有沒有列」，NULL 不會讓它變成 UNKNOWN。這是
`NOT IN` 與 `NOT EXISTS` 最重要的差異。

> 若子查詢欄位宣告為 `NOT NULL`，`NOT IN` 就沒有這個問題；但實務上很難保證，
> 所以「找不存在」一律優先用 `NOT EXISTS`。

### 1.5 相關子查詢：內層會用到外層的列

```sql
-- 每個類別中，單價高於「該類別平均」的產品
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
```

`p2.Category = p.Category` 讓內層查詢「跟著外層每一列跑一次」。概念上是逐列執行，
但引擎通常會用 semi join／apply 等方式優化，不一定是真的跑 N 次。

**常見錯誤：** 內外層別名沒寫清楚，變成自己比自己，或不小心把相關條件寫到外層。

### 1.6 派生資料表（derived table）

把子查詢放在 `FROM` 後面，當成一張暫時的「小表」：

```sql
-- 每位員工的接單總金額，再篩出高於全體平均的人
SELECT x.姓名, x.接單總金額
FROM (
	SELECT
		e.LastName + e.FirstName AS 姓名,
		SUM(COALESCE(d.Quantity * d.UnitPrice, 0)) AS 接單總金額
	FROM dbo.Employees AS e
	LEFT JOIN dbo.Orders AS o ON e.EmployeeID = o.EmployeeID
	LEFT JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	GROUP BY e.LastName, e.FirstName
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
```

規則：

- `FROM` 後面的子查詢**一定要有別名**（這裡是 `x`、`y`）
- 同一層的 `SELECT`／`WHERE` 不能直接引用同一層的欄位別名，所以平均要再包一層
- 派生資料表適合「先聚合、再篩選」；更複雜的查詢用 CTE 會更清楚

### 1.7 子查詢 vs JOIN：怎麼選

| 情境 | 建議 |
|------|------|
| 只需要「有沒有」 | `EXISTS`／`NOT EXISTS` |
| 需要子查詢的欄位一起顯示 | `JOIN` 或派生資料表 |
| 子查詢會回傳多列，但外層只要比對 | `IN`（注意 NULL） |
| 多步驟、需要重複引用 | CTE（下一節） |

子查詢不是「比較慢」的同義詞；效能要看執行計畫，不要憑感覺改写。可讀性、語意正確
（尤其是 NULL）比「聽說 JOIN 比較快」重要。

---

## 2. CTE：替複雜查詢取名字

CTE（Common Table Expression）用 `WITH` 定義一個具名結果集，**只在下一個陳述式有效**。

### 2.1 基本語法

```sql
WITH CustomerRevenue AS (
	SELECT
		c.CustomerID,
		c.CompanyName,
		SUM(d.Quantity * d.UnitPrice) AS 總金額
	FROM dbo.Customers AS c
	INNER JOIN dbo.Orders AS o ON c.CustomerID = o.CustomerID
	INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
	GROUP BY c.CustomerID, c.CompanyName
)
SELECT CompanyName, 總金額
FROM CustomerRevenue
WHERE 總金額 >= 2000
ORDER BY 總金額 DESC;
```

**語法坑：** `WITH` 前面如果還有陳述式，前一句必須用分號結束，否則會出現
`Incorrect syntax near 'WITH'`。養成每個陳述式都加 `;` 的習慣就沒事。

### 2.2 多個 CTE

用逗號串起來，後面的 CTE 可以引用前面的 CTE：

```sql
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
```

這種「一層一層往上疊」的寫法，比把三、四個子查詢塞在同一行好讀得多。

### 2.3 遞迴 CTE：自己引用自己

遞迴 CTE 的結構是：

1. **錨點成員**（anchor）：先產生第一列
2. `UNION ALL`
3. **遞迴成員**：引用 CTE 自己，直到找不到新列為止

```sql
-- 產生 2014 年 1～12 月，並統計每月訂單數（沒有訂單的月份也要顯示 0）
WITH Months AS (
	SELECT CAST('2014-01-01' AS DATE) AS MonthStart
	UNION ALL
	SELECT DATEADD(MONTH, 1, MonthStart)
	FROM Months
	WHERE MonthStart < CAST('2014-12-01' AS DATE)
)
SELECT
	m.MonthStart,
	DATEPART(MONTH, m.MonthStart) AS 月份,
	COUNT(o.OrderID) AS 訂單數
FROM Months AS m
LEFT JOIN dbo.Orders AS o
	ON o.OrderDate >= m.MonthStart
	AND o.OrderDate < DATEADD(MONTH, 1, m.MonthStart)
GROUP BY m.MonthStart
ORDER BY m.MonthStart
OPTION (MAXRECURSION 12);
```

重點：

- 遞迴成員的停止條件寫在 `WHERE`，不要寫成無窮迴圈
- 預設最多遞迴 100 次，超過會報錯；可用 `OPTION (MAXRECURSION n)` 調整，`0` 代表不限
- `DATEADD`／`DATEPART`／`DATEFROMPARTS`／`EOMONTH` 都是 SQL Server 2012 起可用，2014 沒問題
- 遞迴 CTE 很適合「日期維度」「組織樹」「BOM 展開」；一般分組查詢不需要它

### 2.4 CTE 不是暫存表

這是新手最常誤解的地方：

- CTE 只是**一段查詢的別名**，不是實體資料表，不會自動建索引
- 同一個 CTE 被引用兩次，通常會被執行兩次（除非引擎自己優化）
- CTE 只存活到「下一個陳述式」結束，不能跨 `GO`、不能給下一個查詢用
- 需要重複使用、加索引、跨批次時，才考慮暫存表（`#temp`，Day 4 會講）

### 2.5 CTE + UPDATE／DELETE（預告）

CTE 也可以包住要修改的資料，讓 `UPDATE`／`DELETE` 的條件更好讀：

```sql
WITH Target AS (
	SELECT TOP (3) *
	FROM dbo.Products
	WHERE Category = N'零食'
	ORDER BY UnitPrice
)
UPDATE Target
SET UnitPrice = UnitPrice * 1.05;
```

這種寫法很好用，但**執行前一定要先用同樣的 CTE 做 `SELECT` 確認範圍**，
並放在交易裡（下一節）。

---

## 3. 型別轉換與 NULL 再深入

### 3.1 CAST 與 CONVERT

```sql
SELECT
	CAST(123.456 AS DECIMAL(10,2)) AS 用CAST,
	CONVERT(DECIMAL(10,2), 123.456) AS 用CONVERT,
	CONVERT(VARCHAR(10), CAST('2014-07-01' AS DATE), 112) AS 日期轉字串;
```

- `CAST(值 AS 型別)` 是標準 SQL 寫法，優先使用
- `CONVERT(型別, 值, style)` 是 T-SQL 擴充，日期格式靠第三個參數（`112` = `YYYYMMDD`）
- 字串轉數字、數字轉字串都會發生；轉換失敗會讓整個查詢報錯

### 3.2 TRY_CAST／TRY_CONVERT：轉換失敗回 NULL

SQL Server 2012 起提供「安全版」轉換：

```sql
SELECT
	TRY_CAST('abc' AS INT) AS 轉不成是NULL,
	TRY_CAST('123' AS INT) AS 轉得成,
	TRY_CONVERT(DATE, '2014-13-40') AS 不合法的日期;
```

- `CAST('abc' AS INT)` 會直接報錯；`TRY_CAST` 回傳 NULL
- 適合清理外部匯入資料：先 `TRY_CAST`，再把 NULL 挑出來檢查
- 不要用 `TRY_CAST` 掩蓋資料品質問題；轉成 NULL 後還是要處理

### 3.3 隱含轉換：T-SQL 比 SQLite 嚴格

```sql
-- SQLite 可能讓你這樣比；SQL Server 會報錯
SELECT * FROM dbo.Products WHERE ProductName > 5;

-- 這個可以跑，但 '10' 會被轉成 INT 再比
SELECT CASE WHEN '10' > 5 THEN N'是' ELSE N'否' END;
```

規則：**資料型別有優先權**，優先權低的會被轉成優先權高的。`INT` 比 `VARCHAR` 高，
所以字串被轉成數字；如果字串不是數字，就報錯。

另一個常見坑是 `NVARCHAR` 欄位和 `VARCHAR` 字面值比較：

```sql
-- 欄位是 NVARCHAR，字面值沒加 N → 可能把欄位轉成 VARCHAR，索引失效、中文亂碼
WHERE ProductName = '鐵觀音茶葉'

-- 正確：加 N
WHERE ProductName = N'鐵觀音茶葉'
```

### 3.4 ISNULL 與 COALESCE

```sql
SELECT
	ISNULL(Phone, N'未提供') AS 用ISNULL,
	COALESCE(Phone, N'未提供') AS 用COALESCE
FROM dbo.Customers;
```

| | `ISNULL` | `COALESCE` |
|---|---|---|
| 參數數量 | 只能 2 個 | 可以多個 |
| 標準 | T-SQL 專有 | SQL 標準 |
| 回傳型別 | **第一個參數**的型別 | 參數中優先權最高的型別 |
| 適用 | 快速補值 | 跨資料庫、多層補值 |

型別差異的實際影響：

```sql
DECLARE @s VARCHAR(5) = NULL;
SELECT
	ISNULL(@s, N'這是一段很長的字串') AS 被截斷,	-- VARCHAR(5)，只剩前 5 個字
	COALESCE(@s, N'這是一段很長的字串') AS 完整;	-- NVARCHAR，完整保留
```

新專案優先使用 `COALESCE`；效能上兩者幾乎相同，但 `COALESCE` 語意更清楚。

### 3.5 字串串接：+ 與 CONCAT

```sql
-- +：任何一端是 NULL，整個結果變 NULL
SELECT CompanyName + N'（' + Phone + N'）' AS info
FROM dbo.Customers;

-- CONCAT：NULL 會被當成空字串（SQL Server 2012 起）
SELECT CONCAT(CompanyName, N'（', Phone, N'）') AS info
FROM dbo.Customers;
```

需要「NULL 顯示成未提供」時，兩者可以混用：

```sql
SELECT CONCAT(CompanyName, N'（', COALESCE(Phone, N'未提供'), N'）') AS info
FROM dbo.Customers;
```

### 3.6 日期字面值

```sql
-- 安全：明確轉成 DATE
WHERE OrderDate >= CAST('2014-07-01' AS DATE)
	AND OrderDate < CAST('2015-01-01' AS DATE)

-- 也安全：YYYYMMDD 是 SQL Server 的唯一不受語言設定影響的數字格式
WHERE OrderDate >= '20140701'
	AND OrderDate < '20150101'
```

避免 `'01/07/2014'` 這種寫法：不同 `DATEFORMAT`／語言設定會解讀成不同日期。

---

## 4. DML 安全實務：INSERT／UPDATE／DELETE

Day 1～3 前半都在「讀」；現在開始「寫」。寫錯 `WHERE` 的代價比查錯資料高得多，
所以先把流程固定下來。

### 4.1 安全流程（背下來）

```text
1. 用 SELECT + 同樣的 WHERE 確認影響範圍
2. BEGIN TRANSACTION
3. 執行 INSERT／UPDATE／DELETE
4. 用 SELECT 驗證結果、檢查 @@ROWCOUNT
5. 正確 → COMMIT；不正確 → ROLLBACK
```

口訣：**先看、再改、可回滾、後驗證。**

### 4.2 INSERT

```sql
-- 單筆：一定要寫欄位清單（Identity 欄位不要寫）
INSERT INTO dbo.Customers (CompanyName, ContactName, Phone, City)
VALUES (N'測試客戶', N'測試聯絡人', N'02-0000-0000', N'台北');

-- 多筆
INSERT INTO dbo.Products (ProductName, Category, UnitPrice, Discontinued)
VALUES
	(N'測試商品A', N'測試', 100.00, 0),
	(N'測試商品B', N'測試', 200.00, 0);

-- 從查詢結果插入（先確認 SELECT 的欄位數與型別）
INSERT INTO dbo.Products (ProductName, Category, UnitPrice, Discontinued)
SELECT ProductName + N'（複本）', Category, UnitPrice, 1
FROM dbo.Products
WHERE Category = N'文具';
```

**取得剛產生的 Identity：**

```sql
INSERT INTO dbo.Customers (CompanyName, City)
VALUES (N'新客戶', N'台南');

SELECT SCOPE_IDENTITY() AS 新客戶編號;
```

| 函式 | 範圍 | 建議 |
|------|------|------|
| `SCOPE_IDENTITY()` | 目前 scope（同一批次／預存程序） | **優先使用** |
| `@@IDENTITY` | 整個連線的最後一個 Identity | 會被 trigger 影響，不要用 |
| `IDENT_CURRENT('表')` | 整個資料庫、指定表的最後一個 Identity | 多使用者時不可靠 |

**OUTPUT：直接把新增的列印出來**

```sql
INSERT INTO dbo.Customers (CompanyName, City)
OUTPUT inserted.CustomerID, inserted.CompanyName
VALUES (N'新客戶', N'台南');
```

### 4.3 UPDATE

```sql
-- 錯誤示範：忘記 WHERE，全表被改
UPDATE dbo.Products SET UnitPrice = UnitPrice * 1.1;

-- 正確：先用 SELECT 確認
SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products
WHERE Category = N'零食';

UPDATE dbo.Products
SET UnitPrice = UnitPrice * 1.1
WHERE Category = N'零食';

SELECT @@ROWCOUNT AS 受影響筆數;	-- 立刻檢查，別插入其他陳述式
```

**UPDATE + JOIN：**

```sql
-- 把台北客戶的訂單運費 NULL 補成 100
UPDATE o
SET o.ShipFee = 100.00
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c ON o.CustomerID = c.CustomerID
WHERE c.City = N'台北'
	AND o.ShipFee IS NULL;
```

**UPDATE + CTE：**

```sql
WITH Target AS (
	SELECT TOP (3) *
	FROM dbo.Products
	WHERE Category = N'零食'
	ORDER BY UnitPrice
)
UPDATE Target SET UnitPrice = UnitPrice * 1.05;
```

⚠️ `TOP` 沒有 `ORDER BY` 時，取哪幾筆不保證；`UPDATE TOP (n)` 也一樣。
要精確控制範圍，先用 CTE／`ROW_NUMBER()` 把目標列挑好（Day 5）。

**UPDATE 的 `OUTPUT`：看舊值與新值**

```sql
UPDATE dbo.Products
SET UnitPrice = UnitPrice * 1.1
OUTPUT
	deleted.ProductID,
	deleted.UnitPrice AS 舊價,
	inserted.UnitPrice AS 新價
WHERE Category = N'零食';
```

### 4.4 DELETE

```sql
-- 先 SELECT 確認
SELECT * FROM dbo.Orders WHERE OrderID = 999;

-- 再刪
DELETE FROM dbo.Orders WHERE OrderID = 999;
```

規則：

- **沒有 `WHERE` 的 `DELETE` 會刪光整張表**；SQL Server 沒有「安全更新模式」會阻止你
- 有外鍵參考時，先刪子表（`OrderDetails`）再刪父表（`Orders`），否則會報
  `The DELETE statement conflicted with the REFERENCE constraint`（錯誤 547）
- `ON DELETE CASCADE` 可以自動刪子表，但風險高；公司既有 schema 通常不會開，先看清楚
- `TRUNCATE TABLE` 更快、會重設 Identity，但**不能加 WHERE**、遇到外鍵會失敗；正式環境少用
- 實務上常用「軟刪除」：加 `IsDeleted` 欄位，查詢時過濾，而不是真的刪資料

**DELETE + JOIN：**

```sql
DELETE d
FROM dbo.OrderDetails AS d
INNER JOIN dbo.Orders AS o ON d.OrderID = o.OrderID
WHERE o.OrderDate < CAST('2014-01-01' AS DATE);
```

### 4.5 MERGE：更新或新增一次完成

`MERGE` 依「配對得到／配對不到」決定 `UPDATE`／`INSERT`：

```sql
MERGE dbo.Products AS t
USING (
	SELECT N'進口耳機' AS ProductName, CAST(1100.00 AS DECIMAL(10,2)) AS UnitPrice
	UNION ALL
	SELECT N'藍牙喇叭', CAST(990.00 AS DECIMAL(10,2))
) AS s
	ON t.ProductName = s.ProductName
WHEN MATCHED THEN
	UPDATE SET t.UnitPrice = s.UnitPrice
WHEN NOT MATCHED THEN
	INSERT (ProductName, Category, UnitPrice, Discontinued)
	VALUES (s.ProductName, N'電子', s.UnitPrice, 0)
OUTPUT $action AS 動作, inserted.ProductID, inserted.ProductName, inserted.UnitPrice;
```

- `MERGE` 在 SQL Server 2008 起就有，2014 可用
- 它有一些已知的併發問題；實務上會在目標表加 `WITH (HOLDLOCK)`，並在交易中執行
- 能用簡單的 `INSERT`／`UPDATE` 分開寫清楚時，不一定要用 `MERGE`
- `OUTPUT $action` 會顯示 `INSERT`／`UPDATE`／`DELETE`

### 4.6 用交易包裹（Day 4 預習）

```sql
SET XACT_ABORT ON;		-- 發生執行期錯誤時自動回滾整個交易

BEGIN TRANSACTION;

UPDATE dbo.Products
SET UnitPrice = UnitPrice * 1.1
WHERE Category = N'零食';

-- 驗證：筆數、金額範圍、關鍵列
SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products
WHERE Category = N'零食';

-- 沒問題才 COMMIT；不確定就 ROLLBACK
ROLLBACK TRANSACTION;
```

- `SET XACT_ABORT ON` 是「腳本」的好朋友：錯誤發生時不會留下半套交易
- `@@TRANCOUNT` 可以知道目前有幾層交易；`ROLLBACK` 會把整個交易回滾
- 在 `sqlcmd` 裡，交易可以跨 `GO`；連線中斷時 SQL Server 會自動回滾未提交的交易
- **不要**在交易裡等待使用者輸入、做網頁 request、或執行很久的報表

### 4.7 正式環境的自我保護

- 用**只具備必要權限**的帳號：應用程式帳號通常不需要 `db_owner`
- 修改前先備份或確認有資料庫備份；大量更新先分批（例如每次 1000 筆）
- 腳本進版控、有人 review；不要在正式環境直接開互動式視窗「試一下」
- 先用 `SELECT` 驗證，再包交易；`UPDATE`／`DELETE` 的 `WHERE` 一定要有索引支撐
  （否則可能鎖住大量資料，Day 4 會講）
- 應用程式碼一律用**參數化查詢**，不要字串拼接（Day 5 會示範 SQL injection）

---

## 5. 接下來

做完 `exercises.sql`。第 10 題以後會實際執行 `INSERT`／`UPDATE`／`DELETE`，
但每一題都包在交易裡並在結尾 `ROLLBACK`，**不會留下資料變更**。

明天 Day 4：交易與隔離級別、索引與執行計畫、變數與流程控制——把今天「會寫」的 DML
變成「寫得安全、跑得快」。
