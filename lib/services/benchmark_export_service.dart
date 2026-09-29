import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:syncfusion_officechart/officechart.dart';
import '../models/benchmark_models.dart';

class BenchmarkExportService {
  static Future<void> exportAll({
    required BenchmarkSuiteResult result,
    required String outputDir,
  }) async {
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final excelPath = '${dir.path}${Platform.pathSeparator}benchmark_results.xlsx';
    final csvPath = '${dir.path}${Platform.pathSeparator}benchmark_results.csv';
    final jsonPath = '${dir.path}${Platform.pathSeparator}benchmark_results.json';

    await exportToExcel(result, excelPath);
    await exportToCsv(result, csvPath);
    await exportToJson(result, jsonPath);
  }

  static Future<void> exportToExcel(
    BenchmarkSuiteResult result,
    String outputPath,
  ) async {
    final workbook = Workbook();

    // -------------------------------------------------------------
    // SHEET 1: Summary
    // -------------------------------------------------------------
    final sheetSummary = workbook.worksheets[0];
    sheetSummary.name = 'Summary';

    final summaryHeaders = [
      'Model Name',
      'GGUF File',
      'GGUF SHA-256',
      'Architecture',
      'Quantization',
      'Size (MB)',
      'Prompt tok/s',
      'Gen tok/s',
      'Peak VRAM (MB)',
      'Peak RAM (MB)',
      'Logic (%)',
      'Coding (%)',
      'Instruction (%)',
      'Overall (%)',
      'Status',
    ];

    for (int col = 0; col < summaryHeaders.length; col++) {
      final cell = sheetSummary.getRangeByIndex(1, col + 1);
      cell.setText(summaryHeaders[col]);
      cell.cellStyle.bold = true;
    }

    int row = 2;
    for (final s in result.summaries) {
      sheetSummary.getRangeByIndex(row, 1).setText(s.modelDisplayName);
      sheetSummary.getRangeByIndex(row, 2).setText(s.ggufFileName);
      sheetSummary.getRangeByIndex(row, 3).setText(s.ggufSha256);
      sheetSummary.getRangeByIndex(row, 4).setText(s.architectureFamily);
      sheetSummary.getRangeByIndex(row, 5).setText(s.quantization);
      sheetSummary
          .getRangeByIndex(row, 6)
          .setNumber(double.parse((s.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)));
      sheetSummary.getRangeByIndex(row, 7).setNumber(double.parse(s.avgPromptTps.toStringAsFixed(2)));
      sheetSummary.getRangeByIndex(row, 8).setNumber(double.parse(s.avgGenTps.toStringAsFixed(2)));
      sheetSummary.getRangeByIndex(row, 9).setNumber(double.parse(s.maxPeakVramMb.toStringAsFixed(1)));
      sheetSummary.getRangeByIndex(row, 10).setNumber(double.parse(s.maxPeakRamMb.toStringAsFixed(1)));
      sheetSummary.getRangeByIndex(row, 11).setNumber(double.parse(s.logicScore.toStringAsFixed(1)));
      sheetSummary.getRangeByIndex(row, 12).setNumber(double.parse(s.codingScore.toStringAsFixed(1)));
      sheetSummary.getRangeByIndex(row, 13).setNumber(double.parse(s.instructionScore.toStringAsFixed(1)));
      sheetSummary.getRangeByIndex(row, 14).setNumber(double.parse(s.overallScore.toStringAsFixed(1)));
      sheetSummary.getRangeByIndex(row, 15).setText(s.status.toUpperCase());
      row++;
    }

    final totalModels = result.summaries.length;
    if (totalModels > 0) {
      final ChartCollection charts = ChartCollection(sheetSummary);

      // Chart 1: Generation tok/s Comparison (Bar Chart)
      final chartTps = charts.add();
      chartTps.chartType = ExcelChartType.bar;
      chartTps.dataRange = sheetSummary.getRangeByName('A1:B${totalModels + 1}');
      chartTps.isSeriesInRows = false;
      chartTps.topRow = totalModels + 3;
      chartTps.bottomRow = totalModels + 18;
      chartTps.leftColumn = 1;
      chartTps.rightColumn = 8;
      chartTps.chartTitle = 'Model Generation Speed (tok/s)';

      // Chart 2: Objective Benchmark Scores (Column Chart)
      final chartScores = charts.add();
      chartScores.chartType = ExcelChartType.column;
      chartScores.dataRange = sheetSummary.getRangeByName('A1:A${totalModels + 1}');
      chartScores.dataRange = sheetSummary.getRangeByName('K1:N${totalModels + 1}');
      chartScores.isSeriesInRows = false;
      chartScores.topRow = totalModels + 20;
      chartScores.bottomRow = totalModels + 36;
      chartScores.leftColumn = 1;
      chartScores.rightColumn = 10;
      chartScores.chartTitle = 'Objective Benchmark Scores (%)';

      sheetSummary.charts = charts;
    }

    // -------------------------------------------------------------
    // SHEET 2: Individual Runs
    // -------------------------------------------------------------
    final sheetRuns = workbook.worksheets.addWithName('Individual Runs');
    final runHeaders = [
      'Timestamp',
      'Model Name',
      'GGUF SHA-256',
      'Test ID',
      'Test Title',
      'Context',
      'Requested Layers',
      'Actual Offload',
      'Status',
      'Score (%)',
      'Prompt Tokens',
      'Generated Tokens',
      'Prompt tok/s',
      'Gen tok/s',
      'Prompt Eval (ms)',
      'TTFT (ms)',
      'Duration (ms)',
      'Peak VRAM (MB)',
      'Peak RAM (MB)',
      'Score Details',
    ];

    for (int col = 0; col < runHeaders.length; col++) {
      final cell = sheetRuns.getRangeByIndex(1, col + 1);
      cell.setText(runHeaders[col]);
      cell.cellStyle.bold = true;
    }

    int runRow = 2;
    for (final r in result.individualRuns) {
      sheetRuns.getRangeByIndex(runRow, 1).setText(r.timestamp.toIso8601String());
      sheetRuns.getRangeByIndex(runRow, 2).setText(r.modelDisplayName);
      sheetRuns.getRangeByIndex(runRow, 3).setText(r.ggufSha256);
      sheetRuns.getRangeByIndex(runRow, 4).setText(r.testId);
      sheetRuns.getRangeByIndex(runRow, 5).setText(r.testTitle);
      sheetRuns.getRangeByIndex(runRow, 6).setText(r.contextSetting);
      sheetRuns.getRangeByIndex(runRow, 7).setNumber(r.requestedGpuLayers.toDouble());
      sheetRuns.getRangeByIndex(runRow, 8).setText(r.actualGpuLayersOffloaded);
      sheetRuns.getRangeByIndex(runRow, 9).setText(r.status.toUpperCase());
      sheetRuns.getRangeByIndex(runRow, 10).setNumber(double.parse(r.scorePercent.toStringAsFixed(1)));
      sheetRuns.getRangeByIndex(runRow, 11).setNumber(r.promptTokens.toDouble());
      sheetRuns.getRangeByIndex(runRow, 12).setNumber(r.generatedTokens.toDouble());
      sheetRuns.getRangeByIndex(runRow, 13).setNumber(double.parse(r.promptEvalSpeedTps.toStringAsFixed(2)));
      sheetRuns.getRangeByIndex(runRow, 14).setNumber(double.parse(r.generationSpeedTps.toStringAsFixed(2)));
      sheetRuns.getRangeByIndex(runRow, 15).setNumber(double.parse(r.promptEvalTimeMs.toStringAsFixed(1)));
      sheetRuns.getRangeByIndex(runRow, 16).setNumber(double.parse(r.timeToFirstTokenMs.toStringAsFixed(1)));
      sheetRuns.getRangeByIndex(runRow, 17).setNumber(r.totalElapsedMs.toDouble());
      sheetRuns.getRangeByIndex(runRow, 18).setNumber(double.parse(r.peakVramMb.toStringAsFixed(1)));
      sheetRuns.getRangeByIndex(runRow, 19).setNumber(double.parse(r.peakRamMb.toStringAsFixed(1)));
      sheetRuns.getRangeByIndex(runRow, 20).setText(r.scoreDetails);
      runRow++;
    }

    // -------------------------------------------------------------
    // SHEET 3: Full Responses
    // -------------------------------------------------------------
    final sheetResponses = workbook.worksheets.addWithName('Full Responses');
    final respHeaders = [
      'Timestamp',
      'Model Name',
      'GGUF SHA-256',
      'Test Title',
      'Status',
      'Score (%)',
      'Complete Model Response',
    ];

    for (int col = 0; col < respHeaders.length; col++) {
      final cell = sheetResponses.getRangeByIndex(1, col + 1);
      cell.setText(respHeaders[col]);
      cell.cellStyle.bold = true;
    }

    int respRow = 2;
    for (final r in result.individualRuns) {
      sheetResponses.getRangeByIndex(respRow, 1).setText(r.timestamp.toIso8601String());
      sheetResponses.getRangeByIndex(respRow, 2).setText(r.modelDisplayName);
      sheetResponses.getRangeByIndex(respRow, 3).setText(r.ggufSha256);
      sheetResponses.getRangeByIndex(respRow, 4).setText(r.testTitle);
      sheetResponses.getRangeByIndex(respRow, 5).setText(r.status.toUpperCase());
      sheetResponses.getRangeByIndex(respRow, 6).setNumber(double.parse(r.scorePercent.toStringAsFixed(1)));
      sheetResponses.getRangeByIndex(respRow, 7).setText(r.completeResponse);
      respRow++;
    }

    // -------------------------------------------------------------
    // SHEET 4: System Info
    // -------------------------------------------------------------
    final sheetSystem = workbook.worksheets.addWithName('System Info');
    sheetSystem.getRangeByName('A1').setText('Property');
    sheetSystem.getRangeByName('B1').setText('Value');
    sheetSystem.getRangeByName('A1:B1').cellStyle.bold = true;

    final sysProps = <MapEntry<String, String>>[
      MapEntry('Benchmark Suite', result.suiteVersion),
      MapEntry('Run Timestamp', result.runTimestamp.toIso8601String()),
      ...result.systemInfo.entries.map((e) => MapEntry(e.key, e.value.toString())),
      const MapEntry('Notes', 'Unattended execution with standard MD-Bench 1.0 parameters.'),
    ];

    for (int i = 0; i < sysProps.length; i++) {
      sheetSystem.getRangeByIndex(i + 2, 1).setText(sysProps[i].key);
      sheetSystem.getRangeByIndex(i + 2, 2).setText(sysProps[i].value);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final file = File(outputPath);
    await file.writeAsBytes(bytes);
    debugPrint('[BenchmarkExportService] Excel exported to: $outputPath (${bytes.length} bytes)');
  }

  static Future<void> exportToCsv(
    BenchmarkSuiteResult result,
    String outputPath,
  ) async {
    final buffer = StringBuffer();

    final headers = [
      'timestamp',
      'suite_version',
      'model_display_name',
      'gguf_file_name',
      'gguf_file_path',
      'gguf_sha256',
      'architecture_family',
      'quantization',
      'file_size_bytes',
      'test_id',
      'test_title',
      'context_setting',
      'requested_gpu_layers',
      'actual_gpu_layers_offloaded',
      'status',
      'score_percent',
      'prompt_tokens',
      'generated_tokens',
      'prompt_eval_speed_tps',
      'generation_speed_tps',
      'prompt_eval_time_ms',
      'time_to_first_token_ms',
      'total_elapsed_ms',
      'peak_vram_mb',
      'peak_ram_mb',
      'score_details',
      'complete_response',
    ];

    buffer.writeln(headers.join(','));

    for (final r in result.individualRuns) {
      final row = [
        _escapeCsv(r.timestamp.toIso8601String()),
        _escapeCsv(result.suiteVersion),
        _escapeCsv(r.modelDisplayName),
        _escapeCsv(r.ggufFileName),
        _escapeCsv(r.ggufFilePath),
        _escapeCsv(r.ggufSha256),
        _escapeCsv(r.architectureFamily),
        _escapeCsv(r.quantization),
        r.fileSizeBytes.toString(),
        _escapeCsv(r.testId),
        _escapeCsv(r.testTitle),
        _escapeCsv(r.contextSetting),
        r.requestedGpuLayers.toString(),
        _escapeCsv(r.actualGpuLayersOffloaded),
        _escapeCsv(r.status),
        r.scorePercent.toStringAsFixed(1),
        r.promptTokens.toString(),
        r.generatedTokens.toString(),
        r.promptEvalSpeedTps.toStringAsFixed(2),
        r.generationSpeedTps.toStringAsFixed(2),
        r.promptEvalTimeMs.toStringAsFixed(1),
        r.timeToFirstTokenMs.toStringAsFixed(1),
        r.totalElapsedMs.toString(),
        r.peakVramMb.toStringAsFixed(1),
        r.peakRamMb.toStringAsFixed(1),
        _escapeCsv(r.scoreDetails),
        _escapeCsv(r.completeResponse),
      ];
      buffer.writeln(row.join(','));
    }

    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
    debugPrint('[BenchmarkExportService] CSV exported to: $outputPath');
  }

  static Future<void> exportToJson(
    BenchmarkSuiteResult result,
    String outputPath,
  ) async {
    final file = File(outputPath);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(result.toJson());
    await file.writeAsString(jsonStr);
    debugPrint('[BenchmarkExportService] JSON exported to: $outputPath');
  }

  static String _escapeCsv(String val) {
    var s = val.replaceAll('"', '""');
    s = s.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
    return '"$s"';
  }
}
