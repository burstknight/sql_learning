#!/usr/bin/env bash
# 檢查工具自己的測試：乾淨的 2014 語法要過、2016+ 語法要被抓出來
#
# 用法：tools/test.sh
# 離開碼：0 = 全部符合預期；1 = 有案例不如預期
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

schema="curriculum/common/seed.sql"
failures=0

run_case() {
	local name="$1"
	local expected="$2"
	shift 2

	local output
	local status=0
	output="$(dotnet run --project tools/sqlcheck --configuration Release -- "$@" 2>&1)" || status=$?

	if [[ "$status" -eq "$expected" ]]; then
		echo "PASS  $name（離開碼 $status，符合預期）"
	else
		echo "FAIL  $name（離開碼 $status，預期 $expected）"
		echo "$output" | sed 's/^/      /'
		failures=$((failures + 1))
	fi
}

run_case "2014 可用的語法應通過" 0 "tools/sqlcheck/tests/ok2014.sql" "--schema=$schema"
run_case "2016+ 語法應被擋下" 1 "tools/sqlcheck/tests/newer_syntax.sql" "--schema=$schema"
run_case "教材本身應全部通過" 0 "curriculum" "--schema=$schema"

echo
if [[ "$failures" -eq 0 ]]; then
	echo "全部通過"
else
	echo "$failures 個案例不如預期"
	exit 1
fi
