// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../controllers/server_controller.dart';
import '../widgets/status_badge.dart';

class ServerTab extends StatefulWidget {
  final ServerController serverController;

  const ServerTab({super.key, required this.serverController});

  @override
  State<ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<ServerTab> {
  final ScrollController _logScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();
  bool _autoScroll = true;

  late final TextEditingController _ctxController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _extraArgsController;
  late final TextEditingController _binController;

  @override
  void initState() {
    super.initState();
    final config = widget.serverController.config;
    _ctxController = TextEditingController(text: config.ctxSize);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port);
    _extraArgsController = TextEditingController(text: config.extraArgs);
    _binController = TextEditingController(text: config.llamaBin);
  }

  @override
  void didUpdateWidget(covariant ServerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final config = widget.serverController.config;
    if (_ctxController.text != config.ctxSize) _ctxController.text = config.ctxSize;
    if (_hostController.text != config.host) _hostController.text = config.host;
    if (_portController.text != config.port) _portController.text = config.port;
    if (_extraArgsController.text != config.extraArgs) _extraArgsController.text = config.extraArgs;
    if (_binController.text != config.llamaBin) _binController.text = config.llamaBin;
  }

  @override
  Widget build(BuildContext context) {
    final srv = widget.serverController;
    final config = srv.config;

    // Auto-scroll logs to bottom if enabled
    if (_autoScroll && _logScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Configuration Controls (Scrollable)
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              controller: _mainScrollController,
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Control Bar
                  _buildControlHeader(srv, config),
                  const SizedBox(height: 12),

                  // 1. Model Selection Card
                  _buildModelCard(srv, config),
                  const SizedBox(height: 12),

                  // 2. Hardware & Inference Parameters Card
                  _buildParametersCard(srv, config),
                  const SizedBox(height: 12),

                  // 3. Command Preview Card
                  _buildCommandPreviewCard(config),
                ],
              ),
            ),
          ),

          // Right Column: Live Console Output
          Expanded(
            flex: 4,
            child: _buildConsoleCard(srv),
          ),
        ],
      ),
    );
  }

  // --- Top Control Bar ---

  Widget _buildControlHeader(ServerController srv, dynamic config) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          StatusBadge(
            status: srv.status,
            url: srv.isRunning ? config.baseUrl : null,
          ),
          const Spacer(),
          if (srv.isStopped)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: const Color(0xFF11111B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Start Server', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => srv.startServer(),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.stop, size: 20),
              label: const Text('Stop Server', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: srv.isStarting || srv.isRunning ? () => srv.stopServer() : null,
            ),
        ],
      ),
    );
  }

  // --- 1. Model Selection Card ---

  Widget _buildModelCard(ServerController srv, dynamic config) {
    final availableModels = srv.availableModels;
    final availableMmprojs = srv.availableMmprojs;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MODEL SELECTION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgCardLight,
                      foregroundColor: AppTheme.textMain,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: srv.isScanningModels
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                          )
                        : const Icon(Icons.refresh, size: 14),
                    label: const Text('Refresh'),
                    onPressed: srv.isScanningModels ? null : () => srv.rescanModels(),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgCardLight,
                      foregroundColor: AppTheme.textMain,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 14),
                    label: const Text('Add Folder...'),
                    onPressed: () => srv.addCustomModelFolder(),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgCardLight,
                      foregroundColor: AppTheme.textMain,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: const Text('Browse File...'),
                    onPressed: () => srv.browseModelFile(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active GGUF Model Selector
          const Text('Active GGUF Model:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: availableModels.any((m) => m.path == config.modelPath)
                ? config.modelPath
                : (availableModels.isNotEmpty ? availableModels.first.path : null),
            isExpanded: true,
            dropdownColor: AppTheme.bgInput,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: availableModels.map((m) {
              return DropdownMenuItem<String>(
                value: m.path,
                child: Text(
                  m.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (selectedPath) {
              if (selectedPath != null) {
                srv.setModelPath(selectedPath);
              }
            },
          ),
          const SizedBox(height: 4),
          Text(
            config.modelPath.isNotEmpty ? 'Path: ${config.modelPath}' : 'No model selected.',
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textSubtle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Vision mmproj Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vision mmproj (Optional):', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: config.mmprojPath.isNotEmpty ? () => srv.clearMmproj() : null,
                    child: const Text('Clear', style: TextStyle(fontSize: 11, color: AppTheme.danger)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => srv.browseMmprojFile(),
                    child: const Text('Browse...', style: TextStyle(fontSize: 11, color: AppTheme.accent)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: config.mmprojPath.isEmpty
                ? ''
                : (availableMmprojs.any((m) => m.path == config.mmprojPath) ? config.mmprojPath : ''),
            isExpanded: true,
            dropdownColor: AppTheme.bgInput,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('(None)', style: TextStyle(fontSize: 13, color: AppTheme.textSubtle)),
              ),
              ...availableMmprojs.map((m) {
                return DropdownMenuItem<String>(
                  value: m.path,
                  child: Text(
                    m.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            ],
            onChanged: (selectedPath) {
              srv.setMmprojPath(selectedPath ?? '');
            },
          ),
        ],
      ),
    );
  }

  // --- 2. Server Parameters & Hardware Configuration Card ---

  Widget _buildParametersCard(ServerController srv, dynamic config) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SERVER PARAMETERS & HARDWARE CONFIGURATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Row 0: GPU Layers (-ngl), Context Size (-c), CPU Threads (-t)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GPU Layers
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GPU Layers (-ngl):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 65,
                          child: TextFormField(
                            initialValue: config.nGpuLayers.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                            onChanged: (v) {
                              final val = int.tryParse(v);
                              if (val != null) srv.setGpuLayers(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.bgCardLight,
                            foregroundColor: AppTheme.textMain,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => srv.setGpuLayers(99),
                          child: const Text('All (99)', style: TextStyle(fontSize: 10.5)),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.bgCardLight,
                            foregroundColor: AppTheme.textMain,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => srv.setGpuLayers(0),
                          child: const Text('CPU (0)', style: TextStyle(fontSize: 10.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Context Window
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Context Size (-c):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ['2048', '4096', '8192', '16384', '32768', '65536', '131072'].contains(config.ctxSize)
                          ? config.ctxSize
                          : '8192',
                      dropdownColor: AppTheme.bgInput,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: ['2048', '4096', '8192', '16384', '32768', '65536', '131072'].map((c) {
                        return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) srv.setContextSize(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // CPU Threads
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Threads (-t):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: config.threads.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onChanged: (v) {
                        final val = int.tryParse(v);
                        if (val != null) srv.setThreads(val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 1: Flash Attention (-fa), Cache K (-ctk), Cache V (-ctv)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Flash Attention (-fa):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ['on', 'off', 'auto'].contains(config.flashAttn) ? config.flashAttn : 'on',
                      dropdownColor: AppTheme.bgInput,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: ['on', 'off', 'auto'].map((fa) {
                        return DropdownMenuItem(value: fa, child: Text(fa, style: const TextStyle(fontSize: 12.5)));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) srv.setFlashAttention(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cache Type K (-ctk):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ['q8_0', 'f16', 'q4_0', 'q5_1'].contains(config.cacheTypeK) ? config.cacheTypeK : 'q8_0',
                      dropdownColor: AppTheme.bgInput,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: ['q8_0', 'f16', 'q4_0', 'q5_1'].map((k) {
                        return DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 12.5)));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) srv.setCacheTypeK(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cache Type V (-ctv):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ['q8_0', 'f16', 'q4_0', 'q5_1'].contains(config.cacheTypeV) ? config.cacheTypeV : 'q8_0',
                      dropdownColor: AppTheme.bgInput,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: ['q8_0', 'f16', 'q4_0', 'q5_1'].map((v) {
                        return DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12.5)));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) srv.setCacheTypeV(v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Parallel Slots (-np), Host, Port
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Parallel Slots (-np):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: config.parallel.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onChanged: (v) {
                        final val = int.tryParse(v);
                        if (val != null) srv.setParallel(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Host (--host):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onChanged: (v) => srv.setHost(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Port (--port):', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onChanged: (v) => srv.setPort(v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Memory Lock (--mlock) & Extra Arguments
          Row(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: config.mlock,
                    activeColor: AppTheme.accent,
                    onChanged: (v) => srv.setMlock(v ?? false),
                  ),
                  const Text('Lock Memory (--mlock)', style: TextStyle(fontSize: 12, color: AppTheme.textMain)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    const Text('Extra Flags: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        controller: _extraArgsController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. -lv 3 --no-mmap',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (v) => srv.setExtraArgs(v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: Executable Path
          Row(
            children: [
              const Text('Binary: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: _binController,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (v) => srv.setLlamaBin(v),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bgCardLight,
                  foregroundColor: AppTheme.textMain,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => srv.browseLlamaBin(),
                child: const Text('Browse...', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Command Preview Card ---

  Widget _buildCommandPreviewCard(dynamic config) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMMAND PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 0.5,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bgCardLight,
                  foregroundColor: AppTheme.textMain,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.copy, size: 13),
                label: const Text('Copy Command'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: config.commandPreview));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Command copied to clipboard')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              config.commandPreview,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                color: AppTheme.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Right Column: Live Console Output ---

  Widget _buildConsoleCard(ServerController srv) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SERVER CONSOLE OUTPUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _autoScroll,
                        activeColor: AppTheme.accent,
                        onChanged: (v) => setState(() => _autoScroll = v ?? true),
                      ),
                      const Text('Autoscroll', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgCardLight,
                      foregroundColor: AppTheme.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => srv.clearLogs(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF11111B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: srv.consoleLogs.isEmpty
                  ? const Center(
                      child: Text(
                        'No console output yet. Click "Start Server" to begin.',
                        style: TextStyle(color: AppTheme.textSubtle, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      itemCount: srv.consoleLogs.length,
                      itemBuilder: (context, index) {
                        final logLine = srv.consoleLogs[index];
                        Color lineCol = AppTheme.textMain;
                        if (logLine.contains('[ERROR') || logLine.contains('error')) {
                          lineCol = AppTheme.danger;
                        } else if (logLine.contains('[LAUNCHER]') || logLine.contains('HTTP server')) {
                          lineCol = AppTheme.accent;
                        } else if (logLine.contains('all slots are ready') || logLine.contains('LIVE')) {
                          lineCol = AppTheme.success;
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.0),
                          child: SelectableText(
                            logLine,
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 11.5,
                              color: lineCol,
                              height: 1.2,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    _mainScrollController.dispose();
    _ctxController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _extraArgsController.dispose();
    _binController.dispose();
    super.dispose();
  }
}
