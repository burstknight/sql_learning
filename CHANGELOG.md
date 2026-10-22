# Change Log


## [Unreleased]
### [Added]
- `tools/sqlcheck/`：離線 T-SQL 2014 檢查器——ScriptDom `TSql120Parser`（2014 文法）＋ DacFx `SqlServerVersion.Sql120` 模型（抓不存在的資料表／欄位）＋ `compat2014.txt` 黑名單（補 `STRING_AGG`、`TRIM` 等解析器放行的 2016+ 函式）。
- `tools/check.sh`：一行檢查 `curriculum/` 下所有 `.sql` 是否符合 SQL Server 2014，不需要資料庫；有問題時離開碼為 1。
- `tools/test.sh` 與 `tools/sqlcheck/tests/`：檢查工具的自測案例（一份乾淨 2014 語法、一份故意違規的 2016+ 語法、以及教材本身）。
- `curriculum/common/SETUP.md`：安裝與環境設定手冊——公司 SQL Server 2014 Express 連線與驗證（主線）、Windows 靜默安裝、x86_64 Linux Docker 佈署、ARM64（樹莓派 5）實測不可行結論、疑難排解。
- `curriculum/README.md`：5 天 SQL 教材學習路線圖、資料夾結構、環境對照與工具清單。
- `TODO.md`：教材產出進度追蹤。
- `curriculum/common/docker-compose.yml`：一鍵啟動練習用 SQL Server（Azure SQL Edge，ARM64）。
- `curriculum/common/seed.sql`：共用範例資料庫 `learning_db`（訂單系統，6 張資料表，SQL Server 2014 相容）。
- `curriculum/day01_select/`：Day 1 課程——環境建置（Docker＋sqlcmd 互動介面教學）、SQLite→T-SQL 遷移對照、SELECT 基礎、WHERE 完整攻略，含 13 題練習與解說答案。
- `curriculum/day02_aggregate_join/`：Day 2 課程——聚合函數（COUNT/AVG 的 NULL 陷阱）、GROUP BY/HAVING、INNER/LEFT JOIN 與多表串接（含 ON vs WHERE 常見坑），含 12 題練習與解說答案。
- `AGENTS.md`：新增「工作流程（Workflow）」章節——動工前確認、編輯規範、Commit 規則（每次修改都要提交，且說明改了什麼與為何）、大變動拆成多次 commit、CHANGELOG 與 TODO 維護方式、Python 一律使用 `uv`、未經允許不得 push、完成前檢查清單與回報格式。

### [Changed]
- `AGENTS.md`：專案現況改為「離線檢查工具＋手動實跑」——新增 `tools/check.sh`／`tools/test.sh` 指令、三層檢查說明與已知限制（暫存表、`ALTER TABLE` 批次跳過參考檢查），移除「完全沒有 build/test」與「ARM64 不可行」的過時敘述；編輯規則與完成檢查清單補上執行檢查工具。
- `README.md`：新增「教材檢查（離線）」章節與工具清單項目；環境章改為「ARM64 需先換 4KB 頁核心，尚未驗證」。
- `curriculum/README.md`：使用方式補上離線檢查步驟；環境對照與資料夾結構的 ARM64 敘述同步更新。
- `curriculum/common/SETUP.md`：第 4 章標題與內容改寫為「16KB 頁核心下的兩條死路」，並新增「換 4KB 頁核心（`kernel8.img`）再走 Azure SQL Edge」的待驗證路線、風險與回滾方式；疑難排解同步更新。
- `TODO.md`：補上檢查工具完成項、Pi 5 4KB 核心實測待辦與工具限制，並修正 Day 1／Day 2 兩條進度黏在同一行的格式。
- `curriculum/day01_select/lesson.md`：第 1 章改為公司環境優先（連線＋seed.sql 載入為起點），sqlcmd 安裝與 Docker 啟動細節移至 SETUP.md，章節瘦身重編為 1.1～1.4。
- `curriculum/README.md`：新增 SETUP.md 連結與資料夾結構項目，環境對照改為「公司主線、本機 Docker 備用（僅 x86_64）」。
- `README.md`：快速開始改為公司連線流程（cmd/bat 語彙，避免 bash 吃掉反斜槓），環境章補上公司主線與 ARM64 不可行的說明與連結。
- `curriculum/common/docker-compose.yml`：練習映像從 Azure SQL Edge 換成官方 SQL Server 2022 Developer（前者已退役，且在 16KB 頁大小核心上實測會崩潰——見 SETUP.md 第 4 章）。
- `TODO.md`：新增「到公司實測 SETUP.md 公司章節」等待辦。
- `README.md`：從只有標題改為完整專案簡介——專案目的、快速開始步驟、5 天課程總覽、工具與環境對照。
- `AGENTS.md`：「Repo status」改寫為專案現況（5 天教材、Day 1–2 已完成、Day 3–5 規劃中、SQL Server 2014 為目標方言、無 build/test/lint/CI、驗證靠 sqlcmd 手動執行），並將與工作流程重覆的內容改為指向 `## Workflow` 的對應章節。
- `.gitignore`：忽略 `.venv/`（Python 虛擬環境目錄）。

### [Fixed]

### [Security]

### [Removed]

### [Deprecated]

