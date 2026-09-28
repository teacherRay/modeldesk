import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'services/process_service.dart';
import 'services/llama_client.dart';
import 'services/storage_service.dart';
import 'controllers/server_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/hardware_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/settings_controller.dart';
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

  final hardwareController = HardwareController(
    pidProvider: () => serverController.serverPid,
  );

  final profileController = ProfileController(
    storageService: storageService,
  );

  final settingsController = SettingsController(
    storageService: storageService,
    hardwareController: hardwareController,
  );

  await settingsController.init();

  // Auto-start server if enabled in settings
  if (settingsController.autostartServer && serverController.isStopped) {
    serverController.startServer();
  }

  runApp(LlamaLauncherApp(
    serverController: serverController,
    chatController: chatController,
    hardwareController: hardwareController,
    profileController: profileController,
    settingsController: settingsController,
  ));
}

class LlamaLauncherApp extends StatelessWidget {
  final ServerController serverController;
  final ChatController chatController;
  final HardwareController hardwareController;
  final ProfileController profileController;
  final SettingsController settingsController;

  const LlamaLauncherApp({
    super.key,
    required this.serverController,
    required this.chatController,
    required this.hardwareController,
    required this.profileController,
    required this.settingsController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        serverController,
        chatController,
        hardwareController,
        profileController,
        settingsController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: 'ModelDesk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(settingsController.themeMode),
          home: AppScaffold(
            chatController: chatController,
            serverController: serverController,
            hardwareController: hardwareController,
            profileController: profileController,
            settingsController: settingsController,
          ),
        );
      },
    );
  }
}
