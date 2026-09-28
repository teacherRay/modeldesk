// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/model_profile.dart';
import '../../controllers/server_controller.dart';
import '../../controllers/profile_controller.dart';

class ProfilesTab extends StatefulWidget {
  final ServerController serverController;
  final ProfileController profileController;
  final void Function(int tabIndex)? onNavigateToTab;

  const ProfilesTab({
    super.key,
    required this.serverController,
    required this.profileController,
    this.onNavigateToTab,
  });

  @override
  State<ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<ProfilesTab> {
  void _showProfileDialog({ModelProfile? existing}) {
    final srv = widget.serverController;
    final isEditing = existing != null;

    final nameController = TextEditingController(
      text: existing?.name ?? 'Custom Profile',
    );
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    int nGpuLayers = existing?.nGpuLayers ?? srv.config.nGpuLayers;
    int threads = existing?.threads ?? srv.config.threads;
    String ctxSize = existing?.ctxSize ?? srv.config.ctxSize;
    String flashAttn = existing?.flashAttn ?? srv.config.flashAttn;
    String cacheTypeK = existing?.cacheTypeK ?? srv.config.cacheTypeK;
    String cacheTypeV = existing?.cacheTypeV ?? srv.config.cacheTypeV;
    int parallel = existing?.parallel ?? srv.config.parallel;
    bool mlock = existing?.mlock ?? srv.config.mlock;
    String selectedModel = existing?.modelPath ?? srv.config.modelPath;
    String selectedMmproj = existing?.mmprojPath ?? srv.config.mmprojPath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: Text(
            isEditing ? 'Edit Profile: ${existing.name}' : 'Create New Model Profile',
            style: const TextStyle(color: AppTheme.textMain, fontSize: 16),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Profile Name *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 16),

                  // Model Selection in Profile
                  const Text('Associated Model (Optional):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSubtle)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedModel.isNotEmpty &&
                            srv.availableModels.any((m) => m.path == selectedModel)
                        ? selectedModel
                        : null,
                    decoration: const InputDecoration(hintText: 'Any Model (Global Profile)'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Any Model (Hardware Preset)', style: TextStyle(fontSize: 12)),
                      ),
                      ...srv.availableModels.map((m) => DropdownMenuItem(
                            value: m.path,
                            child: Text(m.displayName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedModel = val ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Hardware Parameters Grid
                  const Text('Hardware & Engine Parameters:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSubtle)),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // GPU Layers
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GPU Layers (-ngl): $nGpuLayers', style: const TextStyle(fontSize: 11)),
                            Slider(
                              value: nGpuLayers.toDouble().clamp(0.0, 99.0),
                              min: 0,
                              max: 99,
                              divisions: 99,
                              label: '$nGpuLayers',
                              onChanged: (v) => setDialogState(() => nGpuLayers = v.round()),
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
                            Text('Threads (-t): $threads', style: const TextStyle(fontSize: 11)),
                            Slider(
                              value: threads.toDouble().clamp(1.0, 32.0),
                              min: 1,
                              max: 32,
                              divisions: 31,
                              label: '$threads',
                              onChanged: (v) => setDialogState(() => threads = v.round()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Context Window
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: ['2048', '4096', '8192', '16384', '32768', '65536', '131072'].contains(ctxSize)
                              ? ctxSize
                              : '8192',
                          decoration: const InputDecoration(labelText: 'Context Size (-c)'),
                          items: const [
                            DropdownMenuItem(value: '2048', child: Text('2,048 (2K)')),
                            DropdownMenuItem(value: '4096', child: Text('4,096 (4K)')),
                            DropdownMenuItem(value: '8192', child: Text('8,192 (8K)')),
                            DropdownMenuItem(value: '16384', child: Text('16,384 (16K)')),
                            DropdownMenuItem(value: '32768', child: Text('32,768 (32K)')),
                            DropdownMenuItem(value: '65536', child: Text('65,536 (64K)')),
                          ],
                          onChanged: (v) => setDialogState(() => ctxSize = v ?? '8192'),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Flash Attention
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: flashAttn,
                          decoration: const InputDecoration(labelText: 'Flash Attention (-fa)'),
                          items: const [
                            DropdownMenuItem(value: 'on', child: Text('On (Faster, Less VRAM)')),
                            DropdownMenuItem(value: 'off', child: Text('Off')),
                          ],
                          onChanged: (v) => setDialogState(() => flashAttn = v ?? 'on'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // KV Cache K
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: cacheTypeK,
                          decoration: const InputDecoration(labelText: 'Cache K (-ctk)'),
                          items: const [
                            DropdownMenuItem(value: 'q8_0', child: Text('q8_0 (Balanced)')),
                            DropdownMenuItem(value: 'q4_0', child: Text('q4_0 (Low VRAM)')),
                            DropdownMenuItem(value: 'f16', child: Text('f16 (Full Precision)')),
                          ],
                          onChanged: (v) => setDialogState(() => cacheTypeK = v ?? 'q8_0'),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // KV Cache V
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: cacheTypeV,
                          decoration: const InputDecoration(labelText: 'Cache V (-ctv)'),
                          items: const [
                            DropdownMenuItem(value: 'q8_0', child: Text('q8_0 (Balanced)')),
                            DropdownMenuItem(value: 'q4_0', child: Text('q4_0 (Low VRAM)')),
                            DropdownMenuItem(value: 'f16', child: Text('f16 (Full Precision)')),
                          ],
                          onChanged: (v) => setDialogState(() => cacheTypeV = v ?? 'q8_0'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                if (name.isEmpty) return;

                if (isEditing) {
                  final updated = existing.copyWith(
                    name: name,
                    description: descController.text.trim(),
                    modelPath: selectedModel,
                    mmprojPath: selectedMmproj,
                    nGpuLayers: nGpuLayers,
                    threads: threads,
                    ctxSize: ctxSize,
                    flashAttn: flashAttn,
                    cacheTypeK: cacheTypeK,
                    cacheTypeV: cacheTypeV,
                    parallel: parallel,
                    mlock: mlock,
                  );
                  await widget.profileController.updateProfile(updated);
                } else {
                  final created = ModelProfile.create(
                    name: name,
                    description: descController.text.trim(),
                    modelPath: selectedModel,
                    mmprojPath: selectedMmproj,
                    nGpuLayers: nGpuLayers,
                    threads: threads,
                    ctxSize: ctxSize,
                    flashAttn: flashAttn,
                    cacheTypeK: cacheTypeK,
                    cacheTypeV: cacheTypeV,
                    parallel: parallel,
                    mlock: mlock,
                  );
                  await widget.profileController.createProfile(created);
                }

                if (mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(
                isEditing ? 'Save Changes' : 'Create Profile',
                style: const TextStyle(color: Color(0xFF11111B), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveCurrentConfigDialog() {
    final srv = widget.serverController;
    final nameController = TextEditingController(
      text: srv.config.modelPath.isNotEmpty
          ? 'Tuned ${srv.config.modelFileName}'
          : 'My Server Profile',
    );
    final descController = TextEditingController(
      text: 'Current server configuration preset',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Save Current Server Settings as Profile',
            style: TextStyle(color: AppTheme.textMain, fontSize: 15)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Profile Name *'),
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
                await widget.profileController.createFromCurrentConfig(
                  name: name,
                  description: descController.text.trim(),
                  config: srv.config,
                );
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Profile "$name" saved!')),
                  );
                }
              }
            },
            child: const Text('Save Profile', style: TextStyle(color: Color(0xFF11111B))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profCtrl = widget.profileController;
    final srv = widget.serverController;

    return ListenableBuilder(
      listenable: profCtrl,
      builder: (context, _) {
        final profiles = profCtrl.profiles;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: AppTheme.accent, size: 24),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Model Profiles',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                          Text(
                            'Save and restore fine-tuned GPU offloading and inference configurations',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Save Current Server Config
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: const Icon(Icons.save_as_outlined, size: 16),
                        label: const Text('Save Current Server Config', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showSaveCurrentConfigDialog(),
                      ),
                      const SizedBox(width: 8),

                      // New Profile Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: const Color(0xFF11111B),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _showProfileDialog(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Profiles Grid
              Expanded(
                child: profiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune, size: 48, color: AppTheme.textSubtle),
                            const SizedBox(height: 12),
                            const Text(
                              'No profiles created yet.',
                              style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Create Your First Profile'),
                              onPressed: () => _showProfileDialog(),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 850;
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isWide ? 2 : 1,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: isWide ? 2.6 : 2.2,
                            ),
                            itemCount: profiles.length,
                            itemBuilder: (context, index) {
                              final profile = profiles[index];
                              final isActive = profCtrl.activeProfile?.id == profile.id;

                              return _buildProfileCard(
                                profile: profile,
                                isActive: isActive,
                                srv: srv,
                                profCtrl: profCtrl,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard({
    required ModelProfile profile,
    required bool isActive,
    required ServerController srv,
    required ProfileController profCtrl,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isActive ? AppTheme.accent : AppTheme.border,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Title, Description, Active Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (profile.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'STARTER',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (profile.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          profile.description,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (profile.modelFileName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Model: ${profile.modelFileName}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.accent, fontFamily: 'Consolas'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accent),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: AppTheme.accent),
                        SizedBox(width: 4),
                        Text(
                          'ACTIVE PROFILE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Parameters Badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildParamBadge('GPU Layers: ${profile.nGpuLayers}', AppTheme.accent),
                _buildParamBadge('Ctx: ${profile.ctxSize}', AppTheme.warning),
                _buildParamBadge('Threads: ${profile.threads}', AppTheme.textMuted),
                _buildParamBadge('FlashAttn: ${profile.flashAttn}', AppTheme.cyan),
                _buildParamBadge('Cache: ${profile.cacheTypeK}', AppTheme.textSubtle),
              ],
            ),

            // Bottom Actions
            Row(
              children: [
                // Apply to Server
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF11111B),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Apply to Server', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    profCtrl.applyProfile(profile, srv);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Applied profile "${profile.name}" to server'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    if (widget.onNavigateToTab != null) {
                      widget.onNavigateToTab!(1); // Go to Server tab
                    }
                  },
                ),
                const SizedBox(width: 6),

                // Apply & Start
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.success,
                    side: const BorderSide(color: AppTheme.success),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: const Text('Apply & Start', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    profCtrl.applyProfile(profile, srv);
                    if (widget.onNavigateToTab != null) {
                      widget.onNavigateToTab!(1);
                    }
                    await srv.startServer();
                  },
                ),

                const Spacer(),

                // Duplicate
                IconButton(
                  icon: const Icon(Icons.copy, size: 15, color: AppTheme.textMuted),
                  tooltip: 'Duplicate Profile',
                  onPressed: () => profCtrl.duplicateProfile(profile),
                ),

                // Edit
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.textMuted),
                  tooltip: 'Edit Profile',
                  onPressed: () => _showProfileDialog(existing: profile),
                ),

                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 15, color: AppTheme.danger),
                  tooltip: 'Delete Profile',
                  onPressed: () => profCtrl.deleteProfile(profile.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: 'Consolas',
        ),
      ),
    );
  }
}
