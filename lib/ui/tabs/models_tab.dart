// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../core/theme.dart';
import '../../models/gguf_model.dart';
import '../../controllers/server_controller.dart';
import '../../controllers/profile_controller.dart';

class ModelsTab extends StatefulWidget {
  final ServerController serverController;
  final ProfileController profileController;
  final void Function(int tabIndex)? onNavigateToTab;

  const ModelsTab({
    super.key,
    required this.serverController,
    required this.profileController,
    this.onNavigateToTab,
  });

  @override
  State<ModelsTab> createState() => _ModelsTabState();
}

class _ModelsTabState extends State<ModelsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openInExplorer(String filePath) {
    if (Platform.isWindows) {
      try {
        Process.run('explorer.exe', ['/select,', filePath]);
      } catch (_) {}
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.bgCardLight,
      ),
    );
  }

  void _showCreateProfileDialog(GgufModelInfo model) {
    final nameController = TextEditingController(
      text: '${model.architectureFamily} ${model.parameterSize.isNotEmpty ? model.parameterSize : "Tuned"} (${model.quantization})',
    );
    final descController = TextEditingController(
      text: 'Custom profile for ${model.name}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Create Profile from Model', style: TextStyle(color: AppTheme.textMain)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Model: ${model.name}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Profile Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                // Find matching mmproj
                final pairedMm = widget.serverController.availableMmprojs
                    .where((m) => p.dirname(m.path) == p.dirname(model.path));
                final mmPath = pairedMm.isNotEmpty ? pairedMm.first.path : '';

                await widget.profileController.createFromCurrentConfig(
                  name: name,
                  description: descController.text.trim(),
                  config: widget.serverController.config.copyWith(
                    modelPath: model.path,
                    mmprojPath: mmPath,
                  ),
                );
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Profile "$name" created!')),
                  );
                }
              }
            },
            child: const Text('Create Profile', style: TextStyle(color: Color(0xFF11111B))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final srv = widget.serverController;
    final allModels = srv.availableModels;

    final filteredModels = allModels.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.architectureFamily.toLowerCase().contains(q) ||
          m.quantization.toLowerCase().contains(q);
    }).toList();

    int totalBytes = 0;
    for (final m in allModels) {
      totalBytes += m.sizeBytes;
    }
    final totalGb = (totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2, color: AppTheme.accent, size: 24),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Model Library',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                          Text(
                            '${allModels.length} models discovered ($totalGb GB total storage)',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Search Input
                      SizedBox(
                        width: 260,
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search models, families, quants...',
                            prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Rescan Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.bgInput,
                          foregroundColor: AppTheme.textMain,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: srv.isScanningModels
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: const Text('Rescan Folders', style: TextStyle(fontSize: 12)),
                        onPressed: srv.isScanningModels ? null : () => srv.rescanModels(),
                      ),
                      const SizedBox(width: 8),

                      // Add Folder Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: const Color(0xFF11111B),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: const Icon(Icons.create_new_folder, size: 16),
                        label: const Text('Add Folder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => srv.addCustomModelFolder(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Scanned Folders Chips
                  Row(
                    children: [
                      const Text(
                        'Search Folders:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSubtle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: srv.config.customModelDirs.map((dir) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Chip(
                                  backgroundColor: AppTheme.bgInput,
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.folder_open, size: 14, color: AppTheme.accent),
                                  label: Text(
                                    p.basename(dir),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMain),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 12),
                                  onDeleted: () {
                                    srv.removeCustomModelFolder(dir);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Models Grid
          Expanded(
            child: filteredModels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: AppTheme.textSubtle),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No models matching "$_searchQuery"'
                              : 'No GGUF models found in search folders.',
                          style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Add Model Folder'),
                          onPressed: () => srv.addCustomModelFolder(),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 2 : 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isWide ? 3.0 : 2.5,
                        ),
                        itemCount: filteredModels.length,
                        itemBuilder: (context, index) {
                          final model = filteredModels[index];
                          final isCurrentlyLoaded =
                              p.normalize(srv.config.modelPath).toLowerCase() ==
                              p.normalize(model.path).toLowerCase();

                          // Check if an mmproj file is paired in the same folder
                          final matchingMm = srv.availableMmprojs
                              .where((m) => p.dirname(m.path) == p.dirname(model.path));
                          final hasVisionMmproj = matchingMm.isNotEmpty;

                          return _buildModelCard(
                            model: model,
                            isLoaded: isCurrentlyLoaded,
                            hasVisionMmproj: hasVisionMmproj,
                            visionMmprojName: hasVisionMmproj ? matchingMm.first.name : null,
                            srv: srv,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard({
    required GgufModelInfo model,
    required bool isLoaded,
    required bool hasVisionMmproj,
    String? visionMmprojName,
    required ServerController srv,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isLoaded ? AppTheme.success : AppTheme.border,
          width: isLoaded ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Title & Status Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        model.path,
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSubtle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.success),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text(
                          'ACTIVE IN SERVER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Middle Row: Tags & Metadata
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildTag(model.architectureFamily, AppTheme.accent),
                if (model.quantization.isNotEmpty)
                  _buildTag(model.quantization, AppTheme.warning),
                _buildTag(model.formattedSize, AppTheme.textMuted),
                if (hasVisionMmproj)
                  _buildTag('Vision Paired', AppTheme.cyan, icon: Icons.visibility),
              ],
            ),

            // Bottom Actions Row
            Row(
              children: [
                // Load in Server
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLoaded ? AppTheme.bgHover : AppTheme.accent,
                    foregroundColor: isLoaded ? AppTheme.textMain : const Color(0xFF11111B),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(isLoaded ? Icons.check : Icons.play_arrow, size: 14),
                  label: Text(
                    isLoaded ? 'Loaded' : 'Load in Server',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: isLoaded
                      ? null
                      : () {
                          srv.setModelPath(model.path);
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(1); // Go to Server tab
                          }
                        },
                ),
                const SizedBox(width: 6),

                // Create Profile
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                  label: const Text('Save Profile', style: TextStyle(fontSize: 11)),
                  onPressed: () => _showCreateProfileDialog(model),
                ),

                const Spacer(),

                // Open in Explorer
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 16, color: AppTheme.textMuted),
                  tooltip: 'Show in Explorer',
                  onPressed: () => _openInExplorer(model.path),
                ),

                // Copy Path
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 15, color: AppTheme.textMuted),
                  tooltip: 'Copy File Path',
                  onPressed: () => _copyToClipboard(model.path, 'Model path'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
