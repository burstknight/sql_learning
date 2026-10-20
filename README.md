# sql learning

自學 SQL 的教材與練習專案：為了新工作（C# 開發＋SQL Server 2014）而建。
目標是用 5 天密集課程，從 SQLite 基礎銜接企業級 T-SQL，並學會在 C# 中安全地操作資料庫。

## 快速開始

```bat
:: 0. 環境安裝與連線問題：見 curriculum\common\SETUP.md
::    （公司 SQL Server 2014 Express 連線為主線；Docker 練習庫僅 x86_64 機器可用）

:: 1. 在公司機上連 SQL Server 2014 Express，載入範例資料庫 learning_db（6 張表）
cd curriculum\common
sqlcmd -S localhost\SQLEXPRESS -E -i seed.sql

:: 2. 從 Day 1 開始
cd ..\day01_select
```

sqlcmd 公司 SQL Server 通常已附帶；安裝與驗證方式見 `curriculum/common/SETUP.md`。

## 課程內容

| 天數 | 主題 |
|------|------|
| [Day 1](curriculum/day01_select/lesson.md) | 連線與 sqlcmd、SQLite→T-SQL 遷移、SELECT、WHERE ✅ |
| [Day 2](curriculum/day02_aggregate_join/lesson.md) | 聚合、GROUP BY/HAVING、JOIN ✅ |
| Day 3 | 子查詢、CTE、INSERT/UPDATE/DELETE 安全實務（規劃中） |
| Day 4 | 交易、索引與執行計畫、T-SQL 程式基礎（規劃中） |
| Day 5 | 視窗函數、實務食譜、C# 串接（SqlClient/Dapper/EF Core）（規劃中） |

每天的資料夾包含：`lesson.md`（觀念）、`exercises.sql`（練習）、`answers.sql`（答案與解說）。
完整架構見 [`curriculum/README.md`](curriculum/README.md)，進度見 [`TODO.md`](TODO.md)。

## 工具

- **sqlcmd**：終端機互動式 SQL shell（類似 sqlite3），Day 1 有完整教學
- **Neovim**：vim-dadbod、vim-dadbod-ui、nvim-treesitter 作為日常查詢加速器
- **C#**：Day 5 介紹 Microsoft.Data.SqlClient、Dapper、Entity Framework Core

## 環境

**以公司環境為主練習場**；本機 Docker 為備用，且僅 x86_64 機器可用
（ARM64 如樹莓派已實測不可行，原因見 [`curriculum/common/SETUP.md`](curriculum/common/SETUP.md) 第 4 章）。

| | 練習環境（備用） | 公司環境（主線） |
|---|---|---|
| 位置 | 本機 Docker（`localhost,1433`，需 x86_64） | `localhost\SQLEXPRESS`（SQL Server 2014 Express） |
| 驗證 | SQL 驗證（sa） | 混合模式 |

教材語法以 **SQL Server 2014** 為準；練習環境引擎較新，遇到 ⚠️ 標示代表該語法 2014 沒有。

## 授權

MIT，見 [LICENSE](LICENSE)。
