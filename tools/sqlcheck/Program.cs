// tools/sqlcheck：用微軟官方解析器驗證教材的 T-SQL 是否符合 SQL Server 2014
//
// 三層檢查：
//   1. 語法：ScriptDom 的 TSql120Parser（SQL Server 2014 文法）
//   2. 參考：DacFx 以 SqlServerVersion.Sql120 建模型，抓「資料表／欄位不存在」
//   3. 版本：compat2014.txt 黑名單，補解析器抓不到的 2016+ 函式
//
// 用法：dotnet run --project tools/sqlcheck -- [路徑...] [--schema=seed.sql] [--verbose]
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.SqlServer.Dac.Model;
using Microsoft.SqlServer.TransactSql.ScriptDom;

namespace SqlCheck;

internal sealed record Issue(string File, int Line, int Column, string Kind, string Message);

internal sealed record Batch(int Line, string Text);

internal sealed record CompatRule(Regex Pattern, string Message);

internal static class Program {
	private const string KindSyntax = "語法";
	private const string KindCompat = "2014";
	private const string KindReference = "參考";
	private const string KindWarning = "提醒";

	private static readonly Regex GoPattern = new(
		@"^\s*GO\s*(\d+)?\s*(--.*)?$",
		RegexOptions.IgnoreCase | RegexOptions.Compiled);

	private static readonly Regex UsePattern = new(
		@"(?im)^[ \t]*USE[ \t]+(\[[^\]]+\]|\w+)[ \t]*;?[ \t]*$",
		RegexOptions.Compiled);

	private static int Main(string[] args) {
		var targets = new List<string>();
		string? schema = null;
		var verbose = false;

		foreach (var arg in args) {
			if (arg is "--verbose" or "-v")
				verbose = true;
			else if (arg.StartsWith("--schema=", StringComparison.Ordinal))
				schema = arg["--schema=".Length..];
			else if (arg.StartsWith("--", StringComparison.Ordinal)) {
				Console.Error.WriteLine($"未知參數：{arg}");
				return 2;
			} else
				targets.Add(arg);
		}

		if (targets.Count == 0)
			targets.Add("curriculum");

		var files = targets
						.SelectMany(t => Directory.Exists(t)
								? Directory.EnumerateFiles(t, "*.sql", SearchOption.AllDirectories)
								: [t])
						.Select(Path.GetFullPath)
						.Where(f => !HasDirSegment(f, "bin") && !HasDirSegment(f, "obj"))
						.Distinct()
						.OrderBy(f => f, StringComparer.Ordinal)
						.ToList();

		if (files.Count == 0) {
			Console.Error.WriteLine("找不到任何 .sql 檔");
			return 2;
		}

		var rules = LoadRules(Path.Combine(AppContext.BaseDirectory, "compat2014.txt"));
		var issues = new List<Issue>();
		var batchCount = 0;

		foreach (var file in files) {
			var text = File.ReadAllText(file);
			var display = Display(file);
			var batches = SplitBatches(text);
			batchCount += batches.Count;

			issues.AddRange(CheckCompat(display, text, rules));

			var parser = new TSql120Parser(true);
			var clean = new List<(Batch Batch, TSqlScript Script)>();
			foreach (var batch in batches) {
				if (!HasCode(batch.Text))
					continue;

				using var reader = new StringReader(StripToolCommands(batch.Text));
				var script = parser.Parse(reader, out var parseErrors) as TSqlScript;
				foreach (var error in parseErrors)
					issues.Add(new Issue(display, batch.Line + error.Line - 1, error.Column, KindSyntax, error.Message.Trim()));
				if (parseErrors.Count == 0 && script is not null)
					clean.Add((batch, script));
			}

			var schemaPath = schema ?? FindSchema(file);
			if (schemaPath is null || Path.GetFullPath(schemaPath) != file)
				issues.AddRange(CheckReferences(display, clean, schemaPath));

			if (verbose)
				Console.WriteLine($"  {display}：{batches.Count} 批次");
		}

		issues.AddRange(CheckPairing(files));

		var ordered = issues
						  .GroupBy(i => (i.File, i.Line, i.Column, i.Kind, i.Message))
						  .Select(g => g.First())
						  .OrderBy(i => i.File, StringComparer.Ordinal)
						  .ThenBy(i => i.Line)
						  .ThenBy(i => i.Column)
						  .ToList();

		foreach (var issue in ordered)
			Console.WriteLine($"{issue.File}:{issue.Line}:{issue.Column}\t[{issue.Kind}] {issue.Message}");

		var errors = ordered.Count(i => i.Kind != KindWarning);
		var warnings = ordered.Count - errors;
		Console.WriteLine();
		Console.WriteLine($"檢查 {files.Count} 個檔案、{batchCount} 個批次：{errors} 個錯誤、{warnings} 個提醒");
		return errors == 0 ? 0 : 1;
	}

	private static bool HasDirSegment(string path, string segment) => path.Contains($"{Path.DirectorySeparatorChar}{segment}{Path.DirectorySeparatorChar}", StringComparison.Ordinal);

	private static string Display(string path) {
		var relative = Path.GetRelativePath(Environment.CurrentDirectory, path);
		return relative.StartsWith("..", StringComparison.Ordinal) ? path : relative;
	}

	private static string? FindSchema(string file) {
		var dir = Path.GetDirectoryName(Path.GetFullPath(file));
		while (dir is not null) {
			var candidate = Path.Combine(dir, "common", "seed.sql");
			if (File.Exists(candidate))
				return candidate;
			dir = Path.GetDirectoryName(dir);
		}
		return null;
	}

	private static List<CompatRule> LoadRules(string path) {
		var rules = new List<CompatRule>();
		if (!File.Exists(path)) {
			Console.Error.WriteLine($"警告：找不到規則檔 {path}，跳過版本黑名單檢查");
			return rules;
		}

		foreach (var raw in File.ReadAllLines(path)) {
			var line = raw.TrimEnd();
			if (line.Length == 0 || line.TrimStart().StartsWith('#'))
				continue;
			var parts = line.Split('\t', 2);
			if (parts.Length != 2) {
				Console.Error.WriteLine($"警告：規則格式錯誤（需以 TAB 分隔）：{line}");
				continue;
			}
			rules.Add(new CompatRule(
				new Regex(parts[0], RegexOptions.IgnoreCase | RegexOptions.Compiled),
				parts[1].Trim()));
		}
		return rules;
	}

	private static List<Batch> SplitBatches(string text) {
		var result = new List<Batch>();
		var lines = text.Replace("\r\n", "\n").Split('\n');
		var buffer = new StringBuilder();
		var start = 1;

		for (var i = 0; i < lines.Length; i++) {
			if (GoPattern.IsMatch(lines[i])) {
				if (buffer.Length > 0)
					result.Add(new Batch(start, buffer.ToString()));
				buffer.Clear();
				start = i + 2;
				continue;
			}
			if (buffer.Length == 0)
				start = i + 1;
			buffer.Append(lines[i]).Append('\n');
		}

		if (buffer.Length > 0)
			result.Add(new Batch(start, buffer.ToString()));
		return result;
	}

	private static string StripToolCommands(string text) => string.Join('\n', text.Split('\n').Select(l => l.TrimStart().StartsWith(':') ? string.Empty : l));

	private static string StripUse(string text) => UsePattern.Replace(text, string.Empty);

	private static bool HasCode(string text) => StripCommentsAndStrings(text).Trim().Length > 0;

	private static List<Issue> CheckCompat(string display, string text, List<CompatRule> rules) {
		var issues = new List<Issue>();
		if (rules.Count == 0)
			return issues;

		var stripped = StripCommentsAndStrings(text);
		var lineStarts = LineStarts(stripped);
		foreach (var rule in rules) {
			foreach (Match match in rule.Pattern.Matches(stripped)) {
				var (line, column) = Locate(lineStarts, match.Index);
				issues.Add(new Issue(display, line, column, KindCompat, rule.Message));
			}
		}
		return issues;
	}

	private static List<int> LineStarts(string text) {
		var starts = new List<int> { 0 };
		for (var i = 0; i < text.Length; i++)
			if (text[i] == '\n')
				starts.Add(i + 1);
		return starts;
	}

	private static (int Line, int Column) Locate(List<int> lineStarts, int index) {
		var lo = 0;
		var hi = lineStarts.Count - 1;
		while (lo < hi) {
			var mid = (lo + hi + 1) / 2;
			if (lineStarts[mid] <= index)
				lo = mid;
			else
				hi = mid - 1;
		}
		return (lo + 1, index - lineStarts[lo] + 1);
	}

	// 把註解與字串常值換成空白（長度與換行保持不變），避免誤判
	private static string StripCommentsAndStrings(string text) {
		var chars = text.ToCharArray();
		var i = 0;
		while (i < chars.Length) {
			if (chars[i] == '-' && i + 1 < chars.Length && chars[i + 1] == '-') {
				while (i < chars.Length && chars[i] != '\n')
					chars[i++] = ' ';
			} else if (chars[i] == '/' && i + 1 < chars.Length && chars[i + 1] == '*') {
				while (i < chars.Length) {
					if (chars[i] == '*' && i + 1 < chars.Length && chars[i + 1] == '/') {
						chars[i++] = ' ';
						chars[i++] = ' ';
						break;
					}
					if (chars[i] != '\n')
						chars[i] = ' ';
					i++;
				}
			} else if (chars[i] == '\'') {
				chars[i++] = ' ';
				while (i < chars.Length) {
					if (chars[i] == '\'') {
						if (i + 1 < chars.Length && chars[i + 1] == '\'') {
							chars[i++] = ' ';
							chars[i++] = ' ';
							continue;
						}
						chars[i++] = ' ';
						break;
					}
					if (chars[i] != '\n')
						chars[i] = ' ';
					i++;
				}
			} else if (chars[i] == '[') {
				i++;
				while (i < chars.Length && chars[i] != ']')
					chars[i++] = ' ';
				if (i < chars.Length)
					i++;
			} else
				i++;
		}
		return new string(chars);
	}

	private static List<Issue> CheckReferences(
		string display,
		List<(Batch Batch, TSqlScript Script)> batches,
		string? schemaPath) {
		var issues = new List<Issue>();
		if (schemaPath is null || !File.Exists(schemaPath) || batches.Count == 0)
			return issues;

		var schema = ExtractSchema(schemaPath);
		if (schema.Count == 0)
			return issues;

		var added = new List<string>();
		TSqlModel? model = null;

		TSqlModel ? Rebuild() {
			try {
				var fresh = new TSqlModel(SqlServerVersion.Sql120, new TSqlModelOptions());
				foreach (var statement in schema)
					fresh.AddObjects(statement);
				foreach (var script in added)
					fresh.AddObjects(script);
				return fresh;
			} catch (DacModelException ex) {
				issues.Add(new Issue(display, 1, 1, KindWarning, $"無法用 seed.sql 建立 2014 模型：{Compact(ex.Message)}"));
				return null;
			}
		}

		model = Rebuild();
		if (model is null)
			return issues;

		var lineOf = new Dictionary<string, int>(StringComparer.Ordinal);
		var index = 0;

		foreach (var (batch, script) in batches) {
			var body = StripUse(batch.Text);
			if (!HasCode(body))
				continue;

			// DacFx 無法模型化暫存表（#t），含暫存表的批次跳過語意檢查
			if (HasTempTable(body))
				continue;

			// DacFx 的模型是宣告式的，不接受用 ALTER TABLE 追加欄位／條件約束
			if (script.Batches.SelectMany(b => b.Statements).Any(s => s is AlterTableStatement)) {
				issues.Add(new Issue(
					display,
					batch.Line,
					1,
					KindWarning,
					"含 ALTER TABLE，DacFx 模型無法套用變更，已跳過此批次的參考檢查"));
				continue;
			}

			var isDdl = script.Batches
							.SelectMany(b => b.Statements)
							.Any(IsDdl);

			string[] scripts;
			if (isDdl) {
				scripts = [..SplitStatements(script, batch.Text)];
			} else {
				index++;
				var name = $"__check_{index}";
				lineOf[name] = batch.Line;
				scripts = [$"CREATE PROCEDURE dbo.{name} AS BEGIN\n{body}\nEND"];
			}

			foreach (var sql in scripts) {
				try {
					model.AddObjects(sql);
					added.Add(sql);
				} catch (DacModelException ex) {
					issues.Add(new Issue(display, batch.Line, 1, KindReference, Compact(ex.Message)));
					model = Rebuild();
					if (model is null)
						return issues;
				}
			}
		}

		try {
			foreach (var error in model.Validate()) {
				var message = Compact(error.Message);
				var line = 1;
				var match = Regex.Match(message, @"__check_(\d+)");
				if (match.Success && lineOf.TryGetValue(match.Value, out var mapped))
					line = mapped;
				issues.Add(new Issue(display, line, 1, KindReference, message));
			}
		} catch (Exception ex) when (ex is not OutOfMemoryException) {
			issues.Add(new Issue(display, 1, 1, KindWarning, $"DacFx 驗證失敗：{Compact(ex.Message)}"));
		}

		return issues;
	}

	private static bool HasTempTable(string text) => Regex.IsMatch(StripCommentsAndStrings(text), @"##?[A-Za-z_0-9]");

	private static List<string> ExtractSchema(string path) {
		var parser = new TSql120Parser(true);
		var parts = new List<string>();

		foreach (var batch in SplitBatches(File.ReadAllText(path))) {
			if (!HasCode(batch.Text))
				continue;

			using var reader = new StringReader(batch.Text);
			var script = parser.Parse(reader, out var errors) as TSqlScript;
			if (errors.Count > 0 || script is null)
				continue;

			if (!script.Batches.SelectMany(b => b.Statements).Any(s => s is CreateTableStatement))
				continue;

			parts.AddRange(SplitStatements(script, batch.Text).Where(s => s.Contains("CREATE TABLE", StringComparison.OrdinalIgnoreCase)));
		}

		return parts;
	}

	// 依 ScriptDom 的位移把一個批次拆成單一陳述式（DacFx 的 AddObjects 一次只吃一個）
	private static List<string> SplitStatements(TSqlScript script, string text) {
		var parts = new List<string>();
		foreach (var batch in script.Batches) {
			foreach (var statement in batch.Statements) {
				if (statement is UseStatement)
					continue;
				var start = Math.Clamp(statement.StartOffset, 0, text.Length);
				var length = Math.Clamp(statement.FragmentLength, 0, text.Length - start);
				if (length > 0)
					parts.Add(text.Substring(start, length));
			}
		}
		return parts;
	}

	private static bool IsDdl(TSqlStatement statement) => statement is
		CreateTableStatement or AlterTableStatement or
		CreateViewStatement or AlterViewStatement or DropViewStatement or
		CreateIndexStatement or DropIndexStatement or
		CreateProcedureStatement or AlterProcedureStatement or DropProcedureStatement or
		CreateFunctionStatement or AlterFunctionStatement or DropFunctionStatement or
		CreateTriggerStatement or DropTriggerStatement or
		CreateSchemaStatement or DropSchemaStatement or
		CreateTypeStatement or CreateSequenceStatement or CreateDatabaseStatement;

	private static List<Issue> CheckPairing(List<string> files) {
		var issues = new List<Issue>();
		var directories = files
							  .Select(f => Path.GetDirectoryName(f)!)
							  .Distinct(StringComparer.Ordinal);

		foreach (var dir in directories) {
			var hasExercises = File.Exists(Path.Combine(dir, "exercises.sql"));
			var hasAnswers = File.Exists(Path.Combine(dir, "answers.sql"));
			if (hasExercises == hasAnswers)
				continue;

			var missing = hasExercises ? "answers.sql" : "exercises.sql";
			issues.Add(new Issue(
				Display(dir),
				1,
				1,
				KindWarning,
				$"缺少 {missing}（練習與答案必須成對）"));
		}
		return issues;
	}

	private static string Compact(string text) => Regex.Replace(text, @"\s+", " ").Trim();
}
