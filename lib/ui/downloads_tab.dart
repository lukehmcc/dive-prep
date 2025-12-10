import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file_plus/open_file_plus.dart';
import '../cubits/download/download_cubit.dart';
import '../cubits/download/download_state.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../models/jellyfin_models.dart';
import '../services/download_service.dart';

class DownloadsTab extends StatelessWidget {
  const DownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        if (state.tasks.isEmpty) {
          return const Center(child: Text("No Downloads"));
        }
        return ListView.separated(
          itemCount: state.tasks.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final record = state.tasks[index];
            return ListTile(
              leading: _buildStatusIcon(record.status),
              title: Text(record.task.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (record.status == TaskStatus.running)
                     LinearProgressIndicator(value: record.progress),
                  const SizedBox(height: 4),
                  Text("${record.speed} • ${record.status.name}"),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (record.status == TaskStatus.running)
                     IconButton(
                       icon: const Icon(Icons.pause),
                       onPressed: () => context.read<DownloadCubit>().pauseDownload(record.task.taskId),
                     ),
                   if (record.status == TaskStatus.paused || record.status == TaskStatus.failed)
                     IconButton(
                       icon: const Icon(Icons.play_arrow),
                       onPressed: () {
                         final auth = context.read<AuthCubit>().state as AuthAuthenticated;
                         context.read<DownloadCubit>().startDownload(
                           record.task.url, record.task.filename, auth.accessToken, metaData: record.task.metaData
                         );
                       },
                     ),
                   IconButton(
                     icon: const Icon(Icons.delete),
                     onPressed: () => context.read<DownloadCubit>().deleteRecord(record),
                   )
                ],
              ),
              onTap: record.status == TaskStatus.complete ? () async {
                 final service = DownloadService();
                 final path = await service.getFilePath(record.task.filename);
                 OpenFile.open(path);
              } : null,
            );
          },
        );
      },
    );
  }

  Widget _buildStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.complete: return const Icon(Icons.check_circle, color: Colors.teal);
      case TaskStatus.failed: return const Icon(Icons.error, color: Colors.red);
      case TaskStatus.running: return const Icon(Icons.downloading, color: Colors.blue);
      case TaskStatus.paused: return const Icon(Icons.pause_circle, color: Colors.amber);
      default: return const Icon(Icons.circle_outlined);
    }
  }
}
