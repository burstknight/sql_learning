# Day 4：交易、隔離級別、索引與執行計畫、T-SQL 程式

建議時間分配（約 4.5 小時）：

| 時間 | 內容 |
|------|------|
| 60 分 | 交易、例外處理與死結 |
| 50 分 | 隔離級別與兩視窗 lab |
| 80 分 | 索引、SARGable 與執行計畫 |
| 70 分 | 變數、流程控制、預存程序、動態 SQL |
| 其餘 | 做 `exercises.sql` |

---

## 1. 交易：一組「要嘛全成功、要嘛全失敗」的操作

### 1.1 為什麼需要交易

想像轉帳：A 帳戶扣 100、B 帳戶加 100。如果只完成第一步就斷線，錢就消失了。
交易（transaction）把多個 DML 綁成一個單位，具備 ACID：

| 特性 | 意思 |
|------|------|
| Atomicity（原子性） | 全部成功或全部回滾，沒有半套 |
| Consistency（一致性） | 交易前後資料都符合規則（外鍵、CHECK 等） |
| Isolation（隔離性） | 同時進行的交易互不干擾（依隔離級別而定） |
| Durability（持久性） | `COMMIT` 之後即使斷電也還在 |

### 1.2 BEGIN／COMMIT／ROLLBACK

```sql
BEGIN TRANSACTION;

UPDATE dbo.Products
SET UnitPrice = UnitPrice * 1.1
WHERE Category = N'零食';

-- 檢查結果，確定沒錯才提交
SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products
WHERE Category = N'零食';

COMMIT TRANSACTION;
-- 有問題就改成 ROLLBACK TRANSACTION;
```

- `BEGIN TRANSACTION` 之後，變更只在目前連線可見（依隔離級別）
- `COMMIT` 才真正寫入；`ROLLBACK` 取消整個交易
- 連線中斷時，SQL Server 會自動回滾未提交的交易
- 交易可以跨 `GO`（sqlcmd 的批次分隔符不影響交易）

**`@@TRANCOUNT`：目前有幾層交易**

```sql
SELECT @@TRANCOUNT;	-- 0

BEGIN TRANSACTION;	-- 1
BEGIN TRANSACTION;	-- 2（巢狀，但沒有真正獨立的內層交易）

COMMIT TRANSACTION;	-- 1
ROLLBACK TRANSACTION;	-- 0，整個交易都回滾
```

巢狀交易的重點：

- 內層 `COMMIT` 只是把 `@@TRANCOUNT` 減 1，**不會真正寫入**
- 最外層 `COMMIT` 才真正提交
- 內層 `ROLLBACK` 會回滾**整個**交易（不是只回滾內層）
- 只想回滾一部分，用 `SAVE TRANSACTION`（見 1.3）

### 1.3 SAVE TRANSACTION：部分回滾

```sql
BEGIN TRANSACTION;

UPDATE dbo.Products SET UnitPrice = UnitPrice + 10 WHERE ProductID = 1;

SAVE TRANSACTION AfterFirstUpdate;

UPDATE dbo.Products SET UnitPrice = UnitPrice + 10 WHERE ProductID = 2;
-- 發現第二步不該做
ROLLBACK TRANSACTION AfterFirstUpdate;

-- 此時 ProductID 1 的更新還在，ProductID 2 的更新已取消
COMMIT TRANSACTION;
```

- `SAVE TRANSACTION` 建立一個保存點，不會改變 `@@TRANCOUNT`
- `ROLLBACK TRANSACTION 保存點名稱` 只回滾到保存點為止
- 保存點在實務上不常用；多數情況會把交易拆小，或用 `TRY/CATCH` 整個回滾

### 1.4 TRY/CATCH 與 THROW

SQL Server 2005 起支援 `TRY/CATCH`；2012 起支援 `THROW`。

```sql
SET XACT_ABORT ON;	-- 執行期錯誤發生時，自動把整個交易標記為無法提交

BEGIN TRY
	BEGIN TRANSACTION;

	INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipFee)
	VALUES (999, 1, CAST('2014-06-01' AS DATE), 50.00);	-- CustomerID 999 不存在

	COMMIT TRANSACTION;
END TRY
BEGIN CATCH
	IF XACT_STATE() <> 0
		ROLLBACK TRANSACTION;

	SELECT
		ERROR_NUMBER() AS 錯誤編號,
		ERROR_MESSAGE() AS 錯誤訊息,
		ERROR_SEVERITY() AS 嚴重性,
		ERROR_STATE() AS 狀態,
		ERROR_LINE() AS 發生行號;
END CATCH;
```

**`XACT_STATE()`：交易目前能不能提交**

| 回傳值 | 意思 | 動作 |
|--------|------|------|
| `1` | 交易仍可提交 | 可 `COMMIT` 或 `ROLLBACK` |
| `0` | 目前沒有交易 | 不用回滾 |
| `-1` | 交易已無法提交（doomed） | **只能 `ROLLBACK`** |

`XACT_ABORT ON` 讓大部分執行期錯誤直接把交易標成 `-1`；這時 `COMMIT` 會失敗，
一定要先 `ROLLBACK`。上面的 `IF XACT_STATE() <> 0 ROLLBACK` 就是標準收尾。

**THROW：主動丟出錯誤**

```sql
BEGIN TRY
	IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = 1)
		THROW 50001, N'找不到客戶', 1;

	SELECT N'客戶存在' AS 結果;
END TRY
BEGIN CATCH
	SELECT ERROR_NUMBER() AS 錯誤編號, ERROR_MESSAGE() AS 錯誤訊息;
END CATCH;
```

- `THROW 錯誤編號, N'訊息', 狀態;`：錯誤編號必須 ≥ 50000
- `THROW;`（只有分號）：在 `CATCH` 裡重新拋出目前的錯誤，保留原始編號與訊息
- `RAISERROR` 是舊語法，仍然可用；新專案優先 `THROW`
- `THROW` 會把嚴重性設為 16（可用 `CATCH` 捕捉），且一定終止批次

**標準錯誤處理樣板（背下來）：**

```sql
SET XACT_ABORT ON;

BEGIN TRY
	BEGIN TRANSACTION;

	-- 你的 DML

	COMMIT TRANSACTION;
END TRY
BEGIN CATCH
	IF XACT_STATE() <> 0
		ROLLBACK TRANSACTION;

	THROW;	-- 把錯誤往上丟，讓呼叫端（或 C#）知道失敗
END CATCH;
```

### 1.5 死結（deadlock）

兩個交易互相等待對方持有的鎖，SQL Server 會選一個當犧牲者，回報錯誤 **1205**：

```
Transaction (Process ID 57) was deadlocked on lock resources with another process
and has been chosen as the deadlock victim. Rerun the transaction.
```

避免方式：

- 交易越短越好，不要在交易裡等使用者輸入或跑報表
- 多個資源的存取順序一致（例如永遠先更新 A 再更新 B）
- 用適當的索引縮小鎖定範圍
- 應用程式要能**重試** 1205（以及逾時 1222）

```sql
-- 查目前有哪些請求在等待
SELECT
	session_id,
	blocking_session_id,
	wait_type,
	wait_time,
	wait_resource
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;
```

### 1.6 交易的最佳實務

- 交易只包住必要的 DML；`SELECT` 報表、寄信、呼叫外部 API 都放外面
- 一定要有 `COMMIT` 或 `ROLLBACK` 的明確路徑；用 `TRY/CATCH` 保證例外時回滾
- 應用程式連線要關閉／歸還連線池；長時間閒置的交易會擋住別人
- 大量更新分批做（例如每次 1000 筆），避免長時間鎖定與巨大交易記錄
- 不要用 `BEGIN TRAN` 之後忘記結束；`@@TRANCOUNT` 大於 0 時，後續操作都在同一個交易裡

---

## 2. 隔離級別：同時上線時，誰看得到誰的變更

### 2.1 三種「讀取異常」

| 異常 | 情境 | 一句話 |
|------|------|--------|
| 骯髒讀（dirty read） | A 讀到 B 尚未提交的資料 | 讀到「可能被回滾」的資料 |
| 不可重複讀（non-repeatable read） | A 兩次讀同一列，中間 B 更新並提交 | 同一交易內讀到不同值 |
| 幻讀（phantom read） | A 兩次查同一範圍，中間 B 新增／刪除並提交 | 同一交易內多出或少掉列 |

### 2.2 隔離級別對照

| 隔離級別 | 骯髒讀 | 不可重複讀 | 幻讀 | 特性 |
|----------|--------|------------|------|------|
| `READ UNCOMMITTED` | 可能 | 可能 | 可能 | 幾乎不鎖，最快但最不安全 |
| `READ COMMITTED`（預設） | 不會 | 可能 | 可能 | 只讀已提交資料 |
| `REPEATABLE READ` | 不會 | 不會 | 可能 | 讀過的列保持共享鎖，擋住更新 |
| `SERIALIZABLE` | 不會 | 不會 | 不會 | 範圍鎖，最嚴格、最容易阻塞 |

```sql
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;	-- 連線層級，直到再設定或重連
```

- SQL Server 預設是 `READ COMMITTED`
- 隔離級別是**連線**設定，不是查詢設定；用完記得改回來
- 級別越高，一致性越好，但並行度越低、阻塞與死結越多
- `NOLOCK` 等於對單一查詢使用 `READ UNCOMMITTED`：

```sql
SELECT * FROM dbo.Orders WITH (NOLOCK) WHERE CustomerID = 1;
```

⚠️ `NOLOCK` 不是「免費加速」：可能讀到未提交資料、漏掉列、讀到同一列兩次，
甚至因資料頁變動而報錯。只在「可接受不精確」的報表使用，交易性資料不要用。

### 2.3 兩視窗 lab：實際觀察

> 以下用**全域暫存表** `##IsolationLab`，兩個 sqlcmd 視窗都能看到；
> 最後一個連線關閉時會自動消失。若中途關掉視窗，重新執行 setup 即可。

**Setup（視窗 A）**

```sql
IF OBJECT_ID('tempdb..##IsolationLab') IS NOT NULL
	DROP TABLE ##IsolationLab;

CREATE TABLE ##IsolationLab (
	ID INT PRIMARY KEY,
	Value INT NOT NULL
);

INSERT INTO ##IsolationLab (ID, Value) VALUES (1, 100);
```

**Lab 1：骯髒讀**

視窗 A：

```sql
BEGIN TRANSACTION;
UPDATE ##IsolationLab SET Value = 999 WHERE ID = 1;
-- 先不要 COMMIT／ROLLBACK
```

視窗 B：

```sql
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM ##IsolationLab;	-- 看到 999（A 還沒提交）
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

視窗 A：

```sql
ROLLBACK TRANSACTION;
```

視窗 B 再查一次，會回到 100。這就是骯髒讀：B 讀到了 A 可能回滾的資料。

**Lab 2：不可重複讀**

視窗 A：

```sql
BEGIN TRANSACTION;
SELECT Value FROM ##IsolationLab WHERE ID = 1;	-- 100
-- 保持交易開啟
```

視窗 B：

```sql
BEGIN TRANSACTION;
UPDATE ##IsolationLab SET Value = 200 WHERE ID = 1;
COMMIT TRANSACTION;
```

視窗 A：

```sql
SELECT Value FROM ##IsolationLab WHERE ID = 1;	-- 200（同一交易內值變了）
COMMIT TRANSACTION;
```

把 A 的隔離級別改成 `REPEATABLE READ` 再試一次：B 的 `UPDATE` 會**卡住**，
直到 A 提交或回滾。這就是「重複讀」的代價：讀取者持有共享鎖，擋住寫入者。

**Lab 3：幻讀**

視窗 A：

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
SELECT COUNT(*) FROM ##IsolationLab WHERE Value >= 0;	-- 1
-- 保持交易開啟
```

視窗 B（另開一個查詢）：

```sql
INSERT INTO ##IsolationLab (ID, Value) VALUES (2, 50);
-- 會被擋住，直到 A 提交／回滾
```

視窗 A：

```sql
SELECT COUNT(*) FROM ##IsolationLab WHERE Value >= 0;	-- 還是 1
COMMIT TRANSACTION;
```

`SERIALIZABLE` 用範圍鎖防止「同一範圍突然多一列」。代價是 B 被阻塞；
若 B 設定 `SET LOCK_TIMEOUT 3000;`，會在三秒後收到錯誤 1222。

**清理（視窗 A）**

```sql
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
DROP TABLE ##IsolationLab;
```

### 2.4 SNAPSHOT／READ_COMMITTED_SNAPSHOT（選讀）

SQL Server 另外提供以「列版本」實作的隔離：

- `SNAPSHOT`：交易開始時看到一致的快照，讀取不阻塞寫入、寫入不阻塞讀取
- `READ_COMMITTED_SNAPSHOT`（RCSI）：讓預設的 `READ COMMITTED` 也用列版本

需要資料庫選項（`ALLOW_SNAPSHOT_ISOLATION`／`READ_COMMITTED_SNAPSHOT`），
會使用 `tempdb` 存放版本資料。公司資料庫不一定開啟，**本課主線先不用**；
若公司已開啟，寫查詢時就不用加 `NOLOCK` 也能避免讀寫互擋。

### 2.5 監控阻塞

```sql
-- 誰在擋誰
SELECT
	r.session_id,
	r.blocking_session_id,
	r.wait_type,
	r.wait_time,
	r.wait_resource,
	t.text AS 目前語句
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0;
```

`sp_who2` 也可以快速看；找出 blocking_session_id 後，再查該 session 在做什麼。
不要隨便 `KILL` 別人的 session，先確認影響。

---

## 3. 索引：讓引擎少讀一些資料

### 3.1 兩種常見索引

| 類型 | 結構 | 一張表能有幾個 | 說明 |
|------|------|----------------|------|
| Clustered（叢集） | 資料列本身照索引鍵排序（B-tree 的葉節點就是資料） | **1** | 主鍵預設會建叢集索引 |
| Nonclustered（非叢集） | 另外一份結構，葉節點存索引鍵＋列定位器 | 多個 | 一般查詢加速的主力 |

沒有叢集索引的表叫 **heap**。`dbo.Orders` 的 `OrderID` 是主鍵，預設就是叢集索引；
`CustomerID` 沒有索引，所以「依客戶找訂單」只能掃描整張表。

```sql
-- 建立非叢集索引
CREATE INDEX IX_Orders_CustomerID
ON dbo.Orders (CustomerID);

-- 複合索引：先 CustomerID，再 OrderDate
CREATE INDEX IX_Orders_CustomerID_OrderDate
ON dbo.Orders (CustomerID, OrderDate);

-- covering index：把查詢需要的欄位放在葉節點，避免 key lookup
CREATE INDEX IX_Orders_CustomerID_Covering
ON dbo.Orders (CustomerID)
INCLUDE (OrderDate, ShipFee);
```

### 3.2 索引鍵的順序很重要

複合索引 `(City, CustomerID)` 的排序是「先 City，再 CustomerID」：

| 查詢條件 | 能不能有效使用索引 |
|----------|--------------------|
| `WHERE City = N'台北'` | 可以（用到最左前綴） |
| `WHERE City = N'台北' AND CustomerID = 1` | 可以（兩欄都用到） |
| `WHERE CustomerID = 1` | **不行**（跳過最左欄） |

所以索引不是「欄位越多越好」，而是要對應**實際的查詢條件**。
`INCLUDE` 的欄位不算索引鍵，只放在葉節點，適合「查詢要顯示、但不需要拿來篩選」的欄位。

### 3.3 選擇性與成本

- 選擇性高（很多不同值，例如 `CustomerID`）的欄位，適合平等比對
- 選擇性低（只有幾種值，例如 `Discontinued` 只有 0/1）單獨建索引通常效益不大
- 每個索引都會增加 **INSERT／UPDATE／DELETE 的成本**與儲存空間
- 索引越多，寫入越慢、統計值維護越重；不要「每個欄位都建一個」
- 外鍵欄位常是查詢條件，但是否建索引要看實際查詢；不是所有 FK 都自動有索引

### 3.4 SARGable：讓條件能用索引

SARGable 的意思是「條件能被索引搜尋（seek）有效使用」。原則是**不要把欄位包在函數或運算裡**：

```sql
-- 不佳：欄位被 YEAR() 包住，通常只能掃描
WHERE YEAR(OrderDate) = 2014

-- 較佳：範圍條件，可以用 OrderDate 索引
WHERE OrderDate >= CAST('2014-01-01' AS DATE)
	AND OrderDate < CAST('2015-01-01' AS DATE)
```

其他常見例子：

```sql
-- 不佳：欄位參與運算
WHERE OrderID + 1 = 10
-- 較佳
WHERE OrderID = 9

-- 不佳：前導 %
WHERE ProductName LIKE N'%耳機'
-- 較佳：固定開頭
WHERE ProductName LIKE N'進口%'

-- 不佳：對欄位做 ISNULL
WHERE ISNULL(ShipFee, 0) = 0
-- 較佳：拆成兩個條件
WHERE ShipFee = 0 OR ShipFee IS NULL
```

隱含轉換也會讓索引失效：`NVARCHAR` 欄位和 `VARCHAR` 字面值比較時，可能把欄位轉型。
養成中文加 `N`、數值用正確型別的習慣。

### 3.5 用 STATISTICS IO 看「讀了多少」

```sql
SET STATISTICS IO ON;

SELECT OrderID, OrderDate
FROM dbo.Orders
WHERE CustomerID = 1;

SET STATISTICS IO OFF;
```

訊息會長這樣：

```
Table 'Orders'. Scan count 1, logical reads 2, physical reads 0, ...
```

- **logical reads**：從 buffer pool 讀了幾個 8KB 頁；越小越好，這是最穩定的比較指標
- physical reads：真的從磁碟讀；第一次查詢或快取被清掉時才會有
- scan count：掃描次數；巢狀迴圈可能讓同一張表被掃很多次
- 資料量小的時候，數字差異不明顯；重點是看趨勢與執行計畫，不要死背數字

### 3.6 執行計畫

**estimated plan（不會真的執行）**

```sql
SET SHOWPLAN_TEXT ON;
GO
SELECT OrderID, OrderDate
FROM dbo.Orders
WHERE CustomerID = 1;
GO
SET SHOWPLAN_TEXT OFF;
GO
```

- `SHOWPLAN_TEXT ON` 之後，查詢只回傳計畫文字，不會執行
- `SHOWPLAN_TEXT` 必須是批次裡唯一的陳述式，所以要單獨一個 `GO`
- 看完一定要 `SET SHOWPLAN_TEXT OFF;`，否則整個 session 都只產生計畫

**actual plan（SSMS）**

在 SSMS 按 `Ctrl+M`（Include Actual Execution Plan）再執行查詢；或使用
`SET STATISTICS XML ON`。actual plan 會包含實際資料列數，適合抓「預估 vs 實際差很多」。

**常見運算子**

| 運算子 | 意思 | 什麼時候要注意 |
|--------|------|----------------|
| Table Scan | 掃描 heap 全部資料 | 大表 + 選擇性高的條件 → 可能需要索引 |
| Clustered Index Scan | 掃描叢集索引全部葉節點 | 同上；不是「有索引就一定 seek」 |
| Index Seek | 依索引鍵定位 | 通常較好；確認 seek 的條件符合預期 |
| Key Lookup／RID Lookup | 用非叢集索引找到列後，再回表拿其他欄位 | 次數多時成本高；可考慮 covering index |
| Nested Loops | 小外表逐筆匹配內表 | 內表有索引時很快；沒索引會變多次掃描 |
| Hash Match | 建立 hash table 做 join／聚合 | 大資料量常見；注意記憶體授予 |
| Sort | 排序 | 大資料量 + `ORDER BY` 沒索引時可能很貴 |

**看計畫的順序：**

1. 有沒有大表 scan？條件是否 SARGable？
2. 有沒有 key lookup 很多次？查詢需要的欄位能否用 `INCLUDE` 覆蓋？
3. 預估列數和實際列數差很多嗎？→ 統計值可能過期，考慮 `UPDATE STATISTICS`
4. 有沒有 implicit conversion 警告（黃色驚嘆號）？→ 型別不一致
5. 有沒有不必要的 sort／hash？→ 索引或寫法可以調整

### 3.7 索引維護與迷思

```sql
-- 看索引使用狀況（重新啟動 SQL Server 後會歸零）
SELECT
	OBJECT_NAME(i.object_id) AS 資料表,
	i.name AS 索引,
	s.user_seeks,
	s.user_scans,
	s.user_lookups,
	s.user_updates
FROM sys.indexes AS i
LEFT JOIN sys.dm_db_index_usage_stats AS s
	ON i.object_id = s.object_id
	AND i.index_id = s.index_id
	AND s.database_id = DB_ID()
WHERE i.object_id = OBJECT_ID('dbo.Orders');
```

- 「missing index」DMV 的建議只是參考，不是命令；照單全收會產生一堆重複索引
- 索引碎片化不是萬靈丹；小表不必天天重建
- `ALTER INDEX ... REBUILD` 在 Express 可用，但 `ONLINE = ON` 只有 Enterprise 版
  （⚠️ Express 不支援 online rebuild）
- 統計值過期會讓預估列數失準；`UPDATE STATISTICS dbo.Orders;` 可以手動更新

---

## 4. T-SQL 程式：變數、流程控制、預存程序

### 4.1 變數

```sql
DECLARE @Category NVARCHAR(50) = N'電子';
DECLARE @MinPrice DECIMAL(10,2) = 300.00;

SELECT ProductName, UnitPrice
FROM dbo.Products
WHERE Category = @Category
	AND UnitPrice >= @MinPrice
ORDER BY UnitPrice DESC;
```

**`SET` 與 `SELECT` 賦值的差異：**

```sql
DECLARE @x INT;

SET @x = (SELECT UnitPrice FROM dbo.Products WHERE ProductID = 999);
SELECT @x AS 用SET;		-- NULL（子查詢沒資料）

SET @x = 0;
SELECT @x = UnitPrice FROM dbo.Products WHERE ProductID = 999;
SELECT @x AS 用SELECT;		-- 0（沒資料時保持原值）
```

- `SET` 是標準寫法，意圖清楚；一次只設一個變數
- `SELECT` 可以一次設多個變數，但「查不到資料」時不會改成 NULL，容易藏 bug
- 新專案優先 `SET`

### 4.2 IF／ELSE 與 BEGIN／END

T-SQL 沒有 boolean 型別，條件要寫成比較或 `EXISTS`：

```sql
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
```

- 多個陳述式要用 `BEGIN ... END` 包起來
- `IF` 後面只能接一個陳述式（或一個 `BEGIN...END` 區塊）
- `IF EXISTS (SELECT ...)` 是檢查「有沒有」的標準寫法

### 4.3 WHILE 迴圈

```sql
DECLARE @i INT = 1;
DECLARE @sum INT = 0;

WHILE @i <= 100
BEGIN
	SET @sum = @sum + @i;
	SET @i = @i + 1;
END;

SELECT @sum AS 總和;	-- 5050
```

- 一定要有遞增／遞減條件，否則會無限迴圈
- `BREAK` 跳出迴圈、`CONTINUE` 跳到下一輪
- 能用集合式寫法就不要用迴圈；逐列處理通常很慢（見 4.6 cursor）

### 4.4 預存程序（stored procedure）

```sql
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
```

重點：

- `SET NOCOUNT ON` 可以避免多餘的「(n rows affected)」訊息，應用程式較好處理
- 參數可以有預設值：`@MinPrice DECIMAL(10,2) = 0`
- `OUTPUT` 參數讓呼叫端拿回計算結果
- 一律用 `dbo.` 開頭，避免落到使用者預設 schema
- SQL Server 2014 **沒有** `CREATE OR ALTER`（2016 SP1 才有）；要嘛先 `DROP` 再 `CREATE`，
  要嘛用 `ALTER PROCEDURE`
- 程式碼要處理 `NULL` 與 0 筆；不要假設一定有資料

### 4.5 動態 SQL 與 SQL injection

**危險寫法：字串拼接**

```sql
DECLARE @Category NVARCHAR(50) = N'電子';
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'SELECT ProductName, UnitPrice FROM dbo.Products WHERE Category = N'''
	+ @Category + N'''';

EXEC (@sql);
```

如果 `@Category` 是 `N'電子'' OR 1=1 --'`，整個 `WHERE` 就被改寫，變成查全部。
這就是 SQL injection。

**安全寫法：`sys.sp_executesql` + 參數**

```sql
DECLARE @Category NVARCHAR(50) = N'電子';
DECLARE @sql NVARCHAR(MAX) = N'
	SELECT ProductName, UnitPrice
	FROM dbo.Products
	WHERE Category = @Category;';

EXEC sys.sp_executesql
	@sql,
	N'@Category NVARCHAR(50)',
	@Category = @Category;
```

- 參數不會被當成 SQL 語法，注入字串只會被當成普通值
- `sys.sp_executesql` 的參數型別要寫清楚，避免隱含轉換；加 `sys.` 是 schema 限定寫法，
  也是官方建議的呼叫方式
- 只有「資料表名稱、欄位名稱、排序方向」不能參數化；這時用**白名單**或 `QUOTENAME`

```sql
DECLARE @SortColumn NVARCHAR(128) = N'UnitPrice';

-- 白名單：只允許預期的欄位
IF @SortColumn NOT IN (N'UnitPrice', N'ProductName')
	THROW 50002, N'不合法的排序欄位', 1;

DECLARE @sql NVARCHAR(MAX) = N'
	SELECT ProductName, UnitPrice
	FROM dbo.Products
	ORDER BY ' + QUOTENAME(@SortColumn) + N';';

EXEC sys.sp_executesql @sql;
```

### 4.6 暫存表、表變數與 cursor

**暫存表 `#temp`：**

```sql
SELECT
	o.OrderID,
	SUM(d.Quantity * d.UnitPrice) AS 訂單金額
INTO #OrderTotals
FROM dbo.Orders AS o
INNER JOIN dbo.OrderDetails AS d ON o.OrderID = d.OrderID
GROUP BY o.OrderID;

CREATE INDEX IX_OrderTotals_Amount ON #OrderTotals (訂單金額);

SELECT TOP (3) * FROM #OrderTotals ORDER BY 訂單金額 DESC;

DROP TABLE #OrderTotals;
```

- 有統計值、可以建索引、交易中可回滾
- 只在目前連線可見，連線結束自動刪除（`##` 是全域，所有連線可見）
- 適合多步驟查詢、需要重複使用的中間結果

**表變數 `@t`：**

```sql
DECLARE @t TABLE (
	ID INT PRIMARY KEY,
	Amount DECIMAL(12,2)
);

INSERT INTO @t (ID, Amount) VALUES (1, 100.00);

SELECT * FROM @t;
```

- 生命週期只在目前批次；沒有統計值（預估列數常常是 1）
- 適合少量資料；資料量大時效能可能不如 `#temp`
- 沒有「哪個一定比較好」；看資料量與查詢模式

**cursor：逐列處理**

```sql
DECLARE @CustomerID INT;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
	SELECT CustomerID FROM dbo.Customers;

OPEN cur;
FETCH NEXT FROM cur INTO @CustomerID;

WHILE @@FETCH_STATUS = 0
BEGIN
	-- 對每一列做事（通常可以用集合式寫法取代）
	FETCH NEXT FROM cur INTO @CustomerID;
END;

CLOSE cur;
DEALLOCATE cur;
```

cursor 不是罪惡，但 99% 的情境可以用 `JOIN`／`GROUP BY`／CTE／視窗函數（Day 5）取代。
真的需要逐列呼叫預存程序或處理外部資源時再用，並且用完一定要 `CLOSE`＋`DEALLOCATE`。

---

## 5. 接下來

做完 `exercises.sql`。今天有交易、索引建立等 DDL／DML，練習一樣全部包在交易中並回滾。

明天 Day 5：視窗函數、實務食譜，以及用 C#（SqlClient／Dapper／EF Core）安全地接上
這些查詢。
