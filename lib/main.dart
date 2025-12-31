import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:logger/logger.dart';

import 'cubits/auth/auth_cubit.dart';
import 'cubits/auth/auth_state.dart';
import 'cubits/download/download_cubit.dart';
import 'services/auth_service.dart';
import 'services/download_service.dart';
import 'ui/login_screen.dart';
import 'ui/main_screen.dart';

Logger logger = Logger(); // init the logger here

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileDownloader().trackTasks();

  final authService = AuthService();
  final downloadService = DownloadService();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(authService)..checkSession()),
        BlocProvider(create: (_) => DownloadCubit(downloadService)),
      ],
      child: const DivePrepApp(),
    ),
  );
}

class DivePrepApp extends StatelessWidget {
  const DivePrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jellyfin Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
      ),
      home: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) return const MainScreen();
          if (state is AuthUnauthenticated || state is AuthError)
            return const LoginScreen();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
