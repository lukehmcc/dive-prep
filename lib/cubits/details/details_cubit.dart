import 'package:dive_prep/cubits/auth/auth_cubit.dart';
import 'package:dive_prep/cubits/auth/auth_state.dart';
import 'package:dive_prep/cubits/download/download_cubit.dart';
import 'package:dive_prep/main.dart';
import 'package:dive_prep/models/jellyfin_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'details_state.dart';

class DetailsCubit extends Cubit<DetailsState> {
  AuthCubit authCubit;
  DownloadCubit downloadCubit;
  String id; // widget (item) id
  String name; // widget (item) name
  bool loading = true;
  String? bgTag;
  late QualityProfile selectedQuality;
  final List<QualityProfile> qualities = [
    QualityProfile("1080p High (20 Mbps)", 20000000, width: 1920),
    QualityProfile("1080p Standard (10 Mbps)", 10000000, width: 1920),
    QualityProfile("720p High (6 Mbps)", 6000000, width: 1280),
    QualityProfile("720p Standard (4 Mbps)", 4000000, width: 1280),
    QualityProfile("480p SD (2 Mbps)", 2000000, width: 720),
  ];
  DetailsCubit(this.authCubit, this.downloadCubit, this.id, this.name)
    : super(DetailsInitial()) {
    selectedQuality = qualities[3];
    fetchDetails();
  }

  static DetailsCubit get(context) => BlocProvider.of(context);

  List<MediaSource> sources = [];

  Future<void> fetchDetails() async {
    final client = authCubit.getClient();
    final userId = (authCubit.state as AuthAuthenticated).userId;

    if (client == null) return;

    try {
      final response = await client.get('/Users/$userId/Items/$id');
      final data = response.data;

      final List sourcesJson = data['MediaSources'] ?? [];
      if (data['BackdropImageTags'] != null &&
          (data['BackdropImageTags'] as List).isNotEmpty) {
        bgTag = data['BackdropImageTags'][0];
      }
      sources = sourcesJson.map((s) => MediaSource.fromJson(s)).toList();
      loading = false;
      emit(DetailsLoaded(bgTag));
    } catch (e) {
      logger.e("Error fetching details: $e");
    }
  }

  void startTranscodeDownload() {
    if (sources.isEmpty) return;

    final AuthAuthenticated authState = authCubit.state as AuthAuthenticated;
    final String sourceId = sources.first.id;
    final String baseUrl = "${authState.serverUrl}/Videos/$id/stream.mp4";

    const int audioBitrate = 128000;
    final totalBitrate = selectedQuality.bitrate + audioBitrate;

    int estimatedBytes = 0;

    final query = {
      'container': 'mp4',
      'videoCodec': 'h264',
      'audioCodec': 'aac',
      'videoBitrate': selectedQuality.bitrate.toString(),
      'maxWidth': selectedQuality.width.toString(),
      'audioBitrate': audioBitrate.toString(),
      'mediaSourceId': sourceId,
      'deviceId': 'FlutterDownloader',
      'api_key': authState.accessToken,
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final fileName = "$name - ${selectedQuality.label}.mp4";

    String meta = "";
    if (estimatedBytes > 0) meta = "size:$estimatedBytes|bitrate:$totalBitrate";

    downloadCubit.startDownload(
      uri.toString(),
      fileName,
      authState.accessToken,
      metaData: meta,
    );

    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(SnackBar(content: Text("Transcode Started: $fileName")));
  }

  void startDirectDownload(MediaSource source) {
    final AuthAuthenticated authState = authCubit.state as AuthAuthenticated;
    final String dlUrl =
        "${authState.serverUrl}/Items/$id/Download?mediaSourceId=${source.id}";
    final String fileName = "$name - ${source.name}.${source.container}";

    final String meta = "size:${source.size}";

    downloadCubit.startDownload(
      dlUrl,
      fileName,
      authState.accessToken,
      metaData: meta, // <--- Pass metadata
    );
    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(SnackBar(content: Text("Downloading: $fileName")));
  }
}
