#!/usr/bin/env bash
# 離線檢查教材的 T-SQL 是否符合 SQL Server 2014（不需連線、不需 Docker）
#
# 用法：
#   tools/check.sh                       # 檢查 curriculum 下所有 .sql
#   tools/check.sh curriculum/day01_select
#   tools/check.sh path/to/file.sql --verbose
#
# 離開碼：0 = 沒有錯誤；1 = 有錯誤；2 = 參數或環境問題
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

exec dotnet run --project tools/sqlcheck --configuration Release -- "$@"
