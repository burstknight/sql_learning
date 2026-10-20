# Change Log


## [Unreleased]
### [Added]
- `curriculum/common/SETUP.md`：安裝與環境設定手冊——公司 SQL Server 2014 Express 連線與驗證（主線）、Windows 靜默安裝、x86_64 Linux Docker 佈署、ARM64（樹莓派 5）實測不可行結論、疑難排解。
- `curriculum/README.md`：5 天 SQL 教材學習路線圖、資料夾結構、環境對照與工具清單。
- `TODO.md`：教材產出進度追蹤。
- `curriculum/common/docker-compose.yml`：一鍵啟動練習用 SQL Server（Azure SQL Edge，ARM64）。
- `curriculum/common/seed.sql`：共用範例資料庫 `learning_db`（訂單系統，6 張資料表，SQL Server 2014 相容）。
- `curriculum/day01_select/`：Day 1 課程——環境建置（Docker＋sqlcmd 互動介面教學）、SQLite→T-SQL 遷移對照、SELECT 基礎、WHERE 完整攻略，含 13 題練習與解說答案。
- `curriculum/day02_aggregate_join/`：Day 2 課程——聚合函數（COUNT/AVG 的 NULL 陷阱）、GROUP BY/HAVING、INNER/LEFT JOIN 與多表串接（含 ON vs WHERE 常見坑），含 12 題練習與解說答案。

### [Changed]
- `curriculum/day01_select/lesson.md`：第 1 章改為公司環境優先（連線＋seed.sql 載入為起點），sqlcmd 安裝與 Docker 啟動細節移至 SETUP.md，章節瘦身重編為 1.1～1.4。
- `curriculum/README.md`：新增 SETUP.md 連結與資料夾結構項目，環境對照改為「公司主線、本機 Docker 備用（僅 x86_64）」。
- `README.md`：快速開始改為公司連線流程（cmd/bat 語彙，避免 bash 吃掉反斜槓），環境章補上公司主線與 ARM64 不可行的說明與連結。
- `curriculum/common/docker-compose.yml`：練習映像從 Azure SQL Edge 換成官方 SQL Server 2022 Developer（前者已退役，且在 16KB 頁大小核心上實測會崩潰——見 SETUP.md 第 4 章）。
- `TODO.md`：新增「到公司實測 SETUP.md 公司章節」等待辦。
- `README.md`：從只有標題改為完整專案簡介——專案目的、快速開始步驟、5 天課程總覽、工具與環境對照。

### [Fixed]

### [Security]

### [Removed]

### [Deprecated]

