# Day 5：視窗函數、實務食譜與 C# 串接

建議時間分配（約 4.5 小時）：

| 時間 | 內容 |
|------|------|
| 60 分 | 視窗函數：`OVER`、排名、位移、聚合視窗 |
| 50 分 | 實務食譜：Top N per group、累計、占比、分頁、字串聚合 |
| 60 分 | C# 連線：`Microsoft.Data.SqlClient`、參數化、例外處理 |
| 50 分 | Dapper 與 EF Core：三種存取方式的取捨 |
| 其餘 | 做 `exercises.sql` |

---

## 1. 視窗函數：不摺疊資料列的聚合

Day 2 的 `GROUP BY` 會把多列「摺疊」成一列；視窗函數（window function）則是**保留每一列**，
在旁邊多算一個「跨列」的數值：

```sql
SELECT
	CustomerID,
	OrderID,
	OrderDate,
	COUNT(*) OVER (PARTITION BY CustomerID) AS 該客戶訂單數
FROM dbo.Orders
WHERE OrderDate < CAST('2015-01-01' AS DATE);
```

`OVER (...)` 定義「看哪一個窗口」：

| 子句 | 意思 | 例子 |
|------|------|------|
| `PARTITION BY` | 分組，但**不摺疊** | 每位客戶各自算 |
| `ORDER BY` | 窗口內的排序，決定累計方向 | 依日期累計 |
| `ROWS`／`RANGE` | 窗口範圍（frame） | 最近 3 筆、從頭到目前 |

口訣：**GROUP BY 摺疊、OVER 不摺疊。**

### 1.1 執行順序：為什麼不能寫在 WHERE

邏輯上的執行順序是：

```text
FROM → WHERE → GROUP BY → HAVING → 視窗函數（SELECT）→ DISTINCT → ORDER BY → TOP
```

視窗函數在 `SELECT` 階段才算出來，所以：

```sql
-- 錯誤：WHERE 還看不到 ROW_NUMBER()
SELECT OrderID, ROW_NUMBER() OVER (ORDER BY OrderDate) AS rn
FROM dbo.Orders
WHERE ROW_NUMBER() OVER (ORDER BY OrderDate) <= 3;
```

正確做法是包一層 CTE 或子查詢：

```sql
WITH Numbered AS (
	SELECT
		OrderID,
		OrderDate,
		ROW_NUMBER() OVER (ORDER BY OrderDate) AS rn
	FROM dbo.Orders
	WHERE OrderDate < CAST('2015-01-01' AS DATE)
)
SELECT OrderID, OrderDate, rn
FROM Numbered
WHERE rn <= 3;
```

`ORDER BY` 則可以引用視窗函數的別名（`ORDER BY rn`），因為它比 `SELECT` 晚執行。

---

## 2. 排名函數：ROW_NUMBER／RANK／DENSE_RANK／NTILE

這四個函數都用 `OVER (PARTITION BY ... ORDER BY ...)`，差別在「同名次」怎麼處理：

| 函數 | 並列時 | 下一個名次 | 例子（分數 100, 100, 90） |
|------|--------|------------|---------------------------|
| `ROW_NUMBER()` | 隨機（不保證誰先） | 連續 | 1, 2, 3 |
| `RANK()` | 同名次 | **跳號** | 1, 1, 3 |
| `DENSE_RANK()` | 同名次 | **不跳號** | 1, 1, 2 |
| `NTILE(n)` | 平均切成 n 桶 | — | 依排序分桶 |

```sql
SELECT
	CustomerID,
	COUNT(*) AS 訂單數,
	ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn,
	RANK()       OVER (ORDER BY COUNT(*) DESC) AS rnk,
	DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS dense_rnk,
	NTILE(3)     OVER (ORDER BY COUNT(*) DESC) AS 三等分
FROM dbo.Orders
WHERE OrderDate < CAST('2015-01-01' AS DATE)
GROUP BY CustomerID;
```

重點：

- 排名函數的 `ORDER BY` 可以放聚合結果（`COUNT(*)`），因為 `GROUP BY` 先發生
- `ROW_NUMBER()` 遇到並列時**不保證**誰拿到 1、誰拿到 2；要穩定結果，排序鍵必須唯一
  （例如再補 `, OrderID`）
- `RANK`／`DENSE_RANK` 的差異只在「並列後面怎麼接」
- `NTILE` 的每一桶大小最多差 1；資料筆數不能被 n 整除時，前面的桶會多一筆
- 排名函數不能用在 `WHERE`，要包 CTE／子查詢（見 1.1）

### 2.1 Top N per group 的標準寫法

「每個類別最貴的前 2 個產品」不能直接 `TOP (2)`（那只會取全表前 2 筆），
標準解法是 `PARTITION BY` + `ROW_NUMBER()`：

```sql
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
```

- `ORDER BY` 加上 `ProductID` 是為了「同價時結果穩定」
- 若要「同價並列都入選」，把 `ROW_NUMBER()` 換成 `RANK()` 或 `DENSE_RANK()`
  （並列時可能超過 N 筆）
- SQL Server 2014 沒有 `QUALIFY`（BigQuery／Snowflake 的語法），一定要包一層

---

## 3. 位移函數：LAG／LEAD／FIRST_VALUE／LAST_VALUE

### 3.1 LAG／LEAD：拿前一列、後一列

```sql
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
	營業額 - LAG(營業額) OVER (ORDER BY 月份) AS 月增減
FROM MonthlyRevenue
ORDER BY 月份;
```

- `LAG(運算式, 偏移量, 預設值)`：預設偏移量 1、預設值 NULL
- 第一列沒有「上一列」，所以 `LAG` 回傳 NULL；用第三個參數補 0 也可以
- `LEAD` 相反，往下看
- 這是算「月成長率」「與前一筆的差距」「相鄰事件間隔」的標準工具

### 3.2 FIRST_VALUE／LAST_VALUE：窗口的第一列、最後一列

```sql
SELECT
	o.OrderID,
	o.CustomerID,
	o.OrderDate,
	FIRST_VALUE(o.OrderDate) OVER (
		PARTITION BY o.CustomerID
		ORDER BY o.OrderDate
	) AS 該客戶首張訂單日,
	LAST_VALUE(o.OrderDate) OVER (
		PARTITION BY o.CustomerID
		ORDER BY o.OrderDate
		ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
	) AS 該客戶末張訂單日
FROM dbo.Orders AS o
WHERE o.OrderDate < CAST('2015-01-01' AS DATE);
```

⚠️ `LAST_VALUE` 的預設 frame 只到「目前這一列」，直接寫會得到「自己」。
要取整個 partition 的最後一列，必須明寫
`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`。
`FIRST_VALUE` 的預設 frame 剛好是從頭開始，所以不用改。

---

## 4. 聚合視窗：累計、移動平均、占比

聚合函數（`SUM`／`AVG`／`COUNT`／`MIN`／`MAX`）加上 `OVER` 就變成視窗版：

```sql
-- 1) 全域總額：每一列都附上同一個數字
SUM(d.Quantity * d.UnitPrice) OVER () AS 全部營業額

-- 2) 分組總額：每列附上「該客戶」的總額
SUM(d.Quantity * d.UnitPrice) OVER (PARTITION BY o.CustomerID) AS 該客戶總額

-- 3) 累計：依日期從頭加到目前這一列
SUM(d.Quantity * d.UnitPrice) OVER (
	ORDER BY o.OrderDate, o.OrderID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS 累計營業額
```

### 4.1 ROWS 與 RANGE 的差異（重要）

有 `ORDER BY` 但沒寫 frame 時，預設是：

```text
RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

`RANGE` 會把**排序鍵相同的列視為同一組**。例如兩張訂單同一天，累計時這兩列會拿到
相同的累計值（一起加）；`ROWS` 則嚴格一列一列加。

```sql
-- 同一日期會被視為同一組（預設 RANGE）
SUM(Amount) OVER (ORDER BY OrderDate) AS 累計_RANGE

-- 嚴格逐列累計（建議明寫）
SUM(Amount) OVER (
	ORDER BY OrderDate, OrderID
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS 累計_ROWS
```

規則：**做累計時明寫 `ROWS`，並把排序鍵補到唯一（例如再加主鍵）。**

### 4.2 移動平均

```sql
-- 最近 3 筆（含目前）的移動平均
AVG(Amount) OVER (
	ORDER BY OrderDate, OrderID
	ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
) AS 三筆移動平均
```

frame 的常見組合：

| frame | 意思 |
|-------|------|
| `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | 從頭到目前（累計） |
| `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` | 最近 3 筆（含目前） |
| `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING` | 前後各 1 筆（共 3 筆） |
| `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` | 整個 partition |

### 4.3 占比

```sql
SELECT
	o.OrderID,
	o.CustomerID,
	SUM(d.Quantity * d.UnitPrice) AS 訂單金額,
	CAST(
		100.0 * SUM(d.Quantity * d.UnitPrice)
			/ SUM(SUM(d.Quantity * d.UnitPrice)) OVER (PARTITION BY o.CustomerID)
		AS DECIMAL(10,2)
	) AS 占客戶百分比
FROM dbo.Orders AS o
INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
GROUP BY o.OrderID, o.CustomerID;
```

這裡有兩個層次：

- `SUM(d.Quantity * d.UnitPrice)`：`GROUP BY` 後的每張訂單金額
- `SUM(SUM(...)) OVER (PARTITION BY ...)`：把「每張訂單金額」再加總一次，當分母

`SUM(SUM(x)) OVER (...)` 看起來很奇怪，但這是合法的：內層 `SUM` 先做聚合，
外層 `SUM ... OVER` 再做視窗聚合。也可以先包 CTE 再算，可讀性更好。

⚠️ 整數相除會截斷，所以先乘 `100.0`（或 `CAST(... AS DECIMAL)`）再除。

---

## 5. 實務食譜

### 5.1 取每組最新一筆

```sql
-- 每位客戶最近一張訂單
WITH Ranked AS (
	SELECT
		o.OrderID,
		o.CustomerID,
		o.OrderDate,
		ROW_NUMBER() OVER (
			PARTITION BY o.CustomerID
			ORDER BY o.OrderDate DESC, o.OrderID DESC
		) AS rn
	FROM dbo.Orders AS o
)
SELECT OrderID, CustomerID, OrderDate
FROM Ranked
WHERE rn = 1;
```

這比 `GROUP BY CustomerID + MAX(OrderDate)` 再回去 join 更簡單，也不會因為同一天兩張單
而多出資料列。

### 5.2 去除重複，只留一筆

```sql
WITH Ranked AS (
	SELECT
		*,
		ROW_NUMBER() OVER (
			PARTITION BY CompanyName
			ORDER BY CustomerID
		) AS rn
	FROM dbo.Customers
)
SELECT *
FROM Ranked
WHERE rn = 1;
```

`PARTITION BY` 放「你認為重複的欄位」，`ORDER BY` 放「想保留哪一筆」的規則。

### 5.3 分頁：OFFSET／FETCH

```sql
SELECT OrderID, OrderDate
FROM dbo.Orders
ORDER BY OrderDate DESC, OrderID DESC
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;
```

- SQL Server 2012 起支援，2014 沒問題
- **一定要有 `ORDER BY`**，否則語法錯誤
- `OFFSET` 越大越慢（要跳過前面的列）；深度分頁改用「記住上一頁最後一個鍵」的
  key-set pagination

### 5.4 TOP WITH TIES

```sql
-- 取金額最高的前 3 名，同分一併列出
SELECT TOP (3) WITH TIES
	o.OrderID,
	SUM(d.Quantity * d.UnitPrice) AS 訂單金額
FROM dbo.Orders AS o
INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
WHERE o.OrderDate < CAST('2015-01-01' AS DATE)
GROUP BY o.OrderID
ORDER BY 訂單金額 DESC;
```

`WITH TIES` 必須搭配 `ORDER BY`；同分可能回傳超過 N 筆。

### 5.5 ⚠️ 字串聚合：2014 沒有 STRING_AGG

`STRING_AGG` 是 SQL Server 2017 才有。2014 的常見替代方案是 `FOR XML PATH`：

```sql
SELECT
	c.City,
	STUFF((
		SELECT N'、' + c2.CompanyName
		FROM dbo.Customers AS c2
		WHERE c2.City = c.City
		ORDER BY c2.CompanyName
		FOR XML PATH(''), TYPE
	).value('.', 'NVARCHAR(MAX)'), 1, 1, N'') AS 客戶清單
FROM dbo.Customers AS c
GROUP BY c.City;
```

- `STUFF(..., 1, 1, N'')` 是把開頭多的分隔符號去掉
- `.value('.', 'NVARCHAR(MAX)')` 把 XML 轉回字串，避免 `&`、`<` 被轉義
- 這段語法很醜，但 2014 沒有更好的內建寫法（除非用 CLR 或自訂聚合）
- 若之後升級到 2017+，直接換成 `STRING_AGG(CompanyName, N'、')`

### 5.6 月成長率

```sql
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
	LAG(營業額) OVER (ORDER BY 月份) AS 上月,
	CAST(
		100.0 * (營業額 - LAG(營業額) OVER (ORDER BY 月份))
			/ NULLIF(LAG(營業額) OVER (ORDER BY 月份), 0)
		AS DECIMAL(10,2)
	) AS 成長率百分比
FROM MonthlyRevenue
ORDER BY 月份;
```

- `NULLIF(分母, 0)` 避免除以零
- 第一個月沒有上月，成長率是 NULL（不是 0）
- 百分比欄位用 `DECIMAL` 明確轉型，避免顯示一長串小數

### 5.7 執行計畫與效能

視窗函數通常需要**排序**（`ORDER BY`）或**雜湊**（`PARTITION BY`）：

- 每次 `OVER` 的 `PARTITION BY`／`ORDER BY` 組合都可能是獨立的 sort
- 若查詢已經有適合的索引（例如 `(CustomerID, OrderDate)`），排序成本可能消失
- 多個視窗函數若排序方式相同，最佳化工具有機會共用一次排序
- 在 `WHERE` 前先用 CTE 過濾掉不需要的列，再算視窗，通常比先算全部再過濾便宜
- 排名函數用在**大結果集**上很吃記憶體；能先聚合就先聚合

`SET STATISTICS IO ON` 與執行計畫仍是主要觀察工具（Day 4）。

---

## 6. C# 串接：三種常見方式

> 本節只提供可複製的程式碼片段，**不建立專案**。動機是讓你知道實務上怎麼安全地
> 呼叫這幾天寫的 SQL，以及每種方式的適用情境。

| 方式 | 適合 | 特性 |
|------|------|------|
| `Microsoft.Data.SqlClient` | 效能敏感、需要完整控制 | 最底層、最繁瑣，但沒有魔法 |
| Dapper | 查詢多、想要 SQL 控制權 | 輕量 ORM，SQL 自己寫，物件映射自動 |
| EF Core | CRUD 多、需要變更追蹤與模型 | 生產力高，但查詢可能較難預測 |

三者都走同一組連線字串與 ADO.NET 底層；EF Core 與 Dapper 都是站在
`Microsoft.Data.SqlClient` 上面。

### 6.1 連線字串

```csharp
const string ConnectionString =
	"Server=localhost\\SQLEXPRESS;Database=learning_db;" +
	"Integrated Security=True;Encrypt=False;";
```

- `localhost\\SQLEXPRESS` 在 C# 字串裡要寫成 `\\`（或在 `@""` 字串裡寫 `\`）
- `Integrated Security=True` 是 Windows 驗證；SQL 驗證要改 `User ID=...;Password=...`
- **`Microsoft.Data.SqlClient` 4.0 起預設 `Encrypt=True`**；本機自簽憑證會連不上，
  開發環境可加 `Encrypt=False`（或 `TrustServerCertificate=True`）。正式環境請用
  正確憑證，不要關閉加密
- 連線字串不要寫死在程式碼；用環境變數／使用者密鑰（user-secrets）／Key Vault
- 連線字串用 `SqlConnectionStringBuilder` 組合，避免手動跳脫錯誤：

```csharp
var builder = new SqlConnectionStringBuilder {
	DataSource = @"localhost\SQLEXPRESS",
	InitialCatalog = "learning_db",
	IntegratedSecurity = true,
	Encrypt = false,
};
var connectionString = builder.ConnectionString;
```

### 6.2 Microsoft.Data.SqlClient：參數化查詢

```csharp
using System.Data;
using Microsoft.Data.SqlClient;

public static async Task<List<(int OrderId, string Company, DateTime OrderDate, decimal Total)>>
	GetOrdersAsync(string city, CancellationToken ct)
{
	var rows = new List<(int OrderId, string Company, DateTime OrderDate, decimal Total)>();

	const string sql = """
		SELECT
			o.OrderID,
			c.CompanyName,
			o.OrderDate,
			SUM(d.Quantity * d.UnitPrice) AS OrderTotal
		FROM dbo.Orders AS o
		INNER JOIN dbo.Customers AS c ON c.CustomerID = o.CustomerID
		INNER JOIN dbo.OrderDetails AS d ON d.OrderID = o.OrderID
		WHERE c.City = @City
		GROUP BY o.OrderID, c.CompanyName, o.OrderDate
		ORDER BY o.OrderDate DESC, o.OrderID DESC;
		""";

	await using var connection = new SqlConnection(ConnectionString);
	await connection.OpenAsync(ct);

	await using var command = new SqlCommand(sql, connection);
	command.Parameters.Add("@City", SqlDbType.NVarChar, 50).Value = city;
	command.CommandTimeout = 30;

	await using var reader = await command.ExecuteReaderAsync(ct);
	while (await reader.ReadAsync(ct)) {
		rows.Add((
			reader.GetInt32(0),
			reader.GetString(1),
			reader.GetDateTime(2),
			reader.GetDecimal(3)));
	}

	return rows;
}
```

重點：

- **一律用參數**（`@City`），不要用字串插值把使用者輸入拼進 SQL
- `Add("@City", SqlDbType.NVarChar, 50)` 明確指定型別與長度，避免隱含轉換與計畫快取爆炸
- `await using`＋`OpenAsync`／`ReadAsync`：非同步且會歸還連線池
- 用序號取值（`GetInt32(0)`）最快，但欄位順序一改就錯；可改用 `reader.GetOrdinal("OrderID")`
- `ReadAsync` 回傳 `false` 表示沒有下一列
- 資料量很大時不要一次 `ToList()`；用 `IAsyncEnumerable` 串流

**呼叫預存程序與 OUTPUT 參數：**

```csharp
using System.Data;

int customerId = 1;

await using var command = new SqlCommand("dbo.usp_GetCustomerStats", connection) {
	CommandType = CommandType.StoredProcedure,
};

command.Parameters.Add("@CustomerID", SqlDbType.Int).Value = customerId;

var orderCount = new SqlParameter("@OrderCount", SqlDbType.Int) {
	Direction = ParameterDirection.Output,
};
var total = new SqlParameter("@Total", SqlDbType.Decimal) {
	Direction = ParameterDirection.Output,
	Precision = 12,
	Scale = 2,
};
command.Parameters.Add(orderCount);
command.Parameters.Add(total);

await command.ExecuteNonQueryAsync(ct);

var count = orderCount.Value is int c ? c : 0;
var amount = total.Value is decimal m ? m : 0m;
```

OUTPUT 參數回來可能是 `DBNull.Value`，一定要做型別檢查，不要直接 `(int)` 強制轉型。

### 6.3 SQL injection：參數化 vs 字串拼接

```csharp
// 千萬不要：使用者輸入直接進 SQL
var sql = $"SELECT * FROM dbo.Customers WHERE CompanyName = N'{companyName}'";
```

如果 `companyName` 是 `' OR 1=1 --`，整段 `WHERE` 就失效。參數化之後，
輸入永遠只會被當成「一個字串值」：

```csharp
const string sql = "SELECT CustomerID, CompanyName FROM dbo.Customers WHERE CompanyName = @CompanyName";
command.Parameters.Add("@CompanyName", SqlDbType.NVarChar, 100).Value = companyName;
```

不能參數化的部分（資料表名、欄位名、排序方向）要用**白名單**：

```csharp
private static readonly HashSet<string> AllowedSortColumns =
	new(StringComparer.OrdinalIgnoreCase) { "OrderDate", "OrderID", "Total" };

if (!AllowedSortColumns.Contains(sortColumn))
	throw new ArgumentException("不合法的排序欄位", nameof(sortColumn));

var sql = $"""
	SELECT OrderID, OrderDate
	FROM dbo.Orders
	ORDER BY {sortColumn}
	OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
	""";
```

即使是白名單，`sortColumn` 也應該是「程式內固定的字串」，不要直接把使用者輸入塞進來。

### 6.4 SqlException：常見錯誤碼與處理

```csharp
using Microsoft.Data.SqlClient;

try {
	await command.ExecuteNonQueryAsync(ct);
} catch (SqlException ex) when (ex.Number == 1205) {
	// 死結犧牲者：可以重試整個交易
	throw new InvalidOperationException("資料忙碌中，請稍後重試", ex);
} catch (SqlException ex) when (ex.Number is 2601 or 2627) {
	// 唯一鍵重複：轉成商業邏輯的「資料已存在」
	throw new InvalidOperationException("資料已存在", ex);
} catch (SqlException ex) when (ex.Number == 547) {
	// 外鍵／CHECK 違反：通常是呼叫端給了不存在的關聯
	throw new ArgumentException("關聯資料不存在或違反條件約束", ex);
} catch (SqlException ex) {
	// 其他資料庫錯誤：記錄 ex.Number、ex.Message、ex.Procedure
	throw;
}
```

常見編號：

| 編號 | 意思 | 建議處理 |
|------|------|----------|
| 1205 | 死結犧牲者 | 重試（有次數上限與退避） |
| 1222 | 鎖定逾時 | 重試或回報使用者 |
| 2601／2627 | 唯一索引／主鍵重複 | 視為「已存在」，不要直接 500 |
| 547 | 外鍵或 CHECK 違反 | 回 400，提示哪個關聯不存在 |
| 208 | 物件不存在 | 部署或 schema 問題，不要吞掉 |
| 4060／18456 | 無法開啟資料庫／登入失敗 | 設定或權限問題 |
| -2 | `CommandTimeout` 逾時 | 查詢太慢或阻塞，先看計畫 |

`SqlException.Errors` 可能包含多個錯誤，`ex.Number` 是第一個；需要完整清單時逐一走訪。

### 6.5 Dapper：SQL 自己寫，映射自動做

```csharp
using Dapper;
using Microsoft.Data.SqlClient;

public sealed record CustomerOrderRow(
	int OrderID,
	string CompanyName,
	DateTime OrderDate,
	decimal OrderTotal);

public static async Task<IReadOnlyList<CustomerOrderRow>> GetRecentOrdersAsync(
	DateTime from, CancellationToken ct)
{
	const string sql = """
		SELECT
			o.OrderID,
			c.CompanyName,
			o.OrderDate,
			SUM(d.Quantity * d.UnitPrice) AS OrderTotal
		FROM dbo.Orders AS o
		INNER JOIN dbo.Customers AS c ON c.CustomerID = o.CustomerID
		INNER JOIN dbo.OrderDetails AS d ON d.OrderID = o.OrderID
		WHERE o.OrderDate >= @From
		GROUP BY o.OrderID, c.CompanyName, o.OrderDate
		ORDER BY o.OrderDate DESC, o.OrderID DESC;
		""";

	await using var connection = new SqlConnection(ConnectionString);
	var rows = await connection.QueryAsync<CustomerOrderRow>(
		new CommandDefinition(sql, new { From = from }, cancellationToken: ct));

	return rows.AsList();
}
```

- 參數用匿名物件 `new { From = from }`，Dapper 會自動建立 `@From` 參數
- 欄位別名要與屬性名稱一致（大小寫通常不敏感，但建議一致）
- `QuerySingleOrDefaultAsync`／`QueryFirstOrDefaultAsync`／`ExecuteAsync`／`QueryMultiple` 是常用 API
- 多表一次查回（multi-mapping）用 `QueryAsync<T1, T2, TResult>` 加 `splitOn`
- Dapper 不會幫你檢查 SQL 是否合法；Schema 改動時不會有編譯錯誤
- `CommandDefinition` 可以帶 `CancellationToken`、`transaction`、`commandTimeout`

**Dapper + 交易：**

```csharp
await using var connection = new SqlConnection(ConnectionString);
await connection.OpenAsync(ct);
await using var transaction = await connection.BeginTransactionAsync(ct);

try {
	await connection.ExecuteAsync(new CommandDefinition(
		"UPDATE dbo.Products SET UnitPrice = UnitPrice * 1.1 WHERE Category = @Category",
		new { Category = "零食" },
		transaction,
		cancellationToken: ct));

	await connection.ExecuteAsync(new CommandDefinition(
		"INSERT INTO dbo.AuditLog (Message) VALUES (@Message)",
		new { Message = "零食調漲 10%" },
		transaction,
		cancellationToken: ct));

	await transaction.CommitAsync(ct);
} catch {
	await transaction.RollbackAsync(ct);
	throw;
}
```

### 6.6 EF Core：模型與查詢

EF Core 站在 ADO.NET 上，幫你產生 SQL、追蹤變更、處理關聯。以下是接「既有資料庫」
（database-first 風格）的最小設定：

```csharp
using Microsoft.EntityFrameworkCore;

public sealed class Customer {
	public int CustomerId { get; set; }
	public string CompanyName { get; set; } = "";
	public string? City { get; set; }
}

public sealed class LearningDbContext : DbContext {
	public LearningDbContext(DbContextOptions<LearningDbContext> options) : base(options) { }

	public DbSet<Customer> Customers => Set<Customer>();

	protected override void OnModelCreating(ModelBuilder modelBuilder) {
		modelBuilder.Entity<Customer>(entity => {
			entity.ToTable("Customers", "dbo");
			entity.HasKey(c => c.CustomerId);
			entity.Property(c => c.CustomerId).HasColumnName("CustomerID");
			entity.Property(c => c.CompanyName).HasColumnName("CompanyName").HasMaxLength(100);
			entity.Property(c => c.City).HasColumnName("City").HasMaxLength(50);
		});
	}
}

// Program.cs / DI 設定
var options = new DbContextOptionsBuilder<LearningDbContext>()
	.UseSqlServer(ConnectionString, sql => sql.EnableRetryOnFailure())
	.Options;

await using var db = new LearningDbContext(options);

var customers = await db.Customers
	.AsNoTracking()
	.Where(c => c.City == "台北")
	.OrderBy(c => c.CompanyName)
	.Select(c => new { c.CustomerId, c.CompanyName })
	.ToListAsync(ct);
```

- `AsNoTracking()`：唯讀查詢不要追蹤變更，省記憶體也較快
- `Select` 只取需要的欄位，避免 `SELECT *`
- `EnableRetryOnFailure()` 會自動重試暫時性錯誤（但**不能**用在自訂交易裡，
  需搭配 `db.Database.CreateExecutionStrategy()`）
- EF Core 的 LINQ 不一定能翻成你想要的 SQL；用 `ToQueryString()` 看實際 SQL
- 需要手寫 SQL 時用 `FromSqlInterpolated`（會參數化）：

```csharp
var rows = await db.Customers
	.FromSqlInterpolated($"SELECT * FROM dbo.Customers WHERE City = {city}")
	.AsNoTracking()
	.ToListAsync(ct);
```

**EF Core 交易：**

```csharp
await using var transaction = await db.Database.BeginTransactionAsync(ct);

db.Products.Add(new Product { ProductName = "測試商品", Category = "測試", UnitPrice = 100m });
await db.SaveChangesAsync(ct);

await transaction.CommitAsync(ct);
```

EF Core 的 `SaveChanges` 本身是一個交易；只有「多個 `SaveChanges` 要一起成功／失敗」時
才需要外層交易。

### 6.7 三種方式怎麼選

| 情境 | 建議 |
|------|------|
| 複雜報表、視窗函數、效能調校 | `Microsoft.Data.SqlClient` 或 Dapper |
| 一般查詢＋物件映射，想控制 SQL | Dapper |
| 大量 CRUD、關聯、變更追蹤 | EF Core |
| 專案已用 EF Core，但某支查詢很慢 | 先用 `ToQueryString()` 看，再考慮 Dapper／手寫 SQL |
| 需要批次匯入 | `SqlBulkCopy`（三者都可搭配） |

實務上常見組合：**EF Core 負責 CRUD，Dapper／SqlClient 負責報表**。不要為了「純粹」
硬把複雜報表塞進 LINQ。

### 6.8 連線與資源管理檢查清單

- `SqlConnection` 用完就 `Dispose`／`await using`；連線池會重用，不要自己快取連線
- 非同步全程使用 `*Async` 與 `CancellationToken`
- 設定 `CommandTimeout`（預設 30 秒），避免查詢卡死執行緒
- 不要開啟 `MultipleActiveResultSets` 來掩蓋沒關 reader 的問題
- 大量資料用串流（`ReadAsync`）或分頁，不要一次載入記憶體
- 應用程式帳號只給必要權限（`db_datareader`／`db_datawriter`，必要時才 `EXECUTE`）
- 連線字串與密碼不進版控；用環境變數或密鑰管理
- 正式環境保持 `Encrypt=True` 並使用受信任憑證

---

## 7. 接下來

做完 `exercises.sql`。今天全部是查詢題，不會修改資料；答案檔的 `-- 預期：` 都對應
`seed.sql` 的 2014 年資料（動態日期的那 4 張訂單不列入，避免每次執行結果不同）。

完成後你已經走完 5 天：

- 會寫 SELECT、JOIN、聚合、子查詢、CTE、視窗函數
- 知道怎麼安全地 INSERT／UPDATE／DELETE，以及交易與索引的基本功
- 知道 C# 三種存取方式怎麼選、怎麼參數化、怎麼處理 `SqlException`

下一步建議：拿公司真正的一個報表需求，從 `SELECT` 開始寫，補上索引與執行計畫，
最後包成預存程序或 C# 查詢。真正的進步來自「改一個真實需求」，而不是再看一份教材。
