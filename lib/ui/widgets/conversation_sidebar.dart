import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../controllers/chat_controller.dart';

class ConversationSidebar extends StatelessWidget {
  final ChatController chatController;

  const ConversationSidebar({
    super.key,
    required this.chatController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppTheme.bgSidebar,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // Header / New Chat Button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: const Color(0xFF11111B),
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'New Chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: chatController.isGenerating
                  ? null
                  : () => chatController.createNewChat(),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Conversation List
          Expanded(
            child: ListView.builder(
              itemCount: chatController.conversations.length,
              itemBuilder: (context, index) {
                final conv = chatController.conversations[index];
                final isSelected = conv.id == chatController.activeConversation?.id;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Material(
                    color: isSelected ? AppTheme.bgCard : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      hoverColor: AppTheme.bgHover,
                      onTap: () => chatController.selectConversation(conv.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color: isSelected ? AppTheme.accent : AppTheme.textSubtle,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    conv.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? AppTheme.textMain : AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppUtils.formatTimestamp(conv.modifiedAt),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              IconButton(
                                icon: const Icon(Icons.edit, size: 14, color: AppTheme.textSubtle),
                                tooltip: 'Rename',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showRenameDialog(context, conv.id, conv.title),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 14, color: AppTheme.danger),
                                tooltip: 'Delete',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDelete(context, conv.id, conv.title),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String id, String currentTitle) {
    final textController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Rename Conversation', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Conversation title'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: const Color(0xFF11111B),
            ),
            child: const Text('Save'),
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                chatController.renameChat(id, textController.text.trim());
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Conversation?', style: TextStyle(fontSize: 16)),
        content: Text('Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
            onPressed: () {
              chatController.deleteChat(id);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
