import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'services/process_service.dart';
import 'services/llama_client.dart';
import 'services/storage_service.dart';
import 'controllers/server_controller.dart';
import 'controllers/chat_controller.dart';
import 'ui/app_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final processService = ProcessService();
  final llamaClient = LlamaClient();
  final storageService = StorageService();

  await storageService.init();

  final serverController = ServerController(
    processService: processService,
    llamaClient: llamaClient,
    storageService: storageService,
  );

  final chatController = ChatController(
    llamaClient: llamaClient,
    storageService: storageService,
  );

  runApp(LlamaLauncherApp(
    serverController: serverController,
    chatController: chatController,
  ));
}

class LlamaLauncherApp extends StatelessWidget {
  final ServerController serverController;
  final ChatController chatController;

  const LlamaLauncherApp({
    super.key,
    required this.serverController,
    required this.chatController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([serverController, chatController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'ModelDesk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: AppScaffold(
            chatController: chatController,
            serverController: serverController,
          ),
        );
      },
    );
  }
}
