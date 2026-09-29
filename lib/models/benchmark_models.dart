class MdBenchConstants {
  static const String suiteVersion = 'MD-Bench 1.0';

  // Benchmark Server Parameters
  static const String benchmarkCtxSize = '4096';
  static const int benchmarkGpuLayers = 99;
  static const int benchmarkThreads = 6;
  static const String benchmarkFlashAttn = 'on';
  static const double benchmarkTemperature = 0.0; // Greedy decoding for reproducibility

  // Test 1: General Knowledge / Prose
  static const String testGeneralProseId = 'general_prose';
  static const String testGeneralProseTitle = 'General Knowledge & Prose';
  static const String testGeneralProsePrompt =
      'Describe the maiden voyage of the Titanic in 1000 words.';

  // Test 2: Deterministic Logic & Reasoning
  static const String testLogicReasoningId = 'logic_reasoning';
  static const String testLogicReasoningTitle = 'Deterministic Logic & Reasoning';
  static const String testLogicReasoningPrompt = '''
Solve the following scheduling and allocation puzzle step by step:

A research station has four scientists: Dr. Aris, Dr. Bowen, Dr. Chen, and Dr. Davis.
They must each be assigned to exactly one of four distinct observation shifts numbered Shift 1, Shift 2, Shift 3, and Shift 4 (in chronological order).

The following constraints must all be satisfied:
1. Dr. Chen's shift is immediately before Dr. Davis's shift.
2. Dr. Bowen does not take Shift 1 and does not take Shift 4.
3. Dr. Aris takes an earlier shift than Dr. Bowen.
4. Each shift lasts a different number of hours:
   - Shift 1 lasts 4 hours.
   - Shift 2 lasts 6 hours.
   - Shift 3 lasts 5 hours.
   - Shift 4 lasts 7 hours.
5. In addition, each scientist collects data samples during their shift:
   - Whoever works Shift 1 collects 12 samples per hour.
   - Whoever works Shift 2 collects 8 samples per hour.
   - Whoever works Shift 3 collects 15 samples per hour.
   - Whoever works Shift 4 collects 10 samples per hour.

Question:
How many total data samples did Dr. Bowen collect during their assigned shift?

Provide your step-by-step deduction. On the very last line of your response, output ONLY the final answer in the format:
FINAL ANSWER: <integer>''';

  // Test 3: Python Coding
  static const String testPythonCodingId = 'python_coding';
  static const String testPythonCodingTitle = 'Python Coding Algorithm';
  static const String testPythonCodingPrompt = '''
Write a Python 3 function named 'flatten_and_unique' that accepts a nested list of arbitrary depth containing integers and returns a single sorted list containing only the unique integers in ascending order.

Example:
flatten_and_unique([1, [2, [3, 2]], [1, [4, 5]]]) -> [1, 2, 3, 4, 5]

Return only the Python code inside a ```python markdown code block without extra explanations.''';

  // Test 4: Strict Instruction Following
  static const String testInstructionFollowingId = 'instruction_following';
  static const String testInstructionFollowingTitle = 'Strict Instruction Following';
  static const String testInstructionFollowingPrompt = '''
Write a short paragraph about space exploration that strictly satisfies ALL of the following rules:
1. Your response must contain exactly four sentences.
2. The first sentence must begin with the word 'Deep'.
3. The third sentence must end with the word 'stars'.
4. Do NOT use the letter 'e' anywhere in the second sentence.
5. The total word count across all four sentences must be between 40 and 60 words.

Do not include any bullet points, notes, or preamble; output only the paragraph.''';
}

class BenchmarkTestRecord {
  final String testId;
  final String testTitle;
  final String modelDisplayName;
  final String ggufFileName;
  final String ggufFilePath;
  final String ggufSha256;
  final String architectureFamily;
  final String quantization;
  final int fileSizeBytes;
  final String contextSetting;
  final int requestedGpuLayers;
  final String actualGpuLayersOffloaded;
  final int promptTokens;
  final int generatedTokens;
  final double promptEvalSpeedTps;
  final double generationSpeedTps;
  final double promptEvalTimeMs;
  final double timeToFirstTokenMs;
  final int totalElapsedMs;
  final double peakVramMb;
  final double peakRamMb;
  final String completeResponse;
  final String status; // 'pass', 'fail', 'error', 'completed'
  final double scorePercent;
  final String scoreDetails;
  final DateTime timestamp;

  BenchmarkTestRecord({
    required this.testId,
    required this.testTitle,
    required this.modelDisplayName,
    required this.ggufFileName,
    required this.ggufFilePath,
    required this.ggufSha256,
    required this.architectureFamily,
    required this.quantization,
    required this.fileSizeBytes,
    required this.contextSetting,
    required this.requestedGpuLayers,
    required this.actualGpuLayersOffloaded,
    required this.promptTokens,
    required this.generatedTokens,
    required this.promptEvalSpeedTps,
    required this.generationSpeedTps,
    required this.promptEvalTimeMs,
    required this.timeToFirstTokenMs,
    required this.totalElapsedMs,
    required this.peakVramMb,
    required this.peakRamMb,
    required this.completeResponse,
    required this.status,
    required this.scorePercent,
    required this.scoreDetails,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'test_id': testId,
        'test_title': testTitle,
        'model_display_name': modelDisplayName,
        'gguf_file_name': ggufFileName,
        'gguf_file_path': ggufFilePath,
        'gguf_sha256': ggufSha256,
        'architecture_family': architectureFamily,
        'quantization': quantization,
        'file_size_bytes': fileSizeBytes,
        'context_setting': contextSetting,
        'requested_gpu_layers': requestedGpuLayers,
        'actual_gpu_layers_offloaded': actualGpuLayersOffloaded,
        'prompt_tokens': promptTokens,
        'generated_tokens': generatedTokens,
        'prompt_eval_speed_tps': promptEvalSpeedTps,
        'generation_speed_tps': generationSpeedTps,
        'prompt_eval_time_ms': promptEvalTimeMs,
        'time_to_first_token_ms': timeToFirstTokenMs,
        'total_elapsed_ms': totalElapsedMs,
        'peak_vram_mb': peakVramMb,
        'peak_ram_mb': peakRamMb,
        'complete_response': completeResponse,
        'status': status,
        'score_percent': scorePercent,
        'score_details': scoreDetails,
        'timestamp': timestamp.toIso8601String(),
      };

  factory BenchmarkTestRecord.fromJson(Map<String, dynamic> json) {
    return BenchmarkTestRecord(
      testId: json['test_id'] as String? ?? '',
      testTitle: json['test_title'] as String? ?? '',
      modelDisplayName: json['model_display_name'] as String? ?? '',
      ggufFileName: json['gguf_file_name'] as String? ?? '',
      ggufFilePath: json['gguf_file_path'] as String? ?? '',
      ggufSha256: json['gguf_sha256'] as String? ?? '',
      architectureFamily: json['architecture_family'] as String? ?? '',
      quantization: json['quantization'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      contextSetting: json['context_setting']?.toString() ?? '4096',
      requestedGpuLayers: (json['requested_gpu_layers'] as num?)?.toInt() ?? 99,
      actualGpuLayersOffloaded:
          json['actual_gpu_layers_offloaded'] as String? ?? 'N/A',
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
      generatedTokens: (json['generated_tokens'] as num?)?.toInt() ?? 0,
      promptEvalSpeedTps:
          (json['prompt_eval_speed_tps'] as num?)?.toDouble() ?? 0.0,
      generationSpeedTps:
          (json['generation_speed_tps'] as num?)?.toDouble() ?? 0.0,
      promptEvalTimeMs: (json['prompt_eval_time_ms'] as num?)?.toDouble() ?? 0.0,
      timeToFirstTokenMs:
          (json['time_to_first_token_ms'] as num?)?.toDouble() ?? 0.0,
      totalElapsedMs: (json['total_elapsed_ms'] as num?)?.toInt() ?? 0,
      peakVramMb: (json['peak_vram_mb'] as num?)?.toDouble() ?? 0.0,
      peakRamMb: (json['peak_ram_mb'] as num?)?.toDouble() ?? 0.0,
      completeResponse: json['complete_response'] as String? ?? '',
      status: json['status'] as String? ?? 'error',
      scorePercent: (json['score_percent'] as num?)?.toDouble() ?? 0.0,
      scoreDetails: json['score_details'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class BenchmarkModelSummary {
  final String modelDisplayName;
  final String ggufFileName;
  final String ggufFilePath;
  final String ggufSha256;
  final String architectureFamily;
  final String quantization;
  final int fileSizeBytes;
  final double avgPromptTps;
  final double avgGenTps;
  final double maxPeakVramMb;
  final double maxPeakRamMb;
  final double logicScore;
  final double codingScore;
  final double instructionScore;
  final double overallScore;
  final int passedTests;
  final int totalTests;
  final String status;

  BenchmarkModelSummary({
    required this.modelDisplayName,
    required this.ggufFileName,
    required this.ggufFilePath,
    required this.ggufSha256,
    required this.architectureFamily,
    required this.quantization,
    required this.fileSizeBytes,
    required this.avgPromptTps,
    required this.avgGenTps,
    required this.maxPeakVramMb,
    required this.maxPeakRamMb,
    required this.logicScore,
    required this.codingScore,
    required this.instructionScore,
    required this.overallScore,
    required this.passedTests,
    required this.totalTests,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'model_display_name': modelDisplayName,
        'gguf_file_name': ggufFileName,
        'gguf_file_path': ggufFilePath,
        'gguf_sha256': ggufSha256,
        'architecture_family': architectureFamily,
        'quantization': quantization,
        'file_size_bytes': fileSizeBytes,
        'avg_prompt_tps': avgPromptTps,
        'avg_gen_tps': avgGenTps,
        'max_peak_vram_mb': maxPeakVramMb,
        'max_peak_ram_mb': maxPeakRamMb,
        'logic_score': logicScore,
        'coding_score': codingScore,
        'instruction_score': instructionScore,
        'overall_score': overallScore,
        'passed_tests': passedTests,
        'total_tests': totalTests,
        'status': status,
      };

  factory BenchmarkModelSummary.fromJson(Map<String, dynamic> json) {
    return BenchmarkModelSummary(
      modelDisplayName: json['model_display_name'] as String? ?? '',
      ggufFileName: json['gguf_file_name'] as String? ?? '',
      ggufFilePath: json['gguf_file_path'] as String? ?? '',
      ggufSha256: json['gguf_sha256'] as String? ?? '',
      architectureFamily: json['architecture_family'] as String? ?? '',
      quantization: json['quantization'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      avgPromptTps: (json['avg_prompt_tps'] as num?)?.toDouble() ?? 0.0,
      avgGenTps: (json['avg_gen_tps'] as num?)?.toDouble() ?? 0.0,
      maxPeakVramMb: (json['max_peak_vram_mb'] as num?)?.toDouble() ?? 0.0,
      maxPeakRamMb: (json['max_peak_ram_mb'] as num?)?.toDouble() ?? 0.0,
      logicScore: (json['logic_score'] as num?)?.toDouble() ?? 0.0,
      codingScore: (json['coding_score'] as num?)?.toDouble() ?? 0.0,
      instructionScore:
          (json['instruction_score'] as num?)?.toDouble() ?? 0.0,
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      passedTests: (json['passed_tests'] as num?)?.toInt() ?? 0,
      totalTests: (json['total_tests'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'failed',
    );
  }
}

class BenchmarkSuiteResult {
  final String suiteVersion;
  final DateTime runTimestamp;
  final Map<String, dynamic> systemInfo;
  final List<BenchmarkModelSummary> summaries;
  final List<BenchmarkTestRecord> individualRuns;

  BenchmarkSuiteResult({
    required this.suiteVersion,
    required this.runTimestamp,
    required this.systemInfo,
    required this.summaries,
    required this.individualRuns,
  });

  Map<String, dynamic> toJson() => {
        'suite_version': suiteVersion,
        'run_timestamp': runTimestamp.toIso8601String(),
        'system_info': systemInfo,
        'summaries': summaries.map((s) => s.toJson()).toList(),
        'individual_runs': individualRuns.map((r) => r.toJson()).toList(),
      };
}
