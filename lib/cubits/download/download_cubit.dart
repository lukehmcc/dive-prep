import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../models/jellyfin_models.dart';
import '../../services/download_service.dart';
import 'download_state.dart';

class DownloadCubit extends Cubit<DownloadState> {
  final DownloadService _service;
  
  // Trackers for speed calc
  final Map<String, int> _lastBytes = {};
  final Map<String, int> _lastTime = {};

  DownloadCubit(this._service) : super(const DownloadState(tasks: []));

  Future<void> startDownload(String url, String filename, String token, {String? metaData}) async {
    final taskId = filename.hashCode.toString();
    
    // Parse metadata for size
    int estimatedSize = 0;
    if (metaData != null && metaData.contains('size:')) {
      try {
        final parts = metaData.split('|');
        final sizePart = parts.firstWhere((p) => p.startsWith('size:'));
        estimatedSize = int.parse(sizePart.split(':')[1]);
      } catch (_) {}
    }

    final task = DownloadTask(
      taskId: taskId, 
      url: url, 
      filename: filename, 
      metaData: metaData ?? ""
    );

    // Add to list as Running
    final newTasks = List<TaskRecord>.from(state.tasks);
    newTasks.removeWhere((t) => t.task.taskId == taskId);
    newTasks.insert(0, TaskRecord(task: task, status: TaskStatus.running, progress: 0.0, speed: "Starting.."));
    emit(DownloadState(tasks: newTasks));

    // Check for Resume
    int fileStart = await _service.getFileSize(filename);

    try {
      await _service.downloadFile(
        url: url,
        filename: filename,
        token: token,
        startByte: fileStart,
        onProgress: (received, total) {
           _onProgress(taskId, fileStart + received, estimatedSize);
        }
      );
      _updateStatus(taskId, TaskStatus.complete, 1.0);
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        _updateStatus(taskId, TaskStatus.paused, null);
      } else {
        _updateStatus(taskId, TaskStatus.failed, null);
      }
    }
  }

  void _onProgress(String taskId, int totalReceived, int estimatedTotal) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastT = _lastTime[taskId] ?? 0;
    
    // Throttle speed updates to 1 second
    if (now - lastT > 1000) {
      final lastB = _lastBytes[taskId] ?? 0;
      final bytesDiff = totalReceived - lastB;
      final timeDiff = (now - lastT) / 1000.0;
      String speedStr = "0 MB/s";
      
      if (timeDiff > 0) {
        final mbPerSec = (bytesDiff / timeDiff) / (1024 * 1024);
        speedStr = "${mbPerSec.toStringAsFixed(2)} MB/s";
      }

      _lastBytes[taskId] = totalReceived;
      _lastTime[taskId] = now;
      
      double pct = 0.0;
      if (estimatedTotal > 0) pct = totalReceived / estimatedTotal;
      if (pct > 0.99) pct = 0.99; // Cap until actually complete

      // Update State
      final index = state.tasks.indexWhere((t) => t.task.taskId == taskId);
      if (index != -1) {
        final updatedTasks = List<TaskRecord>.from(state.tasks);
        updatedTasks[index] = updatedTasks[index].copyWith(progress: pct, speed: speedStr);
        emit(DownloadState(tasks: updatedTasks));
      }
    }
  }

  void _updateStatus(String taskId, TaskStatus status, double? finalProgress) {
    final index = state.tasks.indexWhere((t) => t.task.taskId == taskId);
    if (index != -1) {
      final updatedTasks = List<TaskRecord>.from(state.tasks);
      updatedTasks[index] = updatedTasks[index].copyWith(
        status: status, 
        progress: finalProgress
      );
      emit(DownloadState(tasks: updatedTasks));
    }
    _cleanup(taskId);
  }

  void pauseDownload(String taskId) {
    _service.cancelDownload(taskId);
  }

  Future<void> deleteRecord(TaskRecord record) async {
    pauseDownload(record.task.taskId);
    await _service.deleteFile(record.task.filename);
    final updatedTasks = List<TaskRecord>.from(state.tasks);
    updatedTasks.removeWhere((t) => t.task.taskId == record.task.taskId);
    emit(DownloadState(tasks: updatedTasks));
  }

  void _cleanup(String taskId) {
    _lastBytes.remove(taskId);
    _lastTime.remove(taskId);
  }
}
