import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/session_history_entry.dart';
import '../state/providers.dart';
import 'error_presentation.dart';

/// The member's own past meditations, newest first.
///
/// Reads finalized session rows only — this screen never touches a live session,
/// so browsing history can't interfere with an event in progress.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const int _pageSize = 50;

  final List<SessionHistoryEntry> _entries = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(historyServiceProvider)
          .myHistory(limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page);
        _exhausted = page.length < _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
      if (isAuthError(e)) ref.read(authServiceProvider).signOut();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(historyServiceProvider)
          .myHistory(limit: _pageSize, offset: _entries.length);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _exhausted = page.length < _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showActionError(ref, context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorRetry(error: _error!, onRetry: _load),
              );
            }
            if (_entries.isEmpty) return const _EmptyHistory();
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length + 2, // summary header + footer
                itemBuilder: (context, index) {
                  if (index == 0) return _Summary(entries: _entries);
                  if (index == _entries.length + 1) return _buildFooter(l10n);
                  return _HistoryTile(entry: _entries[index - 1]);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    if (_exhausted) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _loadingMore
            ? const CircularProgressIndicator()
            : OutlinedButton(
                onPressed: _loadMore,
                child: Text(l10n.historyLoadMore),
              ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.self_improvement,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(l10n.historyEmptyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.historyEmptyBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Running totals across the sessions loaded so far.
class _Summary extends StatelessWidget {
  const _Summary({required this.entries});

  final List<SessionHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final total = entries.fold<Duration>(
      Duration.zero,
      (sum, e) => sum + (e.duration ?? Duration.zero),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              l10n.historySummarySessions(entries.length),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.historySummaryTime(total.inHours, total.inMinutes % 60),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final SessionHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final duration = entry.duration;
    final when = entry.occurredAt.toLocal();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            entry.led ? Icons.record_voice_over : Icons.self_improvement,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(DateFormat.yMMMMd().add_jm().format(when)),
        subtitle: Text(
          duration == null
              ? l10n.historyDurationUnknown
              : l10n.historyDuration(duration.inMinutes),
        ),
        trailing: entry.led
            ? Chip(
                label: Text(l10n.historyLed),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}
