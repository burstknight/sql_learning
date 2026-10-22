# SQL Server 安裝與環境設定手冊（SETUP.md）

把 SQL Server 環境跑起來的操作手冊，配合 5 天課程使用。

實測狀態標記：

- ✅：在 Raspberry Pi 5（Debian 13, ARM64）實際驗證過
- ⚠️：依官方文件整理，尚無環境可實測（用到時請回報問題以便修正）
- ❌：已實測確認**不可行**（附原因與替代方案）

## 先選路徑

| 你的情況 | 看哪一章 |
|----------|---------|
| 公司電腦已裝好 SQL Server 2014 Express（**本課程主線**） | 第 1 章 ⚠️ |
| 想在 Windows 自己裝一台測試機 | 第 2 章 ⚠️ |
| x86_64 Linux 想跑本機練習庫 | 第 3 章 ⚠️ |
| ARM64 Linux（樹莓派等，含本機 Pi 5） | 第 4 章 ❌ **先讀** |

---

## 一、公司環境（SQL Server 2014 Express，本課程主線）⚠️

以下依既有知識整理，**待實際到公司連線後驗證並回填**（驗證清單見 1.6）。

### 1.1 sqlcmd 在哪

SQL Server 2014 Express 安裝時通常附帶 sqlcmd（命令列工具）。開 cmd 或
PowerShell 輸入 `sqlcmd -?`，有版本資訊就是可用。

找不到時，試完整路徑（SQLEXPRESS 實例的版本號是 Mssql12）：

```bat
:: 依安裝選項不同，常見位置之一：
"C:\Program Files\Microsoft SQL Server\MSSQL12.SQLEXPRESS\Tools\Binn\sqlcmd.exe" -?
"C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\110\Tools\Binn\sqlcmd.exe" -?
```

都沒有就到 <https://github.com/microsoft/go-sqlcmd/releases> 下載 Windows 版
（單一執行檔，放到任何 PATH 目錄即可）。

### 1.2 第一次連線

```bat
sqlcmd -S localhost\SQLEXPRESS -E
1> SELECT @@VERSION;
2> GO
```

- `-E`：Windows 驗證（用登入 Windows 的身分，不用密碼）。混合模式環境下建議優先用它
- SQL 驗證：`sqlcmd -S localhost\SQLEXPRESS -U some_user`（省略 `-P` 會提示輸入密碼）
- 公司若有提供專屬學習帳號，優先用它，別拿系統管理員帳號練習
- cmd/PowerShell 中 `\S` 不用跳脫；若在 bash 或腳本中外傳，整個伺服器名加引號

### 1.3 建立練習資料庫

教材的範例資料庫 `seed.sql`（訂單系統，6 張表）是 SQL Server 2014 相容語法，
在公司環境跑過就算通過「2014 相容性」實證：

```bat
:: 在 repo 的 curriculum\common\ 目錄下執行（公司機器若沒 clone repo，把 seed.sql 拷過去即可）
sqlcmd -S localhost\SQLEXPRESS -E -i seed.sql

:: 驗證：查得到資料就成功
sqlcmd -S localhost\SQLEXPRESS -E -d learning_db -Q "SELECT COUNT(*) FROM dbo.Customers;"
```

需要「建立資料庫」權限——一般開發機的預設帳號就有；帳號受限時請管理員幫忙建立
`learning_db` 後再跑 seed.sql。

### 1.4 命名實例是什麼（`localhost\SQLEXPRESS`）

Windows 上的 SQL Server 可以裝多個「實例」，用名稱區分。`localhost\SQLEXPRESS`
意思是「本機的 SQLEXPRESS 實例」——注意是**反斜槓**（跟 Windows 路徑一樣），
不是埠號。Docker 那種 `localhost,1433` 是「預設實例＋明確埠號」，兩種寫法別混用。

- 從同一台電腦連命名實例走 Shared Memory 協定，**不需要知道埠號**（埠號是動態分配的）
- 從別台電腦連才需要：伺服器名＋明確埠號，且要防火牆放行——練習用不到，先跳過

### 1.5 Express 版限制（練習時可能遇到）

| 限制 | 影響 |
|------|------|
| 單一資料庫最大 10GB | 練習遠遠夠用 |
| 沒有 SQL Agent（排程代理） | 依賴排程的教學範例不能用，先跳過 |
| CPU/記憶體使用上限 | 練習無感 |

### 1.6 到公司後的驗證清單 ⚠️

1. `sqlcmd -?`——可用？路徑是什麼？（回填 1.1）
2. `sqlcmd -S localhost\SQLEXPRESS -E -Q "SELECT @@VERSION;"`——版本字串含 `2014`？
   伺服器名真的是 `localhost\SQLEXPRESS`？（回填 1.2）
3. 可建資料庫：`-Q "CREATE DATABASE learning_db_test; DROP DATABASE learning_db_test;"`
4. 完整跑一次 1.3 的 seed.sql 流程
5. 有異動就把實際值回填到本章

---

## 二、Windows 靜默安裝 SQL Server Express（未實測）⚠️

公司新電腦重灌、或想在 Windows 掛一台測試機時，可跳過安裝精靈一鍵佈署。
依官方文件整理，參數如有異動請查
[官方安裝參數文件](https://learn.microsoft.com/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt)。

1. 到 [SQL Server 下載頁](https://www.microsoft.com/zh-tw/sql-server/sql-server-downloads)
   取得 Express 安裝檔（檔名類似 `SQLEXPR_x64_ENU.exe`）。檔案是自解壓縮包，
   先解壓取得內部的 `setup.exe`：

```bat
:: 在「開發人員命令提示字元」或 cmd 執行（需管理員權限）：
SQLEXPR_x64_ENU.exe /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=SQLEXPRESS ^
	/SECURITYMODE=SQL /SAPWD="YourStrong!Passw0rd" ^
	/IACCEPTSQLSERVERLICENSETERMS /QS
```

參數解說：

| 參數 | 意思 |
|------|------|
| `/ACTION=INSTALL` | 執行安裝（必要） |
| `/FEATURES=SQL` | 只裝引擎核心（不含 Management Studio 等，夠練習用） |
| `/INSTANCENAME=SQLEXPRESS` | 命名實例名稱，就是日後連線的 `localhost\SQLEXPRESS` |
| `/SECURITYMODE=SQL /SAPWD=...` | 啟用 SQL 驗證並設定 sa 密碼（不加的話只有 Windows 驗證） |
| `/IACCEPTSQLSERVERLICENSETERMS` | 靜默安裝必須的授權確認 |
| `/QS` | 顯示簡化介面（完全無畫面改 `/Q`） |

安裝完成後服務名稱為 `MSSQL$SQLEXPRESS`，用 `services.msc` 或
`net start MSSQL$SQLEXPRESS` 管理。連線方式見第 1 章。

---

## 三、x86_64 Linux 本機 Docker 練習庫（未實測）⚠️

想在自己的 x86_64 Linux 電腦或伺服器上跑一台練習用 SQL Server 時用。
官方 SQL Server **沒有 ARM64 版**；ARM64 機器請直接看第 4 章的實測結論。

### 3.1 安裝 Docker（Debian／Ubuntu）

已裝過就跳過。安裝完記得讓一般使用者能跑 docker（`sudo usermod -aG docker $USER`，
需重新登入生效）。

```bash
sudo apt update && sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
	-o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
	https://download.docker.com/linux/debian \
	$(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Ubuntu 把上面的 `/linux/debian` 換成 `/linux/ubuntu` 即可。

### 3.2 啟動練習資料庫

`curriculum/common/docker-compose.yml` 使用官方 **SQL Server 2022 Developer 版**
映像（免費開發用途）：

```bash
cd curriculum/common
docker compose up -d		# 第一次會下載映像約 2GB
docker ps			# STATUS 應為 Up，名稱 sql_learning_db
```

等待約 10 秒讓引擎完成初始化。常見啟動失敗：

| 現象 | 原因與解法 |
|------|-----------|
| `Password validation failed` | 密碼不符合複雜度（要有大小寫、數字、符號）。compose 內建的 `LearningP@ssw0rd` 已符合 |
| 容器啟動後立刻退出 | 看日誌：`docker logs sql_learning_db`。常見是記憶體不足（需 ≥ 2GB 可用） |
| `port is already allocated` | 1433 被佔用：改 compose 的 ports 映射，或 `ss -tlnp \| grep 1433` 找出佔用者 |

### 3.3 驗證與載入範例資料庫

sqlcmd 安裝（兩種擇一）：

```bash
# 方式 A（推薦）：go-sqlcmd 單一執行檔（GitHub releases 有 linux_arm64/amd64）
mkdir -p ~/.local/bin
tar -xzf go-sqlcmd_*_linux_*.tar.gz -C ~/.local/bin sqlcmd
export PATH="$HOME/.local/bin:$PATH"	# 加進 ~/.bashrc 可永久生效

# 方式 B：apt 套件（需先加微軟 repo，見 3.5）
sudo apt install -y mssql-tools18
```

```bash
# 1. 連得上嗎
sqlcmd -S localhost,1433 -U sa -P 'LearningP@ssw0rd' -Q "SELECT GETDATE();"
# 2. 載入範例資料庫（在 curriculum/common/ 下）
sqlcmd -S localhost,1433 -U sa -P 'LearningP@ssw0rd' -i seed.sql
# 3. 查得到資料嗎（應顯示進口耳機 1200、鍵盤 480、印表機耗材 890）
sqlcmd -S localhost,1433 -U sa -P 'LearningP@ssw0rd' -d learning_db \
	-Q "SELECT TOP 3 ProductName, UnitPrice FROM dbo.Products ORDER BY UnitPrice DESC;"
```

密碼不想留在 shell history：省略 `-P`，sqlcmd 會提示輸入。

### 3.4 重來（刪光重建）

```bash
docker compose down -v		# -v 連資料 volume 一起刪
docker compose up -d		# 重新建立後要再載入一次 seed.sql
```

### 3.5 Linux 指令安裝（不依賴 Docker，伺服器佈署用）

想把 SQL Server 直接裝成系統服務、可寫進佈署腳本時用。⚠️ 依官方文件整理。

```bash
# 1. 匯入微軟 GPG 金鑰與 repo（Debian 12 示範；Ubuntu 用 config/ubuntu/<版本>/prod.list）
curl https://packages.microsoft.com/keys/microsoft.asc | \
	sudo tee /etc/apt/trusted.gpg.d/microsoft.asc > /dev/null
sudo add-repository \
	"$(curl https://packages.microsoft.com/config/debian/12/prod.list)"

# 2. 安裝資料庫引擎（只有 x86_64；repo 對 arm64 架構不提供 mssql-server）
sudo apt update && sudo apt install -y mssql-server

# 3. 一次性設定：管理員密碼＋啟動（會把服務設為開機自啟）
sudo /opt/mssql/bin/mssql-conf setup

# 4. 驗證
systemctl status mssql-server		# 應顯示 active (running)
sqlcmd -S localhost -U sa
```

---

## 四、ARM64 Linux（與本機 Pi 5）：16KB 頁核心的兩條死路 ❌（4KB 核心待驗證）

本教材原規劃用樹莓派 5 跑 Azure SQL Edge（微軟官方唯一的 ARM64 SQL Server
容器）。2026-10-20 於本機（Pi 5 16GB、Debian 13 aarch64）完整實測，預設核心下
兩條路都走死，記錄如下以免後人重蹈覆轍；最後一小節是還沒實測的 4KB 頁核心路線。

### ❌ 路線 A：Azure SQL Edge 原生 ARM64

- 症狀：容器啟動後立刻退出（exit 1），日誌出現
  `<jemalloc>: Unsupported system page size`
- 原因：Pi 的 Debian 13 核心頁大小已是 **16KB**（舊發行版常見 4KB）；
  SQL Edge 內建的 jemalloc 只支援較小頁大小，直接崩潰
- 官方追蹤：<https://github.com/microsoft/mssql-docker/issues/824>；
  且 Azure SQL Edge 已於 2025-11 退役，**不會再修**
- 自行確認：

```bash
getconf PAGE_SIZE	# 輸出 16384（16KB）＝ 這條路不通；4096 才有機會
```

### ❌ 路線 B：qemu 模擬 x86_64 版 SQL Server

- 做法：binfmt＋qemu 使用者模式跑官方 x86_64 映像。一般 x86 小程式正常，
  但 sqlservr 載入函式庫時報
  `error while loading shared libraries: libcrypto.so.3: failed to map segment from shared object`
- 原因：qemu 得把 4KB 對齊的 x86 ELF 交給 16KB 頁核心做映射，特定檔案必炸。
  實測逐檔替換 libcrypto、libresolv 後能過關，但 libatomic 即使換成 Debian
  官方版仍然炸；好壞檔案的 ELF 結構完全相同，**沒有可預測的修復規則**
- 結論：就算打地鼠打完，TCG 模擬速度慢、且有執行期記憶體錯位風險——
  不適合作為每天要用的練習環境，到此止步

### 🧪 待驗證：換成 4KB 頁核心後再走路線 A（尚未實測）

Raspberry Pi OS 的核心有兩種頁大小：預設的 `kernel_2712.img` 是 **16KB** 頁，
另外附一份 `kernel8.img` 是 **4KB** 頁。把開機設定指到 4KB 版本後，路線 A 的
jemalloc 崩潰應該就會消失，可以直接跑 `mcr.microsoft.com/azure-sql-edge`
（arm64 原生映像，已 pull 得到）。

做法（改完要重開機，且**改錯會開不了機**）：

1. 先確認素材都在：`ls /boot/firmware/kernel8.img`、`ls -d /lib/modules/*+rpt-rpi-v8`
2. 備份 `/boot/firmware/config.txt`，並想好救援方式（另一張 SD 卡，或接螢幕鍵盤）
3. 在 `/boot/firmware/config.txt` 的 `[all]` 段落加一行 `kernel=kernel8.img`
4. 重開機後驗證 `getconf PAGE_SIZE` 應變成 **4096**
5. 再啟動 SQL Edge 容器；能起來就代表路線 A 復活

風險與限制：

- Pi 5 跑 4KB 頁核心等於用 Pi 4 世代的核心設定，部分周邊／效能特性可能不同
- Azure SQL Edge 已於 2025-11 退役，映像不再更新、也不支援全文檢索／In-Memory OLTP／
  CLR／SQL Agent；引擎血統是 2019（15.x），`COMPATIBILITY_LEVEL = 120` 只能蓋掉
  部分差異——教材語法仍要靠 `tools/check.sh` 離線檢查把關
- 回滾：把 `kernel=` 那行刪掉或改回 `kernel=kernel_2712.img` 再重開機
- 驗證成功後，本章與 `docker-compose.yml` 再一起更新（見 `TODO.md`）

### 其他選項

- 或改用 x86_64 機器（第 3 章）
- 或直接用公司環境（第 1 章——本課程主線，也正是最準的目標環境）

---

## 五、疑難排解

| 現象 | 原因與解法 |
|------|-----------|
| `Login failed for user 'sa'` | 密碼打錯，或容器是用不同密碼建立的：`docker compose down -v` 重來最快 |
| `TCP connection was refused` | 容器還沒好（初次啟動約 10～30 秒）或沒在跑：`docker ps`、`docker logs sql_learning_db` |
| `The database 'learning_db' does not exist` | 還沒載入 seed.sql（第 1.3 或 3.3 節） |
| 連得上但中文變亂碼 | 終端機編碼：`locale` 應含 UTF-8 |
| SQL 指令貼上沒反應 | sqlcmd 要獨立一行 `GO` 才會執行（見 Day 1 lesson） |
| ARM Linux 上容器一啟動就死、log 有 jemalloc 字樣 | 核心是 16KB 頁，換 4KB 頁核心可解但尚未驗證，見第 4 章 |
| qemu/binfmt 環境出現 `failed to map segment` | 同上，見第 4 章 ❌ |
| 不確定自己的核心頁大小 | `getconf PAGE_SIZE`：16384 ＝ 16KB（第 4 章的兩條死路）；4096 ＝ 4KB |
| `GO` 被 SQL Server 語法檢查罵 | `GO` 是 sqlcmd 等工具的指令、不是 T-SQL；C# 與 vim-dadbod 送 SQL 時都沒有 GO |
