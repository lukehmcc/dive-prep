import 'package:dive_prep/cubits/details/details_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/jellyfin_models.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';

class ItemDetailsScreen extends StatefulWidget {
  final JellyfinItem item;
  const ItemDetailsScreen({super.key, required this.item});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final AuthAuthenticated authState =
        context.read<AuthCubit>().state as AuthAuthenticated;
    final DetailsCubit detailsCubit = context.read<DetailsCubit>();

    return BlocBuilder<DetailsCubit, DetailsState>(
      builder: (context, state) => Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(widget.item.name),
              flexibleSpace: detailsCubit.bgTag != null
                  ? FlexibleSpaceBar(
                      background: Image.network(
                        authState.getImageUrl(
                          widget.item.id,
                          detailsCubit.bgTag,
                          type: "Backdrop",
                        ),
                        fit: BoxFit.cover,
                        color: Colors.black45,
                        colorBlendMode: BlendMode.darken,
                      ),
                    )
                  : null,
            ),

            if (detailsCubit.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
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
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tune),
                                SizedBox(width: 8),
                                Text("Custom Quality Download"),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<QualityProfile>(
                              value: detailsCubit.selectedQuality,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: detailsCubit.qualities
                                  .map(
                                    (q) => DropdownMenuItem(
                                      value: q,
                                      child: Text(q.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(
                                    () => detailsCubit.selectedQuality = val,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: detailsCubit.startTranscodeDownload,
                                icon: const Icon(Icons.download),
                                label: const Text("Download Custom Version"),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Original Files",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

            if (!detailsCubit.loading)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final source = detailsCubit.sources[index];
                  return ListTile(
                    leading: const Icon(Icons.file_present),
                    title: Text(source.name),
                    subtitle: Text(
                      "${source.container.toUpperCase()} • ${source.formattedSize}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => detailsCubit.startDirectDownload(source),
                    ),
                  );
                }, childCount: detailsCubit.sources.length),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        ),
      ),
    );
  }
}
