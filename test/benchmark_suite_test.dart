import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_launcher_flutter/models/benchmark_models.dart';
import 'package:llama_launcher_flutter/services/benchmark_evaluator.dart';
import 'package:llama_launcher_flutter/services/model_hash_service.dart';
import 'package:llama_launcher_flutter/services/benchmark_export_service.dart';

void main() {
  group('MD-Bench 1.0 Suite Constants & Specification', () {
    test('MD-Bench 1.0 constants are immutable and defined', () {
      expect(MdBenchConstants.suiteVersion, equals('MD-Bench 1.0'));
      expect(MdBenchConstants.benchmarkCtxSize, equals('4096'));
      expect(MdBenchConstants.benchmarkGpuLayers, equals(99));
      expect(MdBenchConstants.benchmarkTemperature, equals(0.0));

      // Test 1: Titanic maiden-voyage prose
      expect(MdBenchConstants.testGeneralProseId, equals('general_prose'));
      expect(MdBenchConstants.testGeneralProsePrompt,
          contains('Describe the maiden voyage of the Titanic in 1000 words.'));

      // Test 2: Multi-step scheduling logic
      expect(MdBenchConstants.testLogicReasoningId, equals('logic_reasoning'));
      expect(MdBenchConstants.testLogicReasoningPrompt,
          contains('FINAL ANSWER: <integer>'));

      // Test 3: Python coding
      expect(MdBenchConstants.testPythonCodingId, equals('python_coding'));
      expect(MdBenchConstants.testPythonCodingPrompt,
          contains('flatten_and_unique'));

      // Test 4: Strict instruction following
      expect(MdBenchConstants.testInstructionFollowingId,
          equals('instruction_following'));
      expect(MdBenchConstants.testInstructionFollowingPrompt,
          contains('exactly four sentences'));
    });
  });

  group('ModelHashService SHA-256 & Caching', () {
    late Directory tempDir;
    late File testFile;
    late ModelHashService hashService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bench_hash_test_');
      testFile = File('${tempDir.path}${Platform.pathSeparator}test_model.gguf');
      await testFile.writeAsString('DUMMY_GGUF_MODEL_DATA_FOR_TESTING_PURPOSES');
      hashService = ModelHashService(customCacheDir: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Computes SHA-256 and caches result by path + size + timestamp', () async {
      final hash1 = await hashService.getOrComputeSha256(testFile.path);
      expect(hash1, isNotEmpty);
      expect(hash1, isNot(equals('FILE_NOT_FOUND')));
      expect(hash1, isNot(equals('HASH_ERROR')));

      // Second retrieval must hit the cache
      final hash2 = await hashService.getOrComputeSha256(testFile.path);
      expect(hash2, equals(hash1));

      // Check cache file on disk
      final cacheFile = File('${tempDir.path}${Platform.pathSeparator}hash_cache.json');
      expect(await cacheFile.exists(), isTrue);

      final cacheContent = await cacheFile.readAsString();
      expect(cacheContent, contains(hash1));
    });
  });

  group('BenchmarkEvaluator Deterministic Grading', () {
    test('General Prose: preserves response without artificial scoring', () async {
      const mockTitanic =
          'The RMS Titanic departed Southampton on April 10, 1912, on its maiden voyage across the Atlantic Ocean. '
          'Carrying over 2,200 passengers and crew, the ocean liner was hailed as a marvel of Edwardian engineering.';

      final res = await BenchmarkEvaluator.evaluate(
        testId: MdBenchConstants.testGeneralProseId,
        responseText: mockTitanic,
      );

      expect(res.status, equals('completed'));
      expect(res.scorePercent, equals(100.0));
      expect(res.details, contains('Preserved for human review'));
    });

    test('Logic Puzzle: passes when correct answer 48 is given', () async {
      const mockCorrectLogic = '''
Step 1: Constraint 1 requires Chen to be immediately before Davis.
Step 2: Bowen cannot take Shift 1 or 4, so Bowen must take Shift 2 or Shift 3.
Step 3: Aris is earlier than Bowen. If Bowen was Shift 3, Chen and Davis would be Shift 1 and 2, putting Aris at Shift 4 (contradicting Aris earlier than Bowen).
Therefore Bowen must be Shift 2, Aris is Shift 1, Chen is Shift 3, and Davis is Shift 4.
Step 4: Shift 2 lasts 6 hours and collects 8 samples per hour.
Total = 6 * 8 = 48.

FINAL ANSWER: 48
''';

      final res = await BenchmarkEvaluator.evaluate(
        testId: MdBenchConstants.testLogicReasoningId,
        responseText: mockCorrectLogic,
      );

      expect(res.status, equals('pass'));
      expect(res.scorePercent, equals(100.0));
      expect(res.details, contains('Correct answer 48'));
    });

    test('Logic Puzzle: fails when incorrect answer is given', () async {
      const mockWrongLogic = '''
Deduction leads to Shift 3 with 5 hours at 15 samples = 75.
FINAL ANSWER: 75
''';

      final res = await BenchmarkEvaluator.evaluate(
        testId: MdBenchConstants.testLogicReasoningId,
        responseText: mockWrongLogic,
      );

      expect(res.status, equals('fail'));
      expect(res.scorePercent, equals(0.0));
      expect(res.details, contains('Expected 48'));
    });

    test('Python Coding: executes test harness and scores passed vectors', () async {
      const mockCorrectPython = '''
Here is the implementation:
```python
def flatten_and_unique(nested_list):
    result = []
    def _helper(item):
        if isinstance(item, list):
            for sub in item:
                _helper(sub)
        else:
            result.append(item)
    _helper(nested_list)
    return sorted(list(set(result)))
```
''';

      final res = await BenchmarkEvaluator.evaluate(
        testId: MdBenchConstants.testPythonCodingId,
        responseText: mockCorrectPython,
      );

      expect(res.status, equals('pass'));
      expect(res.scorePercent, equals(100.0));
      expect(res.details, contains('5/5 unit tests passed'));
    });

    test('Instruction Following: grades all 5 deterministic rules', () {
      // 1. Exactly 4 sentences
      // 2. Starts with "Deep"
      // 3. 3rd ends with "stars"
      // 4. 2nd has no 'e'
      // 5. Total word count between 40 and 60
      const validParagraph =
          "Deep cosmic probes journey far beyond our solar system to explore cold uncharted domains. "
          "A small robot spins in total dark void to look around. "
          "Ancient voyagers navigated oceans by tracking bright distant stars. "
          "Future human pioneers will eventually build permanent settlements across new worlds.";

      final res = BenchmarkEvaluator.evaluate(
        testId: MdBenchConstants.testInstructionFollowingId,
        responseText: validParagraph,
      );

      return res.then((eval) {
        expect(eval.status, equals('pass'));
        expect(eval.scorePercent, equals(100.0));
        expect(eval.details, contains('5/5 rules satisfied'));
      });
    });

    test('Instruction Following: detects rule violation', () {
      const invalidParagraph =
          "Hello world! This is too short and fails rules.";

      final res = BenchmarkEvaluator.evaluate(
        testId: MdBenchConstants.testInstructionFollowingId,
        responseText: invalidParagraph,
      );

      return res.then((eval) {
        expect(eval.status, equals('fail'));
        expect(eval.scorePercent, lessThan(100.0));
      });
    });
  });

  group('BenchmarkExportService Multi-Sheet Excel, CSV & JSON', () {
    late Directory exportTempDir;

    setUp(() async {
      exportTempDir = await Directory.systemTemp.createTemp('bench_export_test_');
    });

    tearDown(() async {
      if (await exportTempDir.exists()) {
        await exportTempDir.delete(recursive: true);
      }
    });

    test('Generates complete 4-sheet .xlsx workbook with charts, .csv and .json', () async {
      final dummySummary = BenchmarkModelSummary(
        modelDisplayName: 'Gemma 4B Test [4.2 GB]',
        ggufFileName: 'gemma-4b.gguf',
        ggufFilePath: 'C:\\models\\gemma-4b.gguf',
        ggufSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        architectureFamily: 'Gemma',
        quantization: 'Q4_K_M',
        fileSizeBytes: 4200000000,
        avgPromptTps: 110.5,
        avgGenTps: 34.2,
        maxPeakVramMb: 4500.0,
        maxPeakRamMb: 8200.0,
        logicScore: 100.0,
        codingScore: 100.0,
        instructionScore: 80.0,
        overallScore: 93.3,
        passedTests: 4,
        totalTests: 4,
        status: 'passed',
      );

      final dummyRecord = BenchmarkTestRecord(
        testId: 'logic_reasoning',
        testTitle: 'Deterministic Logic & Reasoning',
        modelDisplayName: 'Gemma 4B Test [4.2 GB]',
        ggufFileName: 'gemma-4b.gguf',
        ggufFilePath: 'C:\\models\\gemma-4b.gguf',
        ggufSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        architectureFamily: 'Gemma',
        quantization: 'Q4_K_M',
        fileSizeBytes: 4200000000,
        contextSetting: '4096',
        requestedGpuLayers: 99,
        actualGpuLayersOffloaded: '49/49',
        promptTokens: 250,
        generatedTokens: 80,
        promptEvalSpeedTps: 112.0,
        generationSpeedTps: 35.1,
        promptEvalTimeMs: 220.0,
        timeToFirstTokenMs: 235.0,
        totalElapsedMs: 2500,
        peakVramMb: 4500.0,
        peakRamMb: 8200.0,
        completeResponse: 'FINAL ANSWER: 48',
        status: 'pass',
        scorePercent: 100.0,
        scoreDetails: 'Correct answer 48 identified.',
        timestamp: DateTime.now(),
      );

      final suiteResult = BenchmarkSuiteResult(
        suiteVersion: 'MD-Bench 1.0',
        runTimestamp: DateTime.now(),
        systemInfo: {
          'Operating System': 'Windows 11',
          'Discrete GPU': 'AMD Radeon RX 9060 XT',
          'Dedicated VRAM Total': '16.0 GB',
        },
        summaries: [dummySummary],
        individualRuns: [dummyRecord],
      );

      await BenchmarkExportService.exportAll(
        result: suiteResult,
        outputDir: exportTempDir.path,
      );

      final excelFile = File('${exportTempDir.path}${Platform.pathSeparator}benchmark_results.xlsx');
      final csvFile = File('${exportTempDir.path}${Platform.pathSeparator}benchmark_results.csv');
      final jsonFile = File('${exportTempDir.path}${Platform.pathSeparator}benchmark_results.json');

      expect(await excelFile.exists(), isTrue);
      expect(await csvFile.exists(), isTrue);
      expect(await jsonFile.exists(), isTrue);

      final excelBytes = await excelFile.readAsBytes();
      expect(excelBytes.length, greaterThan(5000));

      final csvContent = await csvFile.readAsString();
      expect(csvContent, contains('MD-Bench 1.0'));
      expect(csvContent, contains('gemma-4b.gguf'));
      expect(csvContent, contains('FINAL ANSWER: 48'));

      final jsonContent = await jsonFile.readAsString();
      expect(jsonContent, contains('MD-Bench 1.0'));
      expect(jsonContent, contains('AMD Radeon RX 9060 XT'));
    });
  });
}
