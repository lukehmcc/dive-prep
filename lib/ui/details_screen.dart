import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../models/jellyfin_models.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../cubits/download/download_cubit.dart';

class ItemDetailsScreen extends StatefulWidget {
  final JellyfinItem item;
  const ItemDetailsScreen({super.key, required this.item});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  bool _loading = true;
  List<MediaSource> _sources = [];
  String? _backdropTag;
  
  final List<QualityProfile> _qualities = [
    QualityProfile("1080p High (20 Mbps)", 20000000, width: 1920),
    QualityProfile("1080p Standard (10 Mbps)", 10000000, width: 1920),
    QualityProfile("720p High (6 Mbps)", 6000000, width: 1280),
    QualityProfile("720p Standard (4 Mbps)", 4000000, width: 1280),
    QualityProfile("480p SD (2 Mbps)", 2000000, width: 720),
  ];
  QualityProfile? _selectedQuality;

  @override
  void initState() {
    super.initState();
    _selectedQuality = _qualities[3];
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final authCubit = context.read<AuthCubit>();
    final client = authCubit.getClient(); 
    final userId = (authCubit.state as AuthAuthenticated).userId;

    if (client == null) return;

    try {
      final response = await client.get('/Users/$userId/Items/${widget.item.id}');
      final data = response.data;
      
      final List sourcesJson = data['MediaSources'] ?? [];
      String? bgTag;
      if (data['BackdropImageTags'] != null && (data['BackdropImageTags'] as List).isNotEmpty) {
        bgTag = data['BackdropImageTags'][0];
      }

      if (mounted) {
        setState(() {
          _sources = sourcesJson.map((s) => MediaSource.fromJson(s)).toList();
          _backdropTag = bgTag;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Error fetching details: $e");
    }
  }

  void _startTranscodeDownload() {
    if (_selectedQuality == null || _sources.isEmpty) return;

    final authState = context.read<AuthCubit>().state as AuthAuthenticated;
    final sourceId = _sources.first.id;
    final baseUrl = "${authState.serverUrl}/Videos/${widget.item.id}/stream.mp4";
    
    const int audioBitrate = 128000;
    final totalBitrate = _selectedQuality!.bitrate + audioBitrate;
    
    int estimatedBytes = 0;
    if (widget.item.runTimeTicks != null) {
      final durationSeconds = widget.item.runTimeTicks! / 10000000;
      estimatedBytes = ((totalBitrate * durationSeconds) / 8).round();
    }

    final query = {
      'container': 'mp4',
      'videoCodec': 'h264',
      'audioCodec': 'aac',
      'videoBitrate': _selectedQuality!.bitrate.toString(),
      'maxWidth': _selectedQuality!.width.toString(),
      'audioBitrate': audioBitrate.toString(),
      'mediaSourceId': sourceId,
      'deviceId': 'FlutterDownloader',
      'api_key': authState.accessToken,
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);
    final fileName = "${widget.item.name} - ${_selectedQuality!.label}.mp4";
    
    String meta = "";
    if (estimatedBytes > 0) meta = "size:$estimatedBytes|bitrate:$totalBitrate";

    context.read<DownloadCubit>().startDownload(
      uri.toString(), 
      fileName, 
      authState.accessToken, 
      metaData: meta
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Transcode Started: $fileName")));
  }

  void _startDirectDownload(MediaSource source) {
    final authState = context.read<AuthCubit>().state as AuthAuthenticated;
    final dlUrl = "${authState.serverUrl}/Items/${widget.item.id}/Download?mediaSourceId=${source.id}";
    final fileName = "${widget.item.name} - ${source.name}.${source.container}";
    
    // FIX IS HERE: Pass size in metadata
    final meta = "size:${source.size}";

    context.read<DownloadCubit>().startDownload(
      dlUrl, 
      fileName, 
      authState.accessToken,
      metaData: meta // <--- Pass metadata
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Downloading: $fileName")));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state as AuthAuthenticated;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(widget.item.name),
            flexibleSpace: _backdropTag != null 
              ? FlexibleSpaceBar(
                  background: Image.network(
                    authState.getImageUrl(widget.item.id, _backdropTag, type: "Backdrop"),
                    fit: BoxFit.cover,
                    color: Colors.black45,
                    colorBlendMode: BlendMode.darken,
                  ),
                )
              : null,
          ),
          
          if (_loading) 
             const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Theme.of(context).colorScheme.surfaceContainerHighest,
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Row(children: [Icon(Icons.tune), SizedBox(width: 8), Text("Custom Quality Download")]),
                           const SizedBox(height: 12),
                           DropdownButtonFormField<QualityProfile>(
                             value: _selectedQuality,
                             decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                             items: _qualities.map((q) => DropdownMenuItem(value: q, child: Text(q.label))).toList(),
                             onChanged: (val) => setState(() => _selectedQuality = val),
                           ),
                           const SizedBox(height: 12),
                           SizedBox(
                             width: double.infinity,
                             child: FilledButton.icon(
                               onPressed: _startTranscodeDownload,
                               icon: const Icon(Icons.download),
                               label: const Text("Download Custom Version"),
                             ),
                           )
                         ],
                       ),
                     ),
                     const SizedBox(height: 24),
                     Text("Original Files", style: Theme.of(context).textTheme.titleLarge),
                     const SizedBox(height: 8),
                   ],
                 ),
               ),
             ),

          if (!_loading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final source = _sources[index];
                  return ListTile(
                    leading: const Icon(Icons.file_present),
                    title: Text(source.name),
                    subtitle: Text("${source.container.toUpperCase()} • ${source.formattedSize}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => _startDirectDownload(source),
                    ),
                  );
                },
                childCount: _sources.length,
              ),
            ),
            
           const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }
}
