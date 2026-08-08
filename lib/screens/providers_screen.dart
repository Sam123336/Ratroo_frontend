import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/transit_icons.dart';
import '../models/provider.dart';
import '../providers/api_providers.dart';

final providersProvider =
    FutureProvider.autoDispose<ApiResponse<List<TransitProvider>>>((ref) async {
  return ref.watch(transitServiceProvider).getProviders();
});

final providerDetailProvider =
    FutureProvider.autoDispose.family<ApiResponse<TransitProvider>, String>((ref, code) async {
  return ref.watch(transitServiceProvider).getProvider(code);
});

/// Who runs the services, and how much of the network each one accounts for.
class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Operators')),
      body: ref.watch(providersProvider).when(
            data: (response) {
              final providers = response.data ?? const <TransitProvider>[];
              if (providers.isEmpty) {
                return Center(
                  child: Text('No operators recorded.', style: theme.textTheme.bodyMedium),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(RatrooTheme.space4),
                itemCount: providers.length,
                itemBuilder: (context, index) => _ProviderTile(provider: providers[index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(RatrooTheme.space6),
                child: Text('Could not load operators.\n$err',
                    textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              ),
            ),
          ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final TransitProvider provider;

  const _ProviderTile({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: RatrooTheme.space3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: RatrooTheme.space4, vertical: RatrooTheme.space2),
        leading: ModeAvatar(
          category: '${provider.modes.firstOrNull?.toUpperCase() ?? "BUS"}_STOP',
          size: 46,
        ),
        title: Text(provider.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${provider.routeCount} '
          '${provider.routeCount == 1 ? "route" : "routes"} · ${provider.roleLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => context.push('/provider?code=${provider.code}'),
      ),
    );
  }
}

/// One operator in detail. Deliberately has no rating or review count: Ratroo
/// collects neither, and a star next to a real company's name would be an
/// invented claim about it.
class ProviderDetailScreen extends ConsumerWidget {
  final String? code;

  const ProviderDetailScreen({super.key, this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (code == null || code!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operator')),
        body: const Center(child: Text('No operator was selected.')),
      );
    }

    final async = ref.watch(providerDetailProvider(code!));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?.data?.name ?? 'Operator')),
      body: async.when(
        data: (response) {
          final provider = response.data;
          if (provider == null) {
            return Center(child: Text(response.error ?? 'Not found.'));
          }
          return _body(context, theme, provider);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(RatrooTheme.space6),
            child: Text('$err', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData theme, TransitProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(RatrooTheme.space4),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RatrooTheme.space4),
            child: Row(
              children: [
                ModeAvatar(
                  category: '${provider.modes.firstOrNull?.toUpperCase() ?? "BUS"}_STOP',
                  size: 56,
                ),
                const SizedBox(width: RatrooTheme.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(provider.roleLabel, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: RatrooTheme.space4),
        Card(
          child: Column(
            children: [
              _Row(label: 'Routes', value: '${provider.routeCount}'),
              _Row(label: 'Stops', value: '${provider.stopCount}'),
              if (provider.coverage.isNotEmpty)
                _Row(label: 'Coverage', value: provider.coverage.take(4).join(', ')),
              if (provider.lastUpdated != null)
                _Row(label: 'Last updated', value: _date(provider.lastUpdated!)),
              _Row(label: 'Source', value: provider.website ?? 'Not recorded'),
            ],
          ),
        ),
        const SizedBox(height: RatrooTheme.space4),
        if (provider.website != null)
          FilledButton.icon(
            onPressed: () => _open(context, provider.website!),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('Open ${provider.code} website'),
          )
        else
          Text(
            'No official website is recorded for this operator yet, so there is '
            'nothing to link to.',
            style: theme.textTheme.bodyMedium,
          ),
        const SizedBox(height: RatrooTheme.space4),
        Text(
          'Route and stop counts are taken from the data Ratroo holds, not from '
          'the operator. Ratroo does not collect ratings or reviews.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _date(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: RatrooTheme.space4, vertical: RatrooTheme.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(width: RatrooTheme.space4),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}
