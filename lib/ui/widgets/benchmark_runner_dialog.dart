import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/benchmark_models.dart';
import '../../controllers/server_controller.dart';
import '../../services/llama_client.dart';
import '../../services/hardware_monitor_service.dart';
import '../../services/benchmark_runner_service.dart';

class BenchmarkRunnerDialog extends StatefulWidget {
  final ServerController serverController;
  final LlamaClient llamaClient;
  final HardwareMonitorService hardwareMonitor;

  const BenchmarkRunnerDialog({
    super.key,
    required this.serverController,
    required this.llamaClient,
    required this.hardwareMonitor,
  });

  @override
  State<BenchmarkRunnerDialog> createState() => _BenchmarkRunnerDialogState();
}

enum _BenchState { select, running, results }

class _BenchmarkRunnerDialogState extends State<BenchmarkRunnerDialog> {
  late final BenchmarkRunnerService _runnerService;
  StreamSubscription<BenchmarkProgressEvent>? _progressSub;

  _BenchState _state = _BenchState.select;
  final Set<String> _selectedModelPaths = {};

  BenchmarkProgressEvent? _latestProgress;
  BenchmarkSuiteResult? _finalResult;
  String? _exportDirectory;

  @override
  void initState() {
    super.initState();
    _runnerService = BenchmarkRunnerService(
      serverController: widget.serverController,
      llamaClient: widget.llamaClient,
      hardwareMonitor: widget.hardwareMonitor,
    );

    // Default select all available models
    for (final m in widget.serverController.availableModels) {
      _selectedModelPaths.add(m.path);
    }

    _progressSub = _runnerService.progressStream.listen((event) {
      setState(() {
        _latestProgress = event;
        if (event.isFinished) {
          _state = _BenchState.results;
          _finalResult = event.result;
          _exportDirectory = event.exportDirectory;
        }
      });
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _runnerService.dispose();
    super.dispose();
  }

  void _startBenchmark() {
    final models = widget.serverController.availableModels
        .where((m) => _selectedModelPaths.contains(m.path))
        .toList();

    if (models.isEmpty) return;

    setState(() {
      _state = _BenchState.running;
    });

    _runnerService.runBenchmark(models);
  }

  void _openFile(String? filePath) {
    if (filePath == null) return;
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '', filePath]);
      }
    } catch (_) {}
  }

  void _openFolder(String? dirPath) {
    if (dirPath == null) return;
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [dirPath]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.speed, color: AppTheme.accent, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Developer Benchmark Runner',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      MdBenchConstants.suiteVersion,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Sequential, unattended evaluation across local models with fixed parameters and deterministic scoring.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        if (_state == _BenchState.select)
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textMuted),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _BenchState.select:
        return _buildSelectView();
      case _BenchState.running:
        return _buildRunningView();
      case _BenchState.results:
        return _buildResultsView();
    }
  }

  // -----------------------------------------------------------------
  // View 1: Model Selection Checklist
  // -----------------------------------------------------------------
  Widget _buildSelectView() {
    final allModels = widget.serverController.availableModels;

    if (allModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No GGUF models discovered in library',
              style: TextStyle(fontSize: 14, color: AppTheme.textMain),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add model directories in the Models tab first.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSubtle),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Suite Description Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '4 Fixed Tests: 1. Titanic Maiden Voyage (General Prose) | 2. Shift Scheduling Logic (Deterministic, Ans: 48) | '
                  '3. flatten_and_unique (Python Unit Tests) | 4. Space Exploration (Strict 4-Sentence Rule Constraints).\n'
                  'Fixed Configuration: Context: 4096 | GPU Layers: 99 | Temp: 0.0 (Greedy) | Automatic user server restoration.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Selection Controls Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Models to Benchmark (${_selectedModelPaths.length} of ${allModels.length} selected):',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedModelPaths.addAll(allModels.map((m) => m.path));
                    });
                  },
                  child: const Text('Select All', style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedModelPaths.clear();
                    });
                  },
                  child: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Scrollable Model List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: ListView.separated(
              itemCount: allModels.length,
              separatorBuilder: (_, _) => const Divider(color: AppTheme.border, height: 1),
              itemBuilder: (context, index) {
                final model = allModels[index];
                final isSelected = _selectedModelPaths.contains(model.path);

                return CheckboxListTile(
                  value: isSelected,
                  activeColor: AppTheme.accent,
                  checkColor: const Color(0xFF11111B),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedModelPaths.add(model.path);
                      } else {
                        _selectedModelPaths.remove(model.path);
                      }
                    });
                  },
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMain,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Architecture Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          model.architectureFamily,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSubtle),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Quant Badge
                      if (model.quantization.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            model.quantization,
                            style: const TextStyle(fontSize: 10, color: AppTheme.accent),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // File Size
                      Text(
                        model.formattedSize,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    model.path,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSubtle),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // View 2: Live Benchmark Execution Progress
  // -----------------------------------------------------------------
  Widget _buildRunningView() {
    final p = _latestProgress;
    final total = p?.totalOverall ?? 1;
    final done = p?.completedOverall ?? 0;
    final progressVal = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

    final elapsedStr = p != null
        ? '${p.elapsedTime.inMinutes.toString().padLeft(2, '0')}:${(p.elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}'
        : '00:00';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Icon
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 24),

            // Main Status Text
            Text(
              p?.statusMessage ?? 'Initializing benchmark runner...',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Current Model & Test
            if (p != null && p.currentModelName.isNotEmpty)
              Text(
                'Model ${p.currentModelIndex}/${p.totalModels}: ${p.currentModelName}',
                style: const TextStyle(fontSize: 13, color: AppTheme.cyan),
                textAlign: TextAlign.center,
              ),
            if (p != null && p.currentTestTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${p.currentTestTitle} (${p.currentTestIndex}/4)',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 24),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressVal,
                minHeight: 10,
                backgroundColor: AppTheme.bgInput,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
            const SizedBox(height: 10),

            // Metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completed: $done / $total tests',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                ),
                Text(
                  'Elapsed: $elapsedStr',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // View 3: Benchmark Results Summary & Exports
  // -----------------------------------------------------------------
  Widget _buildResultsView() {
    final result = _finalResult;
    if (result == null) {
      return const Center(child: Text('No results available.'));
    }

    final excelPath = '$_exportDirectory${Platform.pathSeparator}benchmark_results.xlsx';
    final csvPath = '$_exportDirectory${Platform.pathSeparator}benchmark_results.csv';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Header & Export Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgInput,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Benchmark Completed & Exported',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Files generated in: $_exportDirectory',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Open Excel Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D6F42), // Excel green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.table_chart, size: 16),
                label: const Text('Open Excel (.xlsx)'),
                onPressed: () => _openFile(excelPath),
              ),
              const SizedBox(width: 8),
              // Open CSV Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMain,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.file_present, size: 16),
                label: const Text('CSV'),
                onPressed: () => _openFile(csvPath),
              ),
              const SizedBox(width: 8),
              // Open Folder Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMain,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Folder'),
                onPressed: () => _openFolder(_exportDirectory),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Summary Table
        const Text(
          'Model Performance & Score Comparison:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.bgCard),
                  columnSpacing: 18,
                  headingTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 11, color: AppTheme.textMain),
                  columns: const [
                    DataColumn(label: Text('Model')),
                    DataColumn(label: Text('Arch')),
                    DataColumn(label: Text('Quant')),
                    DataColumn(label: Text('Prompt tok/s')),
                    DataColumn(label: Text('Gen tok/s')),
                    DataColumn(label: Text('Peak VRAM')),
                    DataColumn(label: Text('Logic')),
                    DataColumn(label: Text('Coding')),
                    DataColumn(label: Text('Instruction')),
                    DataColumn(label: Text('Overall')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: result.summaries.map((s) {
                    final statusColor = s.status == 'passed'
                        ? AppTheme.success
                        : (s.status == 'partial' ? Colors.orange : AppTheme.danger);

                    return DataRow(
                      cells: [
                        DataCell(Text(s.modelDisplayName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(s.architectureFamily)),
                        DataCell(Text(s.quantization)),
                        DataCell(Text('${s.avgPromptTps.toStringAsFixed(1)} t/s')),
                        DataCell(Text('${s.avgGenTps.toStringAsFixed(1)} t/s',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent))),
                        DataCell(Text('${s.maxPeakVramMb.toStringAsFixed(0)} MB')),
                        DataCell(Text('${s.logicScore.toStringAsFixed(0)}%')),
                        DataCell(Text('${s.codingScore.toStringAsFixed(0)}%')),
                        DataCell(Text('${s.instructionScore.toStringAsFixed(0)}%')),
                        DataCell(Text('${s.overallScore.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              s.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    switch (_state) {
      case _BenchState.select:
        final count = _selectedModelPaths.length;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textMuted,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF11111B),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text('Start Benchmark ($count Model${count == 1 ? '' : 's'})'),
              onPressed: count > 0 ? _startBenchmark : null,
            ),
          ],
        );
      case _BenchState.running:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Cancel Benchmark'),
              onPressed: () {
                _runnerService.cancelBenchmark();
              },
            ),
          ],
        );
      case _BenchState.results:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_finalResult?.summaries.length ?? 0} models evaluated. Original server state restored.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF11111B),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
    }
  }
}
