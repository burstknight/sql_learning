# Day 2：聚合、GROUP BY/HAVING、JOIN

建議時間分配（約 4.5 小時）：

| 時間 | 內容 |
|------|------|
| 50 分 | 聚合函數與 NULL 的交互作用 |
| 50 分 | GROUP BY 與 HAVING |
| 100 分 | JOIN（今天最重要的部分） |
| 其餘 | 做 `exercises.sql` |

---

## 1. 聚合函數：把很多列變成一個數字

聚合函數吃一整欄的資料，回傳一個值。五個基本款：

| 函數 | 意思 |
|------|------|
| `COUNT(*)` | 有幾列（整列算，NULL 也算） |
| `COUNT(欄位)` | 這一欄「有幾列非 NULL」 |
| `SUM(欄位)` | 加總 |
| `AVG(欄位)` | 平均（**忽略 NULL**） |
| `MIN / MAX(欄位)` | 最小／最大（對日期、字串也適用） |

```sql
-- 產品有幾項、最貴、最便宜
SELECT
	COUNT(*) AS 產品數,
	MAX(UnitPrice) AS 最貴,
	MIN(UnitPrice) AS 最便宜
FROM dbo.Products;

-- 訂單明細總數量
SELECT SUM(Quantity) AS 總數量
FROM dbo.OrderDetails;
```

### 1.1 COUNT(*) vs COUNT(欄位)：NULL 陷阱

```sql
SELECT
	COUNT(*)           AS 全部客戶,	-- 12
	COUNT(Phone)       AS 有電話的,	-- 只數非 NULL
	COUNT(*) - COUNT(Phone) AS 沒電話的
FROM dbo.Customers;
```

`COUNT(Phone)` 數的是「Phone 不是 NULL 的列數」——這是 SQL 慣用技巧：
「要數 A 的數量，就 COUNT 那個保證不為 NULL 的欄位」。

### 1.2 AVG 忽略 NULL：平均值騙局

假設三筆數量是 `10、NULL、30`：

- `AVG(Quantity)` = 20（把 NULL 當不存在，分母用 2）
- 但業務上常要的是「把沒填的當 0」= 40/3 = 13.3（分母用 3）

```sql
-- 需要把 NULL 當 0 的話，要自己動手
SELECT AVG(COALESCE(Quantity, 0)) AS 平均_補零
FROM dbo.OrderDetails;
```

這個差異在對帳、報表時非常常見，先建立敏感度。

### 1.3 ⚠️ AVG 對整數欄位的經典坑

```sql
SELECT AVG(Quantity) FROM dbo.OrderDetails;		-- Quantity 是 INT
```

T-SQL 的 `AVG(INT)` **回傳 INT**——小數直接被砍掉。`SUM` 不會，只有 `AVG` 有這問題。
解法：先轉型再平均：

```sql
SELECT AVG(CAST(Quantity AS DECIMAL(10,2))) AS 正確平均
FROM dbo.OrderDetails;
```

（`CAST(x AS 型別)` 是標準寫法，Day 3 會更完整介紹型別轉換。）

---

## 2. GROUP BY：先分組、再聚合

想問「每個類別有幾種產品」，一次聚合整張表做不到，要先按 `Category` 分組：

```sql
SELECT Category, COUNT(*) AS 產品數
FROM dbo.Products
GROUP BY Category;
```

**文法規則（新手最常見的錯誤）：**

> SELECT 裡「不是聚合函數」的欄位，必須全部寫進 GROUP BY。

```sql
-- 錯誤：ProductName 既沒聚合、也沒出現在 GROUP BY
SELECT Category, ProductName, COUNT(*)
FROM dbo.Products
GROUP BY Category;
-- Msg 8120: 資料行 'dbo.Products.ProductName' 在 SELECT 清單中不合法，
-- 因為它不是包含在聚合函數或 GROUP BY 子句中
```

直覺解釋：分組後每組只剩一個數字，你要的 ProductName「每組有很多個」，引擎不知道要哪個。

### 2.1 NULL 也會被當成一組

```sql
SELECT DepartmentID, COUNT(*) AS 人數
FROM dbo.Employees
GROUP BY DepartmentID;
-- DepartmentID 為 NULL 的借調人員會自成一組（一列）
```

### 2.2 HAVING：對「組」做條件

`WHERE` 篩選的是**原始列**（分組前），`HAVING` 篩選的是**組**（分組後）：

```sql
-- 有下過單的客戶中，訂單數 ≥ 2 的客戶
SELECT CustomerID, COUNT(*) AS 訂單數
FROM dbo.Orders
GROUP BY CustomerID
HAVING COUNT(*) >= 2;
```

不能寫 `WHERE COUNT(*) >= 2`：WHERE 執行時還沒分組，根本沒有「組的數量」可比。

### 2.3 邏輯執行順序（把 Day 1 的補完）

```
FROM → WHERE → GROUP BY → HAVING → SELECT（欄位/別名）→ ORDER BY
```

- WHERE 先砍列 → 剩下的列分組 → HAVING 再砍組 → 最後才做 SELECT 的欄位與別名
- 所以 `SELECT ... AS 總額` 的別名**可以在 ORDER BY 用，但不能在 WHERE/HAVING 用**
  （HAVING 要重寫一次聚合式，如上例的 `HAVING COUNT(*) >= 2`）

---

## 3. JOIN：把多張表串起來（今天最重要）

### 3.1 為什麼需要 JOIN

正規化的資料庫把資料拆在多張表（客戶在 Customers、訂單在 Orders），
靠「編號對應」串回完整資訊。這個「按編號配對」的動作就是 JOIN。

- `Customers.CustomerID` 與 `Orders.CustomerID` 欄位名相同 → 配對條件寫 `ON Orders.CustomerID = Customers.CustomerID`
- 兩邊欄位名不同時（如 Employees.EmployeeID → Orders.EmployeeID）欄位名不重要，**值對得上**才重要

### 3.2 INNER JOIN：兩邊都配到才保留

```sql
-- 每張訂單顯示客戶公司名
SELECT
	o.OrderID,
	c.CompanyName,
	o.OrderDate
FROM dbo.Orders AS o			-- AS 取別名，表格常用單字母，長表也好打
INNER JOIN dbo.Customers AS c
	ON o.CustomerID = c.CustomerID;
```

- `INNER JOIN ... ON 配對條件` 是現代標準寫法。**配對條件永遠放 ON，不要放 WHERE**
  （今天結束前會看到為什麼）
- `INNER` 可省略（`JOIN` 就是 INNER JOIN）

配對不到的列會被丟掉：沒有員工的訂單（`EmployeeID IS NULL`）在 INNER JOIN 員工時不會出現。

### 3.3 LEFT JOIN：左邊全部保留，右邊配不到補 NULL

「外聯集」家族：

| 寫法 | 保留規則 |
|------|----------|
| `LEFT JOIN` | 左表全保留，右表配不到的欄位補 NULL（**最常用**） |
| `RIGHT JOIN` | 右表全保留（把 LEFT 反過來寫即可，少用） |
| `FULL JOIN` | 兩邊都全保留（更少用，認得就好） |

**經典題型：找出「沒有任何訂單」的客戶**

```sql
SELECT c.CustomerID, c.CompanyName
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o
	ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;	-- 配不到的列，右表欄位全是 NULL
GO
-- 說明原理：LEFT JOIN 保證 c 的每一列都會出現在結果。
-- 配到訂單的列，o.OrderID 有值；
-- 沒配到的列，o.* 全部補 NULL → 用 "o.OrderID IS NULL" 篩出這些列。
```

注意語義：`WHERE o.OrderID IS NULL` 不是「訂單編號是 NULL」，而是
「**這列客戶沒配到任何訂單**」。這是 LEFT JOIN 最重要的用法，Day 2 練習會重複磨。

### 3.4 多表 JOIN

```sql
-- 訂單 → 客戶 → 員工，三表串接（接單員工離職時 Employee 顯示 NULL）
SELECT
	o.OrderID,
	c.CompanyName,
	e.LastName + e.FirstName AS 接單人,
	o.OrderDate
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c
	ON o.CustomerID = c.CustomerID
LEFT JOIN dbo.Employees AS e		-- 用 LEFT：離職員工的訂單也要顯示
	ON o.EmployeeID = e.EmployeeID
ORDER BY o.OrderID;
```

- 每個 JOIN 各自帶自己的 ON，一個 JOIN 出錯只影響那一段，好除錯
- 選 LEFT/RIGHT 的準則：**先決定「哪張表一列都不能少」，把放那張表的 JOIN 寫成 LEFT**

### 3.5 JOIN 常見坑

**坑 1：配對條件放錯邊（ON vs WHERE）**

```sql
-- 錯誤示範：想看「台北客戶的訂單」，把 City 條件寫進 WHERE
SELECT c.CompanyName, o.OrderID
FROM dbo.Customers AS c
LEFT JOIN dbo.Orders AS o
	ON c.CustomerID = o.CustomerID
WHERE c.City = N'台北';
-- 結果變成了「只列出台北客戶」的 INNER JOIN 效果：
-- 因為 WHERE 把 LEFT 補出來的非台北列全砍了，LEFT 白寫了。
-- 正確：LEFT JOIN 之後還想篩「左表的條件」，條件要放 ON 裡（或先用子查詢/暫存表篩好左表）。
```

規則：**LEFT JOIN 之後，對左表的額外條件放 ON；對右表的條件放 WHERE 是可以的**（但那時通常等價於 INNER JOIN，要確認語意）。

**坑 2：欄位同名要指明來源**

```sql
-- Orders 與 OrderDetails 都有 OrderID，直接寫 OrderID 會報「欄位名不明確」
SELECT o.OrderID, d.Quantity	-- 明確寫 o.OrderID
FROM dbo.Orders AS o
INNER JOIN dbo.OrderDetails AS d
	ON o.OrderID = d.OrderID;
```

**坑 3：逗號式（隱式）JOIN**

```sql
-- 舊寫法：FROM 後面放逗號分隔的表，條件放 WHERE（你可能在 SQLite 看過）
SELECT *
FROM dbo.Customers, dbo.Orders
WHERE dbo.Customers.CustomerID = dbo.Orders.CustomerID;
-- 能跑，但條件漏寫就變成 CROSS JOIN（列數相乘爆量）、也分不清 JOIN 類型。
-- 統一用 INNER/LEFT JOIN ... ON，本教材與公司新 code 一律如此。
```

**坑 4：NULL 對不上**

`ON a.x = b.x` 時，NULL 永遠不等於 NULL。例如借調員工 `DepartmentID IS NULL`，
`Employees JOIN Departments ON Employees.DepartmentID = Departments.DepartmentID`
配不到——這是正確行為（未知對未知），但要知道 LEFT JOIN Departments 才看得到這些人。

---

## 4. 心智模型小結

| 情境 | 用法 |
|------|------|
| 兩邊都要有資料 | `INNER JOIN` |
| 左表一列都不能少 | `LEFT JOIN`＋右表欄位 `IS NULL` 找未配對 |
| 先篩列再算 | `WHERE`（分組前） |
| 算完組的統計再篩 | `HAVING`（分組後） |
| 條件 | 永遠寫在 `ON`，別混進 `WHERE` |

做完 `exercises.sql`，明天 Day 3 把「查出來的結果」再拿來當查詢的原料（子查詢／CTE），並開始學安全地修改資料。
