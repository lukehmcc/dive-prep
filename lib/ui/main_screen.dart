import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/download/download_cubit.dart';
import 'library_tab.dart';
import 'downloads_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _openFolder(BuildContext context) async {
    final result = await context.read<DownloadCubit>().openFolder();
    if (context.mounted) {
      if (result['success'] == true) {
        // Optional: Do nothing if successful, or show "Opened"
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open folder.\nPath: ${result['path']}"),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: "OK", onPressed: () {}),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Library" : "Downloads"),
        actions: [
          if (_selectedIndex == 1)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: "Open Download Folder",
              onPressed: () => _openFolder(context),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [LibraryTab(), DownloadsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: "Library",
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: "Manager",
          ),
        ],
      ),
    );
  }
}
