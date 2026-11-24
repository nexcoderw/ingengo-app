import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    unawaited(HapticFeedback.selectionClick());
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

  // Loads the next page automatically when the user nears the end of the list.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 240 &&
        _error == null) {
      unawaited(_load(reset: false));
    }
    return false;
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
                      color: AppColors.primary,
                      onRefresh: _refresh,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                                    const SizedBox(height: 24),
                                    _StatusTabs(
                                      selected: _status,
                                      onSelected: _selectStatus,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              sliver: _buildInbox(),
                            ),
                          ],
                        ),
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
            FinancialMessageImportStatus.pending => 'You’re all caught up',
            FinancialMessageImportStatus.confirmed => 'Nothing added yet',
            FinancialMessageImportStatus.dismissed => 'Nothing dismissed',
            FinancialMessageImportStatus.expired => 'Nothing expired',
          },
          detail: _status == FinancialMessageImportStatus.pending
              ? 'New payment messages will show up here.'
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

        return _ListFooter(
          error: error,
          onRetry: () => unawaited(_load(reset: false)),
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
        const SizedBox(height: 4),
        Text(
          'Review before adding to your records.',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// One compact, fully tappable card. It stays quiet by default and only
/// draws attention when the Shortcut needs an update.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.needsUpdate, required this.onPressed});

  final bool needsUpdate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = needsUpdate ? 'Shortcut update available' : 'iPhone Shortcut';
    final subtitle = needsUpdate
        ? 'Update to keep importing messages.'
        : 'Connect your iPhone to import messages.';

    return Material(
      color: needsUpdate
          ? Color.alphaBlend(
              AppColors.primary.withValues(alpha: 0.10),
              AppColors.surface,
            )
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: needsUpdate
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _IconTile(
                  icon: needsUpdate
                      ? Icons.sync_problem_rounded
                      : Icons.phonelink_ring_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (needsUpdate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                    ),
                    child: Text(
                      'Update',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
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

/// Segmented control that replaces the "Inbox" title, message counter and
/// separate chips with a single, easy-to-reach switcher.
class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.onSelected});

  final FinancialMessageImportStatus selected;
  final ValueChanged<FinancialMessageImportStatus> onSelected;

  static const _statuses = [
    FinancialMessageImportStatus.pending,
    FinancialMessageImportStatus.confirmed,
    FinancialMessageImportStatus.dismissed,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const ShapeDecoration(
        color: AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (final status in _statuses)
            Expanded(
              child: _StatusTab(
                label: _inboxStatusLabel(status),
                selected: selected == status,
                textStyle: textTheme.labelLarge,
                onTap: () => onSelected(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: ShapeDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          shape: const StadiumBorder(),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle?.copyWith(
                    color: selected
                        ? AppColors.background
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _IconTile(icon: _sourceIcon(item)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.senderLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _friendlyDate(item.messageReceivedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (amount == null)
                      Text(
                        'Check amount',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          text: _formatAmount(amount),
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: ' RWF',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (needsReview) ...[
                      const SizedBox(height: 6),
                      const _ReviewBadge(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'Check details',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: AppColors.primary, size: 22),
  );
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: error == null
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Column(
                children: [
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry loading more'),
                  ),
                ],
              ),
      ),
    );
  }
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
          for (var index = 0; index < 4; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 44, height: 44, radius: 14),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 80, height: 9),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SkeletonBox(width: 64, height: 12),
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _IconTile(icon: icon),
            const SizedBox(height: 14),
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
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// "Today, 14:05", "Yesterday", "12 Nov" or "12 Nov 2025".
String _friendlyDate(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo == 0) {
    return 'Today, ${_two(local.hour)}:${_two(local.minute)}';
  }
  if (daysAgo == 1) {
    return 'Yesterday';
  }
  final label = '${local.day} ${_months[local.month - 1]}';
  return local.year == now.year ? label : '$label ${local.year}';
}

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
