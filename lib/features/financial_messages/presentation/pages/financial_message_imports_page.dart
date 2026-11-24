import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../application/financial_message_import_service.dart';
import '../../data/models/financial_message_import.dart';
import '../../data/models/financial_message_pilot_summary.dart';
import '../widgets/financial_message_review_sheet.dart';
import 'iphone_shortcut_setup_page.dart';

class FinancialMessageImportsPage extends StatefulWidget {
  const FinancialMessageImportsPage({super.key, this.service});

  final FinancialMessageImportService? service;

  @override
  State<FinancialMessageImportsPage> createState() =>
      _FinancialMessageImportsPageState();
}

class _FinancialMessageImportsPageState
    extends State<FinancialMessageImportsPage> {
  late final FinancialMessageImportService _service;
  FinancialMessageImportStatus _status = FinancialMessageImportStatus.pending;
  List<FinancialMessageImport> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _changed = false;
  String? _error;
  FinancialMessagePilotSummary? _pilotSummary;
  int _page = 1;
  int _total = 0;
  bool _hasNextPage = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FinancialMessageImportService.createDefault();
    unawaited(_load(reset: true));
    unawaited(_loadPilot());
  }

  Future<void> _loadPilot() async {
    try {
      final summary = await _service.pilotSummary();
      if (!mounted) {
        return;
      }
      setState(() => _pilotSummary = summary);
    } catch (_) {
      // The inbox remains available when connection details cannot be loaded.
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_load(reset: true), _loadPilot()]);
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loading || _loadingMore || !_hasNextPage)) {
      return;
    }
    final generation = reset ? ++_generation : _generation;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
        _loadingMore = false;
        _items = const [];
        _total = 0;
        _hasNextPage = false;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await _service.list(status: _status, page: page);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _items = reset ? result.items : [..._items, ...result.items];
        _page = result.page;
        _total = result.total;
        _hasNextPage = result.hasNextPage;
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(
        () => _error = error is ApiException
            ? error.message
            : 'Could not load imported messages.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _selectStatus(FinancialMessageImportStatus status) {
    if (status == _status) {
      return;
    }
    setState(() => _status = status);
    unawaited(_load(reset: true));
  }

  Future<void> _open(FinancialMessageImport item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FinancialMessageReviewSheet(importId: item.id, service: _service),
    );
    if (!mounted || changed != true) {
      return;
    }
    _changed = true;
    await _refresh();
  }

  void _close() => Navigator.of(context).pop(_changed);

  Future<void> _openSetup() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IphoneShortcutSetupPage(
          currentShortcutVersion: _pilotSummary?.currentShortcutVersion ?? 1,
          shortcutInstallUrl: _pilotSummary?.shortcutInstallUrl,
        ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppBackButton(onBack: _close),
                        IconButton(
                          tooltip: 'Refresh messages',
                          onPressed: _loading
                              ? null
                              : () => unawaited(_refresh()),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size.square(44),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _PageHeading(),
                                  const SizedBox(height: 20),
                                  _ShortcutCard(
                                    needsUpdate:
                                        _pilotSummary?.hasOutdatedShortcuts ??
                                        false,
                                    onPressed: () => unawaited(_openSetup()),
                                  ),
                                  const SizedBox(height: 26),
                                  _InboxHeader(
                                    selected: _status,
                                    total: _loading || _items.isEmpty
                                        ? null
                                        : _total,
                                    onSelected: _selectStatus,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                            sliver: _buildInbox(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInbox() {
    if (_loading) {
      return const SliverToBoxAdapter(child: _LoadingList());
    }
    final error = _error;
    if (_items.isEmpty) {
      if (error != null) {
        return SliverToBoxAdapter(
          child: _InboxState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load messages',
            detail: error,
            action: TextButton.icon(
              onPressed: () => unawaited(_load(reset: true)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        );
      }
      return SliverToBoxAdapter(
        child: _InboxState(
          icon: _status == FinancialMessageImportStatus.confirmed
              ? Icons.inventory_2_outlined
              : Icons.inbox_outlined,
          title: switch (_status) {
            FinancialMessageImportStatus.pending => 'No messages to review',
            FinancialMessageImportStatus.confirmed => 'No added messages',
            FinancialMessageImportStatus.dismissed => 'No dismissed messages',
            FinancialMessageImportStatus.expired => 'No expired messages',
          },
          detail: _status == FinancialMessageImportStatus.pending
              ? 'New messages from your iPhone Shortcut will appear here.'
              : null,
        ),
      );
    }

    return SliverList.separated(
      itemCount: _items.length + (_hasNextPage ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index < _items.length) {
          final item = _items[index];
          return _ImportRow(
            key: ValueKey(item.id),
            item: item,
            onTap: () => unawaited(_open(item)),
          );
        }

        return Column(
          children: [
            if (error != null)
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.danger,
                ),
              ),
            TextButton(
              onPressed: _loadingMore
                  ? null
                  : () => unawaited(_load(reset: false)),
              child: Text(
                _loadingMore
                    ? 'Loading more…'
                    : error == null
                    ? 'Load more'
                    : 'Retry loading more',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Payment messages', style: textTheme.headlineMedium),
        ),
        const SizedBox(height: 6),
        Text(
          'Review imported payment messages before adding them to your records.',
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.needsUpdate, required this.onPressed});

  final bool needsUpdate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.26)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.surface,
            ),
            AppColors.surface,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTile(
                  icon: needsUpdate
                      ? Icons.sync_problem_rounded
                      : Icons.bolt_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        needsUpdate
                            ? 'Shortcut update available'
                            : 'iPhone Shortcut',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        needsUpdate
                            ? 'Update your Shortcut to keep importing payment messages.'
                            : 'Send payment messages to Ingengo using Apple Shortcuts.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(
                needsUpdate
                    ? Icons.system_update_rounded
                    : Icons.phonelink_ring_rounded,
                size: 20,
              ),
              label: Text(
                needsUpdate ? 'Update iPhone Shortcut' : 'Connect my iPhone',
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                iconColor: AppColors.background,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({
    required this.selected,
    required this.total,
    required this.onSelected,
  });

  final FinancialMessageImportStatus selected;
  final int? total;
  final ValueChanged<FinancialMessageImportStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      FinancialMessageImportStatus.pending,
      FinancialMessageImportStatus.confirmed,
      FinancialMessageImportStatus.dismissed,
    ];
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text('Inbox', style: textTheme.titleLarge),
            ),
            if (total != null)
              Text(
                '$total ${total == 1 ? 'message' : 'messages'}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final status in statuses)
              ChoiceChip(
                label: Text(_inboxStatusLabel(status)),
                selected: selected == status,
                onSelected: (_) => onSelected(status),
                showCheckmark: false,
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.primary,
                side: BorderSide(
                  color: selected == status
                      ? AppColors.primary
                      : AppColors.border,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                labelStyle: textTheme.labelLarge?.copyWith(
                  color: selected == status
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
      ],
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({super.key, required this.item, required this.onTap});

  final FinancialMessageImport item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = item.amount;
    final textTheme = Theme.of(context).textTheme;
    final needsReview =
        item.status == FinancialMessageImportStatus.pending &&
        item.needsAttention;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _IconTile(icon: _sourceIcon(item)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.senderLabel, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${item.sourceLabel} · ${_shortDate(item.messageReceivedAt)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            amount == null
                                ? 'Check amount'
                                : '${_formatAmount(amount)} RWF',
                            style: textTheme.labelLarge?.copyWith(
                              color: amount == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (needsReview)
                            Text(
                              'Review details',
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: AppColors.primary, size: 22),
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Loading messages',
    child: ExcludeSemantics(
      child: Column(
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 44, height: 44, radius: 12),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 124, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 92, height: 9),
                        SizedBox(height: 8),
                        SkeletonBox(width: 66, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _InboxState extends StatelessWidget {
  const _InboxState({
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = this.detail;
    final action = this.action;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _IconTile(icon: icon),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatAmount(String value) {
  final whole = value.split('.').first;
  return whole.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

IconData _sourceIcon(FinancialMessageImport item) {
  final source = item.providerCode ?? item.sourceHint;
  if (source.contains('BANK')) {
    return Icons.account_balance_rounded;
  }
  if (source.contains('MOMO') || source.contains('MONEY')) {
    return Icons.account_balance_wallet_rounded;
  }
  return Icons.mark_email_unread_outlined;
}

String _inboxStatusLabel(FinancialMessageImportStatus status) =>
    switch (status) {
      FinancialMessageImportStatus.pending => 'To review',
      FinancialMessageImportStatus.confirmed => 'Added',
      FinancialMessageImportStatus.dismissed => 'Dismissed',
      FinancialMessageImportStatus.expired => 'Expired',
    };
