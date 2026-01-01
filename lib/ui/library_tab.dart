import 'package:dive_prep/cubits/details/details_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../cubits/library/library_cubit.dart';
import '../cubits/library/library_state.dart';
import '../cubits/download/download_cubit.dart';
import '../models/jellyfin_models.dart';
import 'details_screen.dart';

class MediaGrid extends StatelessWidget {
  final List<JellyfinItem> items;
  final Function(JellyfinItem) onTap;

  const MediaGrid({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        String? imgUrl;
        if (authState is AuthAuthenticated) {
          imgUrl = authState.getImageUrl(item.id, item.imageTag);
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTap(item),
            child: GridTile(
              footer: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.indexNumber != null)
                      Text(
                        "Episode ${item.indexNumber}",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
              child: imgUrl != null && imgUrl.isNotEmpty
                  ? Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.movie, size: 50),
                    )
                  : const Icon(Icons.movie, size: 50),
            ),
          ),
        );
      },
    );
  }
}

class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final client = authCubit.getClient();
    if (client == null) return const SizedBox();
    final userId = (authCubit.state as AuthAuthenticated).userId;

    return BlocProvider(
      create: (_) =>
          LibraryCubit(client: client, userId: userId)
            ..fetchItems(includeTypes: 'Movie,Series', sortBy: 'DateCreated'),
      child: const LibraryView(),
    );
  }
}

class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        if (state is LibraryLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is LibraryError) return Center(child: Text(state.msg));
        if (state is LibraryLoaded) {
          if (state.items.isEmpty) {
            return const Center(child: Text("No Items Found"));
          }
          return MediaGrid(
            items: state.items,
            onTap: (item) {
              if (item.type == 'Series') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesSeasonsScreen(series: item),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (context) => DetailsCubit(
                        context.read<AuthCubit>(),
                        context.read<DownloadCubit>(),
                        item.id,
                        item.name,
                      ),
                      child: ItemDetailsScreen(item: item),
                    ),
                  ),
                );
              }
            },
          );
        }
        return const SizedBox();
      },
    );
  }
}

class SeriesSeasonsScreen extends StatelessWidget {
  final JellyfinItem series;
  const SeriesSeasonsScreen({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final client = authCubit.getClient()!;
    final userId = (authCubit.state as AuthAuthenticated).userId;

    return Scaffold(
      appBar: AppBar(title: Text(series.name)),
      body: BlocProvider(
        create: (_) => LibraryCubit(client: client, userId: userId)
          ..fetchItems(
            parentId: series.id,
            includeTypes: 'Season',
            sortBy: 'SortName',
          ),
        child: BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, state) {
            if (state is LibraryLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is LibraryLoaded) {
              return MediaGrid(
                items: state.items,
                onTap: (season) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SeasonEpisodesScreen(
                        season: season,
                        seriesName: series.name,
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}

class SeasonEpisodesScreen extends StatelessWidget {
  final JellyfinItem season;
  final String seriesName;
  const SeasonEpisodesScreen({
    super.key,
    required this.season,
    required this.seriesName,
  });

  void _downloadAll(BuildContext context, List<JellyfinItem> items) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return;

    int count = 0;
    for (var item in items) {
      final ext = item.container ?? "mkv";
      final epNum = item.indexNumber != null
          ? "E${item.indexNumber.toString().padLeft(2, '0')}"
          : "E??";
      final filename = "$seriesName - $epNum - ${item.name}.$ext";

      final url =
          "${authState.serverUrl}/Items/${item.id}/Download?static=true";

      String meta = "";
      if (item.size != null) {
        meta = "size:${item.size}";
      }

      context.read<DownloadCubit>().startDownload(
        url,
        filename,
        authState.accessToken,
        metaData: meta, // <--- Pass metadata here
      );
      count++;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Started $count downloads")));
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final client = authCubit.getClient()!;
    final userId = (authCubit.state as AuthAuthenticated).userId;

    return BlocProvider(
      create: (_) => LibraryCubit(client: client, userId: userId)
        ..fetchItems(
          parentId: season.id,
          includeTypes: 'Episode',
          sortBy: 'IndexNumber',
        ),
      child: Scaffold(
        appBar: AppBar(
          title: Text("$seriesName - ${season.name}"),
          actions: [
            BlocBuilder<LibraryCubit, LibraryState>(
              builder: (context, state) {
                if (state is LibraryLoaded && state.items.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(Icons.download_for_offline),
                    tooltip: "Download Season",
                    onPressed: () => _downloadAll(context, state.items),
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
        body: BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, state) {
            if (state is LibraryLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is LibraryLoaded) {
              return ListView.separated(
                itemCount: state.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final episode = state.items[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text("${episode.indexNumber ?? '#'}"),
                    ),
                    title: Text(episode.name),
                    subtitle: episode.container != null
                        ? Text(
                            episode.container!.toUpperCase(),
                            style: const TextStyle(fontSize: 10),
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider(
                            create: (context) => DetailsCubit(
                              context.read<AuthCubit>(),
                              context.read<DownloadCubit>(),
                              episode.id,
                              episode.name,
                            ),
                            child: ItemDetailsScreen(item: episode),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
