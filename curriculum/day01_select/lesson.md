# Day 1：連線與 sqlcmd、SELECT 基礎、WHERE

建議時間分配（約 4.5 小時）：

| 時間 | 內容 |
|------|------|
| 45 分 | 連上 SQL Server ＋ sqlcmd 互動介面 |
| 30 分 | SQLite → T-SQL 遷移對照 |
| 60 分 | SELECT 基礎 |
| 90 分 | WHERE 完整攻略 |
| 其餘 | 做 `exercises.sql` |

---

## 1. 連上 SQL Server 與 sqlcmd

### 1.1 連線與載入範例資料庫

sqlcmd 是微軟官方的終端機 SQL 工具，就是你要的「類似 sqlite3」的互動式介面。
安裝與環境設定（公司連線、Docker 練習庫、疑難排解）見
[`common/SETUP.md`](../common/SETUP.md)，這裡只講今天要用的連線。

主練習環境是公司的 SQL Server 2014 Express——最接近工作現場、也最準：

```bat
:: 公司機上（cmd/PowerShell），在 repo 的 curriculum\common\ 目錄：
sqlcmd -S localhost\SQLEXPRESS -E -i seed.sql

:: 驗證（三步都正常＝環境就緒）
sqlcmd -S localhost\SQLEXPRESS -E -Q "SELECT GETDATE();"
sqlcmd -S localhost\SQLEXPRESS -E -d learning_db -Q "SELECT COUNT(*) FROM dbo.Customers;"
```

公司機器不方便 clone repo 時，把 `seed.sql` 拷貝過去執行即可。

若你有 x86_64 的機器想跑 Docker 練習庫（樹莓派等 ARM64 機器不可行，原因見
SETUP.md 第 4 章），連線字串換成：

```bash
sqlcmd -S localhost,1433 -U sa		# 密碼 LearningP@ssw0rd，seed.sql 同樣適用
```

### 1.2 sqlcmd 互動模式完整教學

連線到練習資料庫（互動模式，依環境二選一）：

```bat
sqlcmd -S localhost\SQLEXPRESS -E
```

```bash
sqlcmd -S localhost,1433 -U sa		# Docker 練習庫（密碼 LearningP@ssw0rd）
```

- `-S`：伺服器。公司環境是 `localhost\SQLEXPRESS`（反斜槓+命名實例，**不是**埠號）；本機 Docker 用 `localhost,1433`（逗號+埠號）
- `-U` / `-P`：SQL 驗證的帳號密碼。不加 `-P` 會改為提示輸入（**建議**：密碼不會留在 shell history 與畫面上）
- 連上後出現輸入提示：

```
1> USE learning_db;
2> SELECT * FROM dbo.Customers;
3> GO
```

**sqlcmd 的核心規則（新手最常踩的坑）：**

1. 你打的每一行會累積在緩衝區，顯示 `1>`、`2>` 編號，**按下 Enter 不會執行**
2. 打上獨立一行 `GO`（大寫習慣）才會把緩衝區整批送給伺服器執行
3. 陳述式結尾的 `;` 在 sqlcmd 裡可加可不加（但建議養成習慣加上）
4. 要離開：獨立一行 `:quit`（或 Ctrl+D）

注意：`GO` **不是 T-SQL 語法**，是 sqlcmd 等工具的指令。C# 程式碼或 Neovim 的
vim-dadbod 送 SQL 時不會有 `GO`，這是工具間的差異，之後遇到再對照。

其他常用參數：

| 參數 | 用途 | 範例 |
|------|------|------|
| `-d` | 指定連線後使用的資料庫（省去 `USE`） | `sqlcmd ... -d learning_db` |
| `-i` | 執行 SQL 檔案（整檔跑完離開） | `sqlcmd ... -i seed.sql` |
| `-o` | 把結果輸出到檔案 | `sqlcmd ... -Q "SELECT 1" -o out.txt` |
| `-Q` | 執行查詢後立刻離開 | `sqlcmd ... -Q "SELECT GETDATE();"` |
| `-y` | 字串欄位最大顯示長度（預設 30，**超過會被截斷**，看到 `...` 就是它） | `-y 100` |
| `-W` | 去掉結果多餘的尾端空白 | 搭配 `-s"|"` 輸出乾淨 |
| `-s"|"` | 欄位分隔符（預設空格） | `-s"|"` |

試試長字串截斷的坑（客戶公司名若超過 30 字元才會明顯，可自己造）：

```sql
1> SELECT REPLICATE('長', 50) AS long_text;
2> GO
```

看到結尾 `...` 就是被 `-y` 預設 30 截斷了，用 `sqlcmd -y 100` 重連再試。

### 1.3 公司環境差異（SQL Server 2014 Express）

- 驗證方式：`-E`（Windows 驗證，混合模式下建議，不用密碼）或 `-U 帳號`（SQL 驗證，省略 `-P` 會提示輸入）。細節見 SETUP.md 第 1 章
- Express 版限制：單一資料庫最大 **10GB**、CPU/記憶體上限、**沒有 SQL Agent**（排程功能）
  —— 看到有人用「代理人排程」的教學，公司環境做不到，先跳過

### 1.4 Neovim 插件（日常加速器，先裝不急著學）

學習順序仍然是 sqlcmd 先行，把語法練熟。之後可在 Neovim 裝：

| 插件 | 用途 |
|------|------|
| `vim-dadbod`（tpope） | 在 Neovim 內連資料庫、選取 SQL 直接執行 |
| `vim-dadbod-ui` | 圖形化瀏覽資料表、點選查詢 |
| `nvim-treesitter` | SQL 語法高亮，複雜 SQL 可讀性大幅提升 |

dadbod 連線字串範例（Docker 練習庫；公司命名實例的格式等實際連上再回填）：

```vim
" 放在 Neovim 設定檔，之後 :DB 執行
let g:dbs = {
\ 'learning': 'mssql://sa:LearningP@ssw0rd@localhost:1433/learning_db',
\ }
```

---

## 2. SQLite → T-SQL 遷移對照

你有約 8 個月 SQLite 經驗，這是資產。以下是**最常坑到 SQLite 背景者**的差異：

| 你熟悉的 SQLite | T-SQL（SQL Server） | 說明 |
|---|---|---|
| `LIMIT 10 OFFSET 5` | `OFFSET 5 ROWS FETCH NEXT 10 ROWS ONLY`（前面要有 ORDER BY）或簡單取前幾筆用 `TOP 10` | 2012 起支援 OFFSET/FETCH，2014 可用 |
| `a \|\| b` 字串串接 | `a + b` | **大坑**：任一端是 NULL，結果整個變 NULL（Day 3 深講，今天先記住） |
| `AUTOINCREMENT` | `IDENTITY(1,1)` | 寫在欄位資料型別後面 |
| `date('now')`、`julianday()` | `GETDATE()`、`DATEADD()`、`DATEDIFF()`、`DATENAME()` | T-SQL 沒有 SQLite 那套日期函數族，日期靠這幾個函數組合 |
| 型別親和（affinity）：存什麼型別都行 | **嚴格型別**＋隱含轉換規則 | `'abc' > 5` 在 SQLite 常常「可以」，在 SQL Server 會報錯或產生意外的隱含轉換（Day 3 專講） |
| 檔案型資料庫，`sqlite3 xxx.db` | 伺服器型：常駐服務，多使用者同時連線 | 所以有「交易、鎖定、權限」的概念（Day 4） |
| 沒有真正的 schema 分離 | `資料庫.dbo.資料表` 三段式命名 | `learning_db.dbo.Customers`；同資料庫內可只寫 `dbo.Customers` |
| 型別：TEXT/INTEGER/REAL | `NVARCHAR`/`INT`/`DECIMAL(10,2)` 等明確型別 | NVARCHAR = Unicode，中文務必用它（VARCHAR 存中文會出問題） |

保留一個好習慣就好：**SQL 大部分基礎語法（SELECT/WHERE/JOIN/GROUP BY）是跨資料庫通用的**，
你已有的 SQL 直覺多半能延用，只需記住上面這些「換了工具」的部分。

---

## 3. SELECT 基礎

SELECT 陳述式的邏輯執行順序（先記個大概，Day 2 會再用到）：

```
FROM  →  WHERE  →  SELECT（欄位）  →  ORDER BY
```

### 3.1 選欄位、別名、運算式

```sql
-- 指定欄位（正式環境避免 SELECT *：欄位多時浪費、欄位順序一改程式就壞）
SELECT ProductName, UnitPrice
FROM dbo.Products;

-- 別名（AS 可省略；結果標題換名字，不改資料表內容）
SELECT ProductName AS 產品名稱, UnitPrice AS 單價
FROM dbo.Products;

-- 算術運算式：算「小計」
SELECT OrderID, Quantity, UnitPrice,
	Quantity * UnitPrice AS LineTotal
FROM dbo.OrderDetails;

-- 字串串接用 +（注意：任何一端 NULL 整個結果變 NULL！看電話欄）
SELECT CompanyName + '（' + Phone + '）' AS info
FROM dbo.Customers;		-- Phone 為 NULL 的客戶，info 整欄 NULL
```

### 3.2 DISTINCT：去掉重複列

```sql
-- 客戶分佈在哪些城市（重複只留一個）
SELECT DISTINCT City
FROM dbo.Customers;

-- DISTINCT 可同時作用多欄：整組重複才算重複
SELECT DISTINCT City, Category
FROM dbo.Customers, dbo.Products;	-- 這是 CROSS JOIN，Day 2 會講
```

### 3.3 TOP：取前幾筆

```sql
-- 單價最高的 5 個產品（TOP 要搭配 ORDER BY 才有「前 5 名」的意義）
SELECT TOP 5 ProductName, UnitPrice
FROM dbo.Products
ORDER BY UnitPrice DESC;

-- 加 PERCENT 取前 50%
SELECT TOP 50 PERCENT *
FROM dbo.Products;
```

⚠️ 練習環境是新引擎，還支援 `TOP (n) WITH TIES`、`OFFSET ... FETCH`（2014 也有）：

```sql
-- OFFSET/FETCH：分頁標準寫法（2012 起，2014 可用）。注意 OFFSET 前必須有 ORDER BY
SELECT ProductName, UnitPrice
FROM dbo.Products
ORDER BY UnitPrice DESC
	OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
```

### 3.4 ORDER BY 排序

```sql
-- 單一欄：DESC 降冪、ASC 升冪（預設 ASC，可省略）
SELECT ProductName, UnitPrice
FROM dbo.Products
ORDER BY UnitPrice DESC, ProductName ASC;	-- 同單價時再依名稱排
```

規則與坑：

- 預設排序方向是 ASC，NULL 排最前面（ASC 時）
- 可依「沒有出現在 SELECT 的欄位」排序（這在 T-SQL 是允許的）

### 3.5 註解

```sql
-- 單行註解（最常用）
/* 多行註解
   也可以寫在陳述式中間 */
SELECT ProductName, -- 行尾註解
	UnitPrice
FROM dbo.Products;
```

---

## 4. WHERE 完整攻略

WHERE 放在 FROM 之後、對**每一列**做篩選，只留條件為 TRUE 的列。

### 4.1 比較運算子

```sql
SELECT ProductName, UnitPrice
FROM dbo.Products
WHERE UnitPrice >= 300;

-- 不等於：<> 或 != 都可以（<> 是標準，!= 是相容寫法）
SELECT *
FROM dbo.Products
WHERE Category <> N'飲料';
```

⚠️ 中文字面值前加 `N`（National）是 T-SQL 慣例，代表 Unicode 字串。對 NVARCHAR 欄位
不加 `N` 多數情況也行，但養成習慣可避免編碼問題。

### 4.2 AND / OR / NOT

```sql
-- 同時成立
SELECT *
FROM dbo.Products
WHERE Category = N'文具' AND UnitPrice < 100;

-- 任一成立
SELECT *
FROM dbo.Customers
WHERE City = N'台北' OR City = N'高雄';
```

**優先權：AND 比 OR 先算。** 看這個常見邏輯錯誤：

```sql
-- 想找：台北的客戶，以及所有單價 500 以上的產品？寫在同個 WHERE 裡邏輯就亂了
-- 正確做法：用括號明確表達（養成習慣，永遠加括號）
WHERE (a = 1 OR b = 2) AND c = 3
```

### 4.3 IN：多值比對

```sql
SELECT *
FROM dbo.Customers
WHERE City IN (N'台北', N'新竹', N'高雄');
-- 等價於 City = N'台北' OR City = N'新竹' OR City = N'高雄'
-- NOT IN 則是「都不等於」
```

### 4.4 BETWEEN：範圍（含兩端）

```sql
-- 單價 100～300（含頭含尾，等價 >= 100 AND <= 300）
SELECT *
FROM dbo.Products
WHERE UnitPrice BETWEEN 100 AND 300;

-- 日期範圍：2014 下半年。注意：用 >= / < 明確邊界比 BETWEEN 更安全（之後 DATE 型別沒差，
-- 但若欄位是 DATETIME 含時間，BETWEEN '2014-07-01' AND '2014-12-31' 會漏掉 12/31 當天下午）
SELECT *
FROM dbo.Orders
WHERE OrderDate >= '2014-07-01' AND OrderDate < '2015-01-01';
```

### 4.5 LIKE：字串模糊比對

| 通配符 | 意思 | 範例 |
|--------|------|------|
| `%` | 任意字數（含 0 個） | `LIKE '進口%'` 開頭是「進口」 |
| `_` | 單一字元 | `LIKE '_膏'` 兩字詞、結尾是「膏」 |
| `[...]` | 字元集內任一字元 | `LIKE '[A-C]%'` 開頭 A/B/C |

```sql
SELECT *
FROM dbo.Products
WHERE ProductName LIKE N'%耳機%';	-- 名稱裡含「耳機」

-- 找台北區電話：02- 開頭
SELECT *
FROM dbo.Customers
WHERE Phone LIKE N'02-%';
```

坑：

- `%` 放頭尾會讓索引失效、全表掃描（效能問題，Day 4 展開）
- 要比對字面上的 `%` 或 `_` 本身，用 ESCAPE 指定跳脫字元：`LIKE '%10!%%' ESCAPE '!'`

### 4.6 NULL：三值邏輯（SQLite 也有的坑，這裡更嚴格）

NULL 不是 0、不是空字串，是「未知」。**NULL 參與任何比較，結果都是 UNKNOWN**，
而 WHERE 只保留結果為 TRUE 的列：

```sql
-- 錯誤寫法：永遠查不到東西（NULL = NULL 的結果是 UNKNOWN，不是 TRUE）
SELECT * FROM dbo.Customers WHERE Phone = NULL;

-- 正確寫法
SELECT * FROM dbo.Customers WHERE Phone IS NULL;		-- 沒電話的客戶
SELECT * FROM dbo.Customers WHERE Phone IS NOT NULL;	-- 有電話的客戶
```

另一個經典直覺陷阱（先埋個伏筆，Day 3 會看到它在子查詢裡爆發）：

```sql
-- 想找「沒電話」的客戶，寫成 WHERE Phone <> '02-1234-5679' 是錯的：
-- 沒電話的客戶 Phone 是 NULL，NULL <> 任何東西 = UNKNOWN，會被 WHERE 濾掉
```

還有一個小差異：T-SQL 的 `ISNULL(x, y)` 是替 NULL 填值的函數（SQLite 是 `IFNULL`或 `COALESCE`）。`COALESCE` 兩邊都有，可先用它：

```sql
SELECT CompanyName, COALESCE(Phone, N'（沒留電話）') AS Phone
FROM dbo.Customers;
```

---

## 5. 接下來

做完 `exercises.sql`（每題有提示），對答案看 `answers.sql`。明天 Day 2：把這些資料「加總、分組、串起來」。
