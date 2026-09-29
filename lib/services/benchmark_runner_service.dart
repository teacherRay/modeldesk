// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/benchmark_models.dart';
import '../models/gguf_model.dart';
import '../models/chat_message.dart';
import '../controllers/server_controller.dart';
import 'llama_client.dart';
import 'hardware_monitor_service.dart';
import 'model_hash_service.dart';
import 'benchmark_evaluator.dart';
import 'benchmark_export_service.dart';

class BenchmarkProgressEvent {
  final String currentModelName;
  final int currentModelIndex;
  final int totalModels;
  final String currentTestTitle;
  final int currentTestIndex;
  final int totalTests;
  final int completedOverall;
  final int totalOverall;
  final Duration elapsedTime;
  final String statusMessage;
  final bool isFinished;
  final bool isCancelled;
  final String? error;
  final BenchmarkSuiteResult? result;
  final String? exportDirectory;

  BenchmarkProgressEvent({
    required this.currentModelName,
    required this.currentModelIndex,
    required this.totalModels,
    required this.currentTestTitle,
    required this.currentTestIndex,
    required this.totalTests,
    required this.completedOverall,
    required this.totalOverall,
    required this.elapsedTime,
    required this.statusMessage,
    this.isFinished = false,
    this.isCancelled = false,
    this.error,
    this.result,
    this.exportDirectory,
  });
}

class BenchmarkRunnerService {
  final ServerController _serverController;
  final LlamaClient _llamaClient;
  final HardwareMonitorService _hardwareMonitor;
  final ModelHashService _hashService;
  final String _baseStorageDir;

  bool _isRunning = false;
  bool _isCancelled = false;
  final _progressController =
      StreamController<BenchmarkProgressEvent>.broadcast();

  Stream<BenchmarkProgressEvent> get progressStream =>
      _progressController.stream;
  bool get isRunning => _isRunning;

  BenchmarkRunnerService({
    required ServerController serverController,
    required LlamaClient llamaClient,
    required HardwareMonitorService hardwareMonitor,
    ModelHashService? hashService,
    String? baseStorageDir,
  })  : _serverController = serverController,
        _llamaClient = llamaClient,
        _hardwareMonitor = hardwareMonitor,
        _hashService = hashService ?? ModelHashService(),
        _baseStorageDir = baseStorageDir ?? _defaultStorageDir();

  static String _defaultStorageDir() {
    final userProfile = Platform.environment['USERPROFILE'] ?? '.';
    return p.join(userProfile, r'AppData\Roaming\LlamaLauncher\benchmarks');
  }

  void cancelBenchmark() {
    if (_isRunning) {
      _isCancelled = true;
      _llamaClient.cancel();
    }
  }

  Future<void> runBenchmark(List<GgufModelInfo> selectedModels) async {
    if (_isRunning || selectedModels.isEmpty) return;

    _isRunning = true;
    _isCancelled = false;

    final overallStopwatch = Stopwatch()..start();
    final originalConfig = _serverController.config;
    final wasRunningInitially = _serverController.isRunning;

    final timestampStr = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final runDir = p.join(_baseStorageDir, 'MD-Bench_1.0_$timestampStr');

    final individualRuns = <BenchmarkTestRecord>[];
    final summaries = <BenchmarkModelSummary>[];

    final totalModels = selectedModels.length;
    const testsPerModel = 4;
    final totalOverall = totalModels * testsPerModel;
    int completedOverall = 0;

    Timer? elapsedTimer;
    elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRunning && !_progressController.isClosed) {
        _progressController.add(BenchmarkProgressEvent(
          currentModelName: '',
          currentModelIndex: 0,
          totalModels: totalModels,
          currentTestTitle: '',
          currentTestIndex: 0,
          totalTests: testsPerModel,
          completedOverall: completedOverall,
          totalOverall: totalOverall,
          elapsedTime: overallStopwatch.elapsed,
          statusMessage: 'Benchmarking in progress...',
        ));
      }
    });

    try {
      // 1. Gather System Hardware Information
      final sysSample = _hardwareMonitor.sample();
      final systemInfo = <String, dynamic>{
        'Operating System': Platform.operatingSystemVersion,
        'Logical CPU Cores': Platform.numberOfProcessors.toString(),
        'System RAM Total':
            '${(sysSample.ram.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
        'Discrete GPU': _hardwareMonitor.gpuName,
        'Dedicated VRAM Total':
            '${(_hardwareMonitor.dedicatedVramTotalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
        'llama Executable': originalConfig.llamaBin,
        'Benchmark Suite': MdBenchConstants.suiteVersion,
      };

      // 2. Sequential Unattended Execution Across Models
      for (int mIdx = 0; mIdx < totalModels; mIdx++) {
        if (_isCancelled) break;

        final model = selectedModels[mIdx];
        final modelIndex = mIdx + 1;

        _emitProgress(
          modelName: model.name,
          modelIndex: modelIndex,
          totalModels: totalModels,
          testTitle: 'Preparing server & calculating SHA-256',
          testIndex: 0,
          completedOverall: completedOverall,
          totalOverall: totalOverall,
          elapsed: overallStopwatch.elapsed,
          status: 'Hashing model weights & starting server...',
        );

        // Get or compute cached SHA-256
        final modelHash = await _hashService.getOrComputeSha256(model.path);

        if (_isCancelled) break;

        // Cleanly stop any existing server process before starting target model
        if (_serverController.isRunning || _serverController.isStarting) {
          await _serverController.stopServer();
          await Future.delayed(const Duration(milliseconds: 600));
        }

        // Configure server with fixed MD-Bench 1.0 parameters
        final benchConfig = _serverController.config.copyWith(
          modelPath: model.path,
          mmprojPath: '',
          ctxSize: MdBenchConstants.benchmarkCtxSize,
          nGpuLayers: MdBenchConstants.benchmarkGpuLayers,
          threads: MdBenchConstants.benchmarkThreads,
          flashAttn: MdBenchConstants.benchmarkFlashAttn,
          extraArgs: '',
        );

        _serverController.updateConfig(benchConfig);
        _serverController.clearLogs();

        final started = await _serverController.startServer();
        if (!started) {
          _recordModelLaunchFailure(
            model: model,
            sha256: modelHash,
            reason: 'Failed to launch llama-server process.',
            individualRuns: individualRuns,
            summaries: summaries,
          );
          completedOverall += testsPerModel;
          continue;
        }

        // Wait until genuinely healthy and ready (up to 60s)
        final isReady = await _waitForServerReady(
          baseUrl: benchConfig.baseUrl,
          timeoutSeconds: 60,
        );

        if (!isReady) {
          _recordModelLaunchFailure(
            model: model,
            sha256: modelHash,
            reason: 'Server failed to reach healthy state within 60 seconds.',
            individualRuns: individualRuns,
            summaries: summaries,
          );
          await _serverController.stopServer();
          completedOverall += testsPerModel;
          continue;
        }

        // Scrape actual offloaded GPU layers from -lv 4 log output
        final actualLayersOffloaded = _extractActualGpuLayers();

        // 3. Execute the 4 Standard Tests Sequentially
        final tests = [
          _BenchmarkTestDef(
            id: MdBenchConstants.testGeneralProseId,
            title: MdBenchConstants.testGeneralProseTitle,
            prompt: MdBenchConstants.testGeneralProsePrompt,
          ),
          _BenchmarkTestDef(
            id: MdBenchConstants.testLogicReasoningId,
            title: MdBenchConstants.testLogicReasoningTitle,
            prompt: MdBenchConstants.testLogicReasoningPrompt,
          ),
          _BenchmarkTestDef(
            id: MdBenchConstants.testPythonCodingId,
            title: MdBenchConstants.testPythonCodingTitle,
            prompt: MdBenchConstants.testPythonCodingPrompt,
          ),
          _BenchmarkTestDef(
            id: MdBenchConstants.testInstructionFollowingId,
            title: MdBenchConstants.testInstructionFollowingTitle,
            prompt: MdBenchConstants.testInstructionFollowingPrompt,
          ),
        ];

        final modelRunRecords = <BenchmarkTestRecord>[];

        for (int tIdx = 0; tIdx < tests.length; tIdx++) {
          if (_isCancelled) break;

          final testDef = tests[tIdx];
          final testIndex = tIdx + 1;

          _emitProgress(
            modelName: model.name,
            modelIndex: modelIndex,
            totalModels: totalModels,
            testTitle: testDef.title,
            testIndex: testIndex,
            completedOverall: completedOverall,
            totalOverall: totalOverall,
            elapsed: overallStopwatch.elapsed,
            status: 'Executing ${testDef.title}...',
          );

          // Execute single test run
          final runRecord = await _executeTestRun(
            model: model,
            modelSha256: modelHash,
            testDef: testDef,
            baseUrl: benchConfig.baseUrl,
            actualOffload: actualLayersOffloaded,
          );

          modelRunRecords.add(runRecord);
          individualRuns.add(runRecord);
          completedOverall++;
        }

        // Stop server after completing tests for this model
        await _serverController.stopServer();
        await Future.delayed(const Duration(milliseconds: 600));

        // Create Model Summary
        if (modelRunRecords.isNotEmpty) {
          summaries.add(_computeModelSummary(
            model: model,
            sha256: modelHash,
            runs: modelRunRecords,
          ));
        }
      }

      // 4. Compile Final Suite Results & Export
      final suiteResult = BenchmarkSuiteResult(
        suiteVersion: MdBenchConstants.suiteVersion,
        runTimestamp: DateTime.now(),
        systemInfo: systemInfo,
        summaries: summaries,
        individualRuns: individualRuns,
      );

      if (!_isCancelled && individualRuns.isNotEmpty) {
        await BenchmarkExportService.exportAll(
          result: suiteResult,
          outputDir: runDir,
        );
      }

      _progressController.add(BenchmarkProgressEvent(
        currentModelName: '',
        currentModelIndex: totalModels,
        totalModels: totalModels,
        currentTestTitle: 'Completed',
        currentTestIndex: testsPerModel,
        totalTests: testsPerModel,
        completedOverall: completedOverall,
        totalOverall: totalOverall,
        elapsedTime: overallStopwatch.elapsed,
        statusMessage: _isCancelled
            ? 'Benchmark cancelled by user.'
            : 'Benchmark completed successfully!',
        isFinished: true,
        isCancelled: _isCancelled,
        result: suiteResult,
        exportDirectory: runDir,
      ));
    } catch (e, stack) {
      debugPrint('[BenchmarkRunnerService] Fatal benchmark error: $e\n$stack');
      _progressController.add(BenchmarkProgressEvent(
        currentModelName: '',
        currentModelIndex: 0,
        totalModels: totalModels,
        currentTestTitle: 'Error',
        currentTestIndex: 0,
        totalTests: testsPerModel,
        completedOverall: completedOverall,
        totalOverall: totalOverall,
        elapsedTime: overallStopwatch.elapsed,
        statusMessage: 'Error during benchmark: $e',
        isFinished: true,
        error: e.toString(),
      ));
    } finally {
      elapsedTimer.cancel();
      _isRunning = false;

      // 5. GUARANTEED RESTORATION: Restore user's original server configuration
      debugPrint('[BenchmarkRunnerService] Restoring user original server configuration...');
      try {
        if (_serverController.isRunning || _serverController.isStarting) {
          await _serverController.stopServer();
        }
        _serverController.updateConfig(originalConfig);

        // Restart original server if it was running before benchmark started
        if (wasRunningInitially) {
          debugPrint('[BenchmarkRunnerService] Restarting user original model server...');
          await _serverController.startServer();
        }
      } catch (restoreErr) {
        debugPrint('[BenchmarkRunnerService] Error restoring server configuration: $restoreErr');
      }
    }
  }

  Future<bool> _waitForServerReady({
    required String baseUrl,
    required int timeoutSeconds,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      if (_isCancelled) return false;
      try {
        final healthy = await _llamaClient.checkHealth(baseUrl);
        if (healthy) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  String _extractActualGpuLayers() {
    for (final line in _serverController.consoleLogs.reversed) {
      final offloadMatch = RegExp(r'offloaded\s+(\d+\/\d+)\s+layers to GPU', caseSensitive: false)
          .firstMatch(line);
      if (offloadMatch != null) {
        return offloadMatch.group(1)!;
      }
      final repeatingMatch = RegExp(r'offloading\s+(\d+)\s+repeating layers to GPU', caseSensitive: false)
          .firstMatch(line);
      if (repeatingMatch != null) {
        return '${repeatingMatch.group(1)} layers';
      }
    }
    return 'All Available';
  }

  Future<BenchmarkTestRecord> _executeTestRun({
    required GgufModelInfo model,
    required String modelSha256,
    required _BenchmarkTestDef testDef,
    required String baseUrl,
    required String actualOffload,
  }) async {
    final testStopwatch = Stopwatch()..start();
    double peakVram = 0.0;
    double peakRam = 0.0;

    // Track peak memory while query runs
    final pid = _serverController.serverPid;
    final memSampler = Timer.periodic(const Duration(milliseconds: 300), (_) {
      try {
        final sample = _hardwareMonitor.sample(llamaPid: pid);
        final vramMb = sample.gpu.dedicatedVramUsedBytes / (1024 * 1024);
        final ramMb = sample.ram.usedBytes / (1024 * 1024);
        if (vramMb > peakVram) peakVram = vramMb;
        if (ramMb > peakRam) peakRam = ramMb;
      } catch (_) {}
    });

    var responseText = '';
    double promptTps = 0.0;
    double genTps = 0.0;
    int promptTokens = 0;
    int genTokens = 0;
    double promptEvalTimeMs = 0.0;
    double ttftMs = 0.0;

    try {
      // Send the single benchmark prompt
      final streamSubscription = _llamaClient.streamChatCompletion(
        baseUrl: baseUrl,
        conversationHistory: [
          ChatMessage(
            id: 'bench-${testDef.id}',
            role: 'user',
            content: testDef.prompt,
          ),
        ],
        temperature: MdBenchConstants.benchmarkTemperature,
      );

      await for (final chunk in streamSubscription) {
        if (_isCancelled) break;
        if (chunk.deltaText.isNotEmpty) {
          responseText += chunk.deltaText;
        }
        if (chunk.isDone) {
          if (chunk.tokensPerSec != null) genTps = chunk.tokensPerSec!;
          if (chunk.totalTokens != null) genTokens = chunk.totalTokens!;
          if (chunk.promptTokens != null) promptTokens = chunk.promptTokens!;
          if (chunk.promptPerSec != null) promptTps = chunk.promptPerSec!;
          if (chunk.promptEvalTimeMs != null) {
            promptEvalTimeMs = chunk.promptEvalTimeMs!;
          }
          if (chunk.timeToFirstTokenMs != null) {
            ttftMs = chunk.timeToFirstTokenMs!;
          }
        }
      }
    } catch (e) {
      responseText = '[Execution Exception]: $e';
    } finally {
      memSampler.cancel();
      testStopwatch.stop();
    }

    // Evaluate response
    final evalResult = await BenchmarkEvaluator.evaluate(
      testId: testDef.id,
      responseText: responseText,
    );

    return BenchmarkTestRecord(
      testId: testDef.id,
      testTitle: testDef.title,
      modelDisplayName: model.displayName,
      ggufFileName: model.name,
      ggufFilePath: model.path,
      ggufSha256: modelSha256,
      architectureFamily: model.architectureFamily,
      quantization: model.quantization,
      fileSizeBytes: model.sizeBytes,
      contextSetting: MdBenchConstants.benchmarkCtxSize,
      requestedGpuLayers: MdBenchConstants.benchmarkGpuLayers,
      actualGpuLayersOffloaded: actualOffload,
      promptTokens: promptTokens,
      generatedTokens: genTokens,
      promptEvalSpeedTps: promptTps,
      generationSpeedTps: genTps,
      promptEvalTimeMs: promptEvalTimeMs,
      timeToFirstTokenMs: ttftMs,
      totalElapsedMs: testStopwatch.elapsedMilliseconds,
      peakVramMb: peakVram,
      peakRamMb: peakRam,
      completeResponse: responseText,
      status: evalResult.status,
      scorePercent: evalResult.scorePercent,
      scoreDetails: evalResult.details,
      timestamp: DateTime.now(),
    );
  }

  BenchmarkModelSummary _computeModelSummary({
    required GgufModelInfo model,
    required String sha256,
    required List<BenchmarkTestRecord> runs,
  }) {
    double totalPromptTps = 0.0;
    double totalGenTps = 0.0;
    double maxVram = 0.0;
    double maxRam = 0.0;
    double logicScore = 0.0;
    double codingScore = 0.0;
    double instructionScore = 0.0;
    int passed = 0;

    for (final r in runs) {
      totalPromptTps += r.promptEvalSpeedTps;
      totalGenTps += r.generationSpeedTps;
      if (r.peakVramMb > maxVram) maxVram = r.peakVramMb;
      if (r.peakRamMb > maxRam) maxRam = r.peakRamMb;

      if (r.testId == MdBenchConstants.testLogicReasoningId) {
        logicScore = r.scorePercent;
      } else if (r.testId == MdBenchConstants.testPythonCodingId) {
        codingScore = r.scorePercent;
      } else if (r.testId == MdBenchConstants.testInstructionFollowingId) {
        instructionScore = r.scorePercent;
      }

      if (r.status == 'pass' || r.status == 'completed') {
        passed++;
      }
    }

    final count = runs.isNotEmpty ? runs.length : 1;
    final avgPrompt = totalPromptTps / count;
    final avgGen = totalGenTps / count;

    // Overall objective score is average of the 3 objective tests (Logic, Coding, Instruction)
    final overallObjectiveScore = (logicScore + codingScore + instructionScore) / 3.0;

    return BenchmarkModelSummary(
      modelDisplayName: model.displayName,
      ggufFileName: model.name,
      ggufFilePath: model.path,
      ggufSha256: sha256,
      architectureFamily: model.architectureFamily,
      quantization: model.quantization,
      fileSizeBytes: model.sizeBytes,
      avgPromptTps: avgPrompt,
      avgGenTps: avgGen,
      maxPeakVramMb: maxVram,
      maxPeakRamMb: maxRam,
      logicScore: logicScore,
      codingScore: codingScore,
      instructionScore: instructionScore,
      overallScore: overallObjectiveScore,
      passedTests: passed,
      totalTests: runs.length,
      status: passed == runs.length ? 'passed' : (passed > 0 ? 'partial' : 'failed'),
    );
  }

  void _recordModelLaunchFailure({
    required GgufModelInfo model,
    required String sha256,
    required String reason,
    required List<BenchmarkTestRecord> individualRuns,
    required List<BenchmarkModelSummary> summaries,
  }) {
    final tests = [
      _BenchmarkTestDef(
        id: MdBenchConstants.testGeneralProseId,
        title: MdBenchConstants.testGeneralProseTitle,
        prompt: MdBenchConstants.testGeneralProsePrompt,
      ),
      _BenchmarkTestDef(
        id: MdBenchConstants.testLogicReasoningId,
        title: MdBenchConstants.testLogicReasoningTitle,
        prompt: MdBenchConstants.testLogicReasoningPrompt,
      ),
      _BenchmarkTestDef(
        id: MdBenchConstants.testPythonCodingId,
        title: MdBenchConstants.testPythonCodingTitle,
        prompt: MdBenchConstants.testPythonCodingPrompt,
      ),
      _BenchmarkTestDef(
        id: MdBenchConstants.testInstructionFollowingId,
        title: MdBenchConstants.testInstructionFollowingTitle,
        prompt: MdBenchConstants.testInstructionFollowingPrompt,
      ),
    ];

    for (final t in tests) {
      individualRuns.add(BenchmarkTestRecord(
        testId: t.id,
        testTitle: t.title,
        modelDisplayName: model.displayName,
        ggufFileName: model.name,
        ggufFilePath: model.path,
        ggufSha256: sha256,
        architectureFamily: model.architectureFamily,
        quantization: model.quantization,
        fileSizeBytes: model.sizeBytes,
        contextSetting: MdBenchConstants.benchmarkCtxSize,
        requestedGpuLayers: MdBenchConstants.benchmarkGpuLayers,
        actualGpuLayersOffloaded: '0/0 (Launch Failed)',
        promptTokens: 0,
        generatedTokens: 0,
        promptEvalSpeedTps: 0.0,
        generationSpeedTps: 0.0,
        promptEvalTimeMs: 0.0,
        timeToFirstTokenMs: 0.0,
        totalElapsedMs: 0,
        peakVramMb: 0.0,
        peakRamMb: 0.0,
        completeResponse: '[Launch Error]: $reason',
        status: 'error',
        scorePercent: 0.0,
        scoreDetails: reason,
        timestamp: DateTime.now(),
      ));
    }

    summaries.add(BenchmarkModelSummary(
      modelDisplayName: model.displayName,
      ggufFileName: model.name,
      ggufFilePath: model.path,
      ggufSha256: sha256,
      architectureFamily: model.architectureFamily,
      quantization: model.quantization,
      fileSizeBytes: model.sizeBytes,
      avgPromptTps: 0.0,
      avgGenTps: 0.0,
      maxPeakVramMb: 0.0,
      maxPeakRamMb: 0.0,
      logicScore: 0.0,
      codingScore: 0.0,
      instructionScore: 0.0,
      overallScore: 0.0,
      passedTests: 0,
      totalTests: tests.length,
      status: 'failed',
    ));
  }

  void _emitProgress({
    required String modelName,
    required int modelIndex,
    required int totalModels,
    required String testTitle,
    required int testIndex,
    required int completedOverall,
    required int totalOverall,
    required Duration elapsed,
    required String status,
  }) {
    if (!_progressController.isClosed) {
      _progressController.add(BenchmarkProgressEvent(
        currentModelName: modelName,
        currentModelIndex: modelIndex,
        totalModels: totalModels,
        currentTestTitle: testTitle,
        currentTestIndex: testIndex,
        totalTests: 4,
        completedOverall: completedOverall,
        totalOverall: totalOverall,
        elapsedTime: elapsed,
        statusMessage: status,
      ));
    }
  }

  void dispose() {
    _progressController.close();
  }
}

class _BenchmarkTestDef {
  final String id;
  final String title;
  final String prompt;

  _BenchmarkTestDef({
    required this.id,
    required this.title,
    required this.prompt,
  });
}
