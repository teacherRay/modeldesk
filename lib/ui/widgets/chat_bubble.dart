import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/chat_message.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _thinkingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    if (msg.isUser) {
      return _buildUserBubble(context, msg);
    } else {
      return _buildAssistantBubble(context, msg);
    }
  }

  Widget _buildUserBubble(BuildContext context, ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: AppTheme.bgInput,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SelectableText(
                    msg.content,
                    style: const TextStyle(
                      color: AppTheme.textMain,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppUtils.formatTimestamp(msg.timestamp),
                    style: const TextStyle(
                      color: AppTheme.textSubtle,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.accent,
            child: Icon(Icons.person, size: 18, color: Color(0xFF11111B)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context, ChatMessage msg) {
    final hasReasoning = msg.reasoningContent != null && msg.reasoningContent!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.bgCardLight,
            child: Text(
              '🦙',
              style: TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collapsible Thinking / Reasoning Section
                  if (hasReasoning) ...[
                    InkWell(
                      onTap: () => setState(() => _thinkingExpanded = !_thinkingExpanded),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _thinkingExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Thinking Process',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_thinkingExpanded) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSidebar,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SelectableText(
                          msg.reasoningContent!,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],

                  // Markdown Content or loading indicator
                  if (msg.content.isEmpty && !hasReasoning)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Thinking...',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: AppTheme.textMain, fontSize: 14, height: 1.45),
                        code: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 13,
                          color: AppTheme.cyan,
                          backgroundColor: Color(0xFF181825),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF181825),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: AppTheme.bgCardLight,
                          border: const Border(
                            left: BorderSide(color: AppTheme.accent, width: 4),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Footer: Stats & Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Token speed and stats
                      if (msg.tokensPerSecond != null && msg.tokensPerSecond! > 0)
                        Text(
                          '⚡ ${msg.tokensPerSecond!.toStringAsFixed(1)} tok/s'
                          '${msg.totalTokens != null ? ' • ${msg.totalTokens} tokens' : ''}',
                          style: const TextStyle(
                            color: AppTheme.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSubtle),
                            tooltip: 'Copy Message',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: msg.content));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Message copied to clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppUtils.formatTimestamp(msg.timestamp),
                            style: const TextStyle(
                              color: AppTheme.textSubtle,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
