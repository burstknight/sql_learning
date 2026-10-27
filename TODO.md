# To Do List

## 教材產出

- [x] 規劃 5 天課程架構與 `curriculum/README.md`
- [x] Day 1：環境建置、sqlcmd、SQLite→T-SQL 遷移、SELECT、WHERE
- [x] Day 2：聚合、GROUP BY/HAVING、JOIN
- [x] Day 3：子查詢、CTE、INSERT/UPDATE/DELETE 安全實務
- [x] Day 4：交易與隔離級別、索引與執行計畫、變數與流程控制
- [ ] Day 5：視窗函數、實務食譜、C# 串接（SqlClient/Dapper/EF Core）

## 待辦

- [x] 離線 T-SQL 2014 檢查工具：`tools/sqlcheck/`＋`tools/check.sh`／`tools/test.sh`，
      涵蓋語法（ScriptDom `TSql120Parser`）、參考（DacFx `SqlServerVersion.Sql120` 模型）
      與新函式黑名單（`compat2014.txt`）；`tools/test.sh` 全數通過
- [ ] **Pi 5 換 4KB 頁核心並實跑 SQL Edge**：`getconf PAGE_SIZE` 需變成 4096、容器能啟動、
      `seed.sql` 載得進去，且 Day 1／Day 2 `answers.sql` 的 `-- 預期：` 數值全部對上
- [ ] 承上：驗證成功後更新 `curriculum/common/SETUP.md` 第 4 章（把「待驗證」改成實測結果）
      與 `curriculum/common/docker-compose.yml`（改回 `azure-sql-edge`、連接埠綁 `127.0.0.1`）
- [ ] 檢查工具限制：含暫存表（`#t`）、`sp_executesql` 與 `ALTER TABLE` 的批次目前跳過 DacFx 參考檢查，
      想辦法讓 Day 3 之後的 DDL／DML 也能驗證
- [ ] 檢查工具延伸：掃描 `lesson.md` 的 SQL 程式碼區塊（跳過標 ⚠️ 的新版語法示範），
      讓教材本文的範例也自動驗證
- [ ] **到公司實測 `SETUP.md` 第 1 章（公司環境章節）**：sqlcmd 實際路徑與連線、
      伺服器名確認、`seed.sql` 在 SQL Server 2014 實跑，並回填驗證清單（1.6）
- [ ] 如有機會實測 `SETUP.md` 第 2 章（Windows 靜默安裝）——僅在有閒置 Windows 機器時
- [ ] 使用者回饋 Day 1/2 內容後修正
- [ ] 全部完成后更新根目錄 `README.md`
