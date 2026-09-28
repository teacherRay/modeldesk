// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/llama_client.dart';
import '../services/storage_service.dart';

class ChatController extends ChangeNotifier {
  final LlamaClient _llamaClient;
  final StorageService _storageService;
  final _uuid = const Uuid();

  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  bool _isGenerating = false;
  double? _currentTokensPerSec;
  int? _currentTokens;
  StreamSubscription? _chatStreamSub;

  ChatController({
    required LlamaClient llamaClient,
    required StorageService storageService,
  })  : _llamaClient = llamaClient,
        _storageService = storageService {
    _loadConversations();
  }

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get activeConversation => _activeConversation;
  bool get isGenerating => _isGenerating;
  double? get currentTokensPerSec => _currentTokensPerSec;
  int? get currentTokens => _currentTokens;

  Future<void> _loadConversations() async {
    _conversations = await _storageService.loadAllConversations();
    if (_conversations.isNotEmpty) {
      _activeConversation = _conversations.first;
    } else {
      createNewChat();
    }
    notifyListeners();
  }

  void selectConversation(String id) {
    if (_isGenerating) return;
    final found = _conversations.firstWhere(
      (c) => c.id == id,
      orElse: () => _conversations.first,
    );
    _activeConversation = found;
    notifyListeners();
  }

  void createNewChat({String? systemPrompt}) {
    if (_isGenerating) return;
    final newConv = Conversation(
      id: _uuid.v4(),
      title: 'New Chat',
      modelUsed: 'llama.cpp',
      systemPrompt: systemPrompt,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      messages: [],
    );
    _conversations.insert(0, newConv);
    _activeConversation = newConv;
    _storageService.saveConversation(newConv);
    notifyListeners();
  }

  void renameChat(String id, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index != -1) {
      _conversations[index].title = newTitle.trim();
      _conversations[index].modifiedAt = DateTime.now();
      _storageService.saveConversation(_conversations[index]);
      notifyListeners();
    }
  }

  Future<void> deleteChat(String id) async {
    if (_isGenerating) return;
    _conversations.removeWhere((c) => c.id == id);
    await _storageService.deleteConversation(id);

    if (_activeConversation?.id == id) {
      if (_conversations.isNotEmpty) {
        _activeConversation = _conversations.first;
      } else {
        createNewChat();
      }
    }
    notifyListeners();
  }

  Future<void> sendMessage(String text, {required String baseUrl}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    if (_activeConversation == null) {
      createNewChat();
    }

    final conv = _activeConversation!;

    // Auto-title if first user message
    if (conv.messages.isEmpty && conv.title == 'New Chat') {
      final snippet = trimmed.length > 30 ? '${trimmed.substring(0, 30)}...' : trimmed;
      conv.title = snippet.replaceAll('\n', ' ');
    }

    // Add User Message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    );
    conv.messages.add(userMsg);
    conv.modifiedAt = DateTime.now();

    // Prepare Assistant Message Placeholder
    final assistantMsgId = _uuid.v4();
    final assistantMsg = ChatMessage(
      id: assistantMsgId,
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    );
    conv.messages.add(assistantMsg);

    _isGenerating = true;
    _currentTokensPerSec = 0.0;
    _currentTokens = 0;
    notifyListeners();

    try {
      final stream = _llamaClient.streamChatCompletion(
        baseUrl: baseUrl,
        conversationHistory: conv.messages.sublist(0, conv.messages.length - 1),
        systemPrompt: conv.systemPrompt,
      );

      _chatStreamSub = stream.listen(
        (chunk) {
          if (chunk.deltaText.isNotEmpty) {
            assistantMsg.content += chunk.deltaText;
          }
          if (chunk.reasoningDelta != null) {
            assistantMsg.reasoningContent =
                (assistantMsg.reasoningContent ?? '') + chunk.reasoningDelta!;
          }
          if (chunk.tokensPerSec != null) {
            _currentTokensPerSec = chunk.tokensPerSec;
            assistantMsg.tokensPerSecond = chunk.tokensPerSec;
          }
          if (chunk.totalTokens != null) {
            _currentTokens = chunk.totalTokens;
            assistantMsg.totalTokens = chunk.totalTokens;
          }

          notifyListeners();
        },
        onError: (err) {
          assistantMsg.content += '\n[Stream Error]: $err';
          _finishGeneration(conv);
        },
        onDone: () {
          _finishGeneration(conv);
        },
        cancelOnError: true,
      );
    } catch (e) {
      assistantMsg.content += '\n[Error]: $e';
      _finishGeneration(conv);
    }
  }

  void stopGeneration() {
    if (!_isGenerating) return;
    _llamaClient.cancel();
    _chatStreamSub?.cancel();
    _chatStreamSub = null;
    if (_activeConversation != null) {
      _finishGeneration(_activeConversation!);
    }
  }

  void _finishGeneration(Conversation conv) {
    _isGenerating = false;
    _chatStreamSub?.cancel();
    _chatStreamSub = null;
    conv.modifiedAt = DateTime.now();
    _storageService.saveConversation(conv);
    notifyListeners();
  }

  @override
  void dispose() {
    _chatStreamSub?.cancel();
    super.dispose();
  }
}
