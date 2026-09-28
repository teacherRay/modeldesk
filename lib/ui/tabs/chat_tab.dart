import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/server_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/conversation_sidebar.dart';

class ChatTab extends StatefulWidget {
  final ChatController chatController;
  final ServerController serverController;

  const ChatTab({
    super.key,
    required this.chatController,
    required this.serverController,
  });

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // If user is more than 80 pixels above bottom, consider scrolled up
    if (maxScroll - currentScroll > 80) {
      if (!_userScrolledUp) {
        setState(() => _userScrolledUp = true);
      }
    } else {
      if (_userScrolledUp) {
        setState(() => _userScrolledUp = false);
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && _userScrolledUp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _promptController.text;
    if (text.trim().isEmpty) return;

    if (!widget.serverController.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server is not running. Please start the server first.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    _promptController.clear();
    _userScrolledUp = false;
    widget.chatController.sendMessage(
      text,
      baseUrl: widget.serverController.config.baseUrl,
    );
    _scrollToBottom(force: true);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final activeConv = widget.chatController.activeConversation;
    final isGenerating = widget.chatController.isGenerating;
    final isServerRunning = widget.serverController.isRunning;

    // Trigger auto-scroll if actively generating and user hasn't scrolled away
    if (isGenerating && !_userScrolledUp) {
      _scrollToBottom();
    }

    return Row(
      children: [
        // Sidebar
        ConversationSidebar(chatController: widget.chatController),

        // Main Chat Area
        Expanded(
          child: Column(
            children: [
              // Server status reminder banner if server is stopped
              if (!isServerRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.danger.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.danger),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'llama-server is currently stopped. Start it to begin chatting.',
                          style: TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: const Color(0xFF11111B),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: widget.serverController.isStarting
                            ? null
                            : () => widget.serverController.startServer(),
                        child: Text(widget.serverController.isStarting ? 'Starting...' : 'Start Server'),
                      ),
                    ],
                  ),
                ),

              // Chat Messages Stream
              Expanded(
                child: Stack(
                  children: [
                    activeConv == null || activeConv.messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(top: 12, bottom: 20),
                            itemCount: activeConv.messages.length,
                            itemBuilder: (context, index) {
                              final msg = activeConv.messages[index];
                              return ChatBubble(message: msg);
                            },
                          ),

                    // Floating Jump to Bottom Button
                    if (_userScrolledUp)
                      Positioned(
                        right: 20,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          backgroundColor: AppTheme.bgCardLight,
                          foregroundColor: AppTheme.accent,
                          tooltip: 'Scroll to bottom',
                          onPressed: () {
                            setState(() => _userScrolledUp = false);
                            _scrollToBottom(force: true);
                          },
                          child: const Icon(Icons.arrow_downward, size: 18),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Input Area
              _buildInputArea(isGenerating, isServerRunning),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text('🦙', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 16),
          const Text(
            'ModelDesk',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Native Local AI Interface by Southern Apps',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isGenerating, bool isServerRunning) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Prompt Input Field
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _handleSend,
              },
              child: TextField(
                controller: _promptController,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: isServerRunning
                      ? 'Type a message... (Enter to send, Shift+Enter for newline)'
                      : 'Server is stopped. Start server to chat...',
                  hintStyle: const TextStyle(color: AppTheme.textSubtle, fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send / Stop Generation Button
          if (isGenerating)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Stop', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => widget.chatController.stopGeneration(),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isServerRunning ? AppTheme.accent : AppTheme.bgHover,
                foregroundColor: isServerRunning ? const Color(0xFF11111B) : AppTheme.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: isServerRunning ? _handleSend : null,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
