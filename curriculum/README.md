# SQL 自學教材：5 天密集版

目標：從 SQLite 基礎銜接企業級 SQL Server，最終能在 C# 專案中安全地操作資料庫。

- 目標資料庫：**SQL Server（T-SQL）**，公司環境為 SQL Server 2014 Express（`localhost\SQLEXPRESS`）
- 適合對象：會 C#、有淺薄 SQLite 基礎、SQL 新手
- 每天投入：4～5 小時

## 每日路線圖

| 天數 | 資料夾 | 主題 | 重點 |
|------|--------|------|------|
| Day 1 | `day01_select/` | 連線＋SELECT 基礎 | 連上 SQL Server、sqlcmd 互動介面、SQLite→T-SQL 遷移、SELECT、WHERE |
| Day 2 | `day02_aggregate_join/` | 聚合＋JOIN | GROUP BY、HAVING、各種 JOIN、多表關聯 |
| Day 3 | `day03_subquery_dml/` | 子查詢＋資料操作 | 子查詢、CTE、INSERT/UPDATE/DELETE 安全實務 |
| Day 4 | `day04_transaction_perf/` | 交易＋效能＋T-SQL 程式 | 交易與隔離級別、索引與執行計畫、變數與流程控制 |
| Day 5 | `day05_window_csharp/` | 視窗函數＋實務＋C# 串接 | ROW_NUMBER 等、常用食譜、SqlClient/Dapper/EF Core |

Day 4～5 規劃中，完成後會出現在 TODO.md。

## 資料夾結構

```
curriculum/
├── README.md          ← 本檔案
├── common/
│   ├── SETUP.md            ← 安裝與連線手冊（公司環境主線、Docker、疑難排解）
│   ├── docker-compose.yml  ← 練習用資料庫（需 x86_64 或 4KB 頁核心，見 SETUP.md 第 4 章）
│   └── seed.sql            ← 範例資料庫（模擬公司訂單系統，全課程共用）
├── day01_select/
│   ├── lesson.md      ← 觀念講解
│   ├── exercises.sql  ← 練習題（含提示）
│   └── answers.sql    ← 參考答案＋解說
├── day02_aggregate_join/   ← 結構同上
└── day03_subquery_dml/     ← 結構同上
```

## 使用方式

1. 環境還沒就緒或連不上時，先看 [`common/SETUP.md`](common/SETUP.md)
2. 每天先讀 `lesson.md`，邊讀邊在 sqlcmd 裡試範例
3. 做 `exercises.sql`（每題有提示，先自己寫再看 `answers.sql`）
4. 練習檔可直接在 sqlcmd 互動模式貼上執行，或用 `sqlcmd -i exercises.sql` 整份跑
5. 寫完可用 `tools/check.sh`（在專案根目錄執行）離線檢查語法是否符合 SQL Server 2014，
   不需要連線；規則與限制見根目錄 `README.md` 的「教材檢查（離線）」章節

## 練習環境 vs 公司環境

**本課程以公司環境為主練習場**（最接近工作現場）；本機 Docker 為備用，
需要 x86_64 機器（ARM64 如樹莓派 5 預設是 16KB 頁核心，容器會崩潰；
換 4KB 頁核心的做法見 SETUP.md 第 4 章，尚未驗證）。

| | 練習環境（本機備用） | 公司環境（主線） |
|---|---|---|
| 伺服器 | Docker 容器（SQL Server 2022），`localhost,1433` | `localhost\SQLEXPRESS`（命名實例） |
| 驗證 | SQL 驗證（sa） | 混合模式（Windows 驗證＋SQL 驗證） |
| 版本 | 現代引擎（相容層級可調） | SQL Server 2014 |

**重要**：教材以 SQL Server 2014 為目標。練習環境引擎較新，遇到標示 ⚠️ 的語法
代表 2014 沒有，練習時可試、但公司環境不能用。

## 工具

- **sqlcmd**（主力）：終端機互動式 SQL shell，類似 sqlite3，Day 1 教學
- **Neovim 插件**（日常加速）：vim-dadbod、vim-dadbod-ui、nvim-treesitter
- **C# 串接**（Day 5）：Microsoft.Data.SqlClient、Dapper、Entity Framework Core
