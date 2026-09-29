import 'dart:io';
import '../models/benchmark_models.dart';

class EvaluationResult {
  final String status; // 'pass', 'fail', 'error', 'completed'
  final double scorePercent;
  final String details;

  EvaluationResult({
    required this.status,
    required this.scorePercent,
    required this.details,
  });
}

class BenchmarkEvaluator {
  static Future<EvaluationResult> evaluate({
    required String testId,
    required String responseText,
  }) async {
    final clean = responseText.trim();
    if (clean.isEmpty) {
      return EvaluationResult(
        status: 'fail',
        scorePercent: 0.0,
        details: 'Empty response received from model.',
      );
    }

    switch (testId) {
      case MdBenchConstants.testGeneralProseId:
        return _evaluateGeneralProse(clean);
      case MdBenchConstants.testLogicReasoningId:
        return _evaluateLogicReasoning(clean);
      case MdBenchConstants.testPythonCodingId:
        return await _evaluatePythonCoding(clean);
      case MdBenchConstants.testInstructionFollowingId:
        return _evaluateInstructionFollowing(clean);
      default:
        return EvaluationResult(
          status: 'completed',
          scorePercent: 100.0,
          details: 'Unscored custom test',
        );
    }
  }

  static EvaluationResult _evaluateGeneralProse(String text) {
    final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return EvaluationResult(
      status: 'completed',
      scorePercent: 100.0,
      details: 'Preserved for human review ($wordCount words generated). Titanic maiden-voyage prose.',
    );
  }

  static EvaluationResult _evaluateLogicReasoning(String text) {
    // Look for explicit FINAL ANSWER: <val>
    final regex = RegExp(r'FINAL\s+ANSWER:\s*([^\r\n]+)', caseSensitive: false);
    final match = regex.allMatches(text).toList();

    String finalAnswerSnippet = '';
    if (match.isNotEmpty) {
      finalAnswerSnippet = match.last.group(1)?.trim() ?? '';
    } else {
      // Fallback: check the last non-empty line
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isNotEmpty) {
        finalAnswerSnippet = lines.last;
      }
    }

    // Expected answer is 48
    final containsExpected = RegExp(r'\b48\b').hasMatch(finalAnswerSnippet);

    if (containsExpected) {
      return EvaluationResult(
        status: 'pass',
        scorePercent: 100.0,
        details: 'Correct answer 48 identified in: "$finalAnswerSnippet"',
      );
    } else {
      return EvaluationResult(
        status: 'fail',
        scorePercent: 0.0,
        details: 'Incorrect answer. Expected 48, extracted: "$finalAnswerSnippet"',
      );
    }
  }

  static Future<EvaluationResult> _evaluatePythonCoding(String text) async {
    // Extract code block
    var code = '';
    final codeBlockMatch = RegExp(r'```(?:python)?\s*([\s\S]*?)```', caseSensitive: false).firstMatch(text);
    if (codeBlockMatch != null) {
      code = codeBlockMatch.group(1) ?? '';
    } else {
      // Fallback: extract everything from 'def flatten_and_unique'
      final defIdx = text.indexOf('def flatten_and_unique');
      if (defIdx != -1) {
        code = text.substring(defIdx);
      }
    }

    if (code.trim().isEmpty) {
      return EvaluationResult(
        status: 'fail',
        scorePercent: 0.0,
        details: 'No Python code block or flatten_and_unique function found in response.',
      );
    }

    // Test runner harness
    final testHarness = '''
import sys

$code

tests = [
    (flatten_and_unique([]), []),
    (flatten_and_unique([1, 2, 3]), [1, 2, 3]),
    (flatten_and_unique([3, 2, 1, 2, 3]), [1, 2, 3]),
    (flatten_and_unique([1, [2, [3, 2]], [1, [4, 5]]]), [1, 2, 3, 4, 5]),
    (flatten_and_unique([[[[10]]], [5, [2, [5, 10]]], 1]), [1, 2, 5, 10]),
]

passed = 0
for idx, (res, exp) in enumerate(tests):
    if res == exp:
        passed += 1

print(f"PASSED:{passed}/{len(tests)}")
''';

    final tempDir = await Directory.systemTemp.createTemp('bench_py_');
    final tempScript = File('${tempDir.path}${Platform.pathSeparator}test_runner.py');
    await tempScript.writeAsString(testHarness);

    try {
      final res = await Process.run(
        'python',
        [tempScript.path],
        runInShell: false,
      ).timeout(const Duration(seconds: 8));

      final output = res.stdout.toString().trim();
      final err = res.stderr.toString().trim();

      final match = RegExp(r'PASSED:(\d+)/(\d+)').firstMatch(output);
      if (match != null) {
        final p = int.parse(match.group(1)!);
        final t = int.parse(match.group(2)!);
        final score = (p / t) * 100.0;
        return EvaluationResult(
          status: p == t ? 'pass' : 'fail',
          scorePercent: score,
          details: 'Python unit test runner: $p/$t unit tests passed. ${p < t ? err : ''}'.trim(),
        );
      } else {
        return EvaluationResult(
          status: 'fail',
          scorePercent: 0.0,
          details: 'Execution failed: ${err.isNotEmpty ? err : output}',
        );
      }
    } catch (e) {
      return EvaluationResult(
        status: 'error',
        scorePercent: 0.0,
        details: 'Test execution exception: $e',
      );
    } finally {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  static EvaluationResult _evaluateInstructionFollowing(String text) {
    final rules = <String, bool>{};

    // Clean text: strip code blocks or Markdown headers if any
    var clean = text.replaceAll(RegExp(r'```[\s\S]*?```'), '').trim();

    // Sentence tokenizer: split on sentence terminators (. ! ?)
    final rawSentences = clean
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(s))
        .toList();

    // Rule 1: Exactly four sentences
    rules['Rule 1: Exactly 4 sentences'] = rawSentences.length == 4;

    // Rule 2: First sentence begins with 'Deep'
    if (rawSentences.isNotEmpty) {
      rules["Rule 2: Sentence 1 begins with 'Deep'"] =
          rawSentences[0].toLowerCase().startsWith('deep');
    } else {
      rules["Rule 2: Sentence 1 begins with 'Deep'"] = false;
    }

    // Rule 3: Third sentence ends with 'stars'
    if (rawSentences.length >= 3) {
      final s3Clean = rawSentences[2].replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
      rules["Rule 3: Sentence 3 ends with 'stars'"] = s3Clean.endsWith('stars');
    } else {
      rules["Rule 3: Sentence 3 ends with 'stars'"] = false;
    }

    // Rule 4: Zero occurrences of 'e' or 'E' in second sentence
    if (rawSentences.length >= 2) {
      rules["Rule 4: Sentence 2 contains no letter 'e'"] =
          !rawSentences[1].toLowerCase().contains('e');
    } else {
      rules["Rule 4: Sentence 2 contains no letter 'e'"] = false;
    }

    // Rule 5: Word count across paragraph between 40 and 60 words
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    rules['Rule 5: Word count between 40-60 (Actual: $words)'] = words >= 40 && words <= 60;

    final passedCount = rules.values.where((v) => v).length;
    final totalRules = rules.length;
    final score = (passedCount / totalRules) * 100.0;

    final breakdown = rules.entries
        .map((e) => '${e.key}: ${e.value ? "PASSED" : "FAILED"}')
        .join('; ');

    return EvaluationResult(
      status: passedCount == totalRules ? 'pass' : 'fail',
      scorePercent: score,
      details: 'Score: $passedCount/$totalRules rules satisfied ($breakdown)',
    );
  }
}
