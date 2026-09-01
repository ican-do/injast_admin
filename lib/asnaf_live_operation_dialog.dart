import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Snapshot لحظه‌ای وضعیت عملیات — در هر pulse استریم دوباره خوانده می‌شود.
class AsnafLiveOperationSnapshot {
  const AsnafLiveOperationSnapshot({
    required this.operationStatus,
    required this.currentRecord,
    required this.processedCount,
    required this.failedCount,
    required this.totalCount,
    required this.sessionNewSavedCount,
    required this.sessionSkippedCount,
    required this.sessionDebtZeroSkipped,
    required this.logs,
    required this.progressItems,
    required this.isBusy,
    required this.canResumeRecovery,
    required this.isPaused,
    required this.stopRequested,
    required this.recoveryEndedAllowingSave,
    required this.pendingSendCount,
    required this.draftCount,
  });

  final String operationStatus;
  final String currentRecord;
  final int processedCount;
  final int failedCount;
  final int totalCount;
  final int sessionNewSavedCount;
  final int sessionSkippedCount;
  final int sessionDebtZeroSkipped;
  final List<String> logs;
  final List<AsnafLiveProgressRow> progressItems;
  final bool isBusy;
  final bool canResumeRecovery;
  final bool isPaused;
  final bool stopRequested;
  final bool recoveryEndedAllowingSave;
  final int pendingSendCount;
  final int draftCount;
}

/// دیالوگ نمایش زندهٔ وضعیت و جریان لاگ عملیات اصناف.
class AsnafLiveOperationDialog extends StatelessWidget {
  const AsnafLiveOperationDialog({
    super.key,
    required this.title,
    required this.readSnapshot,
    required this.logScrollController,
    required this.liveUiStream,
    required this.progressScrollController,
    required this.showDebtStats,
    required this.showRecoveryControls,
    required this.onStopFull,
    required this.onPause,
    required this.onResume,
    required this.onShowDraft,
    required this.onSendToServer,
    required this.onClose,
  });

  final String title;
  final AsnafLiveOperationSnapshot Function() readSnapshot;
  final ScrollController logScrollController;
  final Stream<void> liveUiStream;
  final ScrollController progressScrollController;
  final bool showDebtStats;
  final bool showRecoveryControls;
  final VoidCallback? onStopFull;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onShowDraft;
  final VoidCallback? onSendToServer;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: SizedBox(
        width: 720,
        height: (screenH * 0.9).clamp(480.0, 940.0),
        child: StreamBuilder<void>(
          stream: liveUiStream,
          initialData: null,
          builder: (context, _) {
            final s = readSnapshot();
            final done = s.processedCount + s.failedCount;
            final progress = s.totalCount > 0 ? (done / s.totalCount).clamp(0.0, 1.0) : null;
            final remain = s.totalCount > 0 ? (s.totalCount - done).clamp(0, 1 << 30) : 0;

            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (s.isBusy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      IconButton(
                        tooltip: 'کپی لاگ',
                        onPressed: s.logs.isEmpty
                            ? null
                            : () async {
                                final text = s.logs.reversed.join('\n');
                                await Clipboard.setData(ClipboardData(text: text));
                              },
                        icon: const Icon(Icons.copy, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.operationStatus,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('پرونده جاری: ${s.currentRecord}', style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text(
                    s.totalCount > 0
                        ? 'پیشرفت: $done / ${s.totalCount} (مانده: $remain) | خطا: ${s.failedCount}'
                        : 'انجام‌شده: $done | خطا: ${s.failedCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (s.totalCount > 0) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'جریان رویداد (زنده)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    flex: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3A3A3A)),
                      ),
                      child: s.logs.isEmpty
                          ? const Center(
                              child: Text(
                                'در انتظار اولین رویداد…',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              controller: logScrollController,
                              padding: const EdgeInsets.all(10),
                              itemCount: s.logs.length,
                              itemBuilder: (_, i) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: SelectableText(
                                    s.logs[i],
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: Color(0xFFE8E8E8),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'پرونده‌ها (${s.progressItems.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: s.progressItems.isEmpty
                          ? const Center(child: Text('هنوز پرونده‌ای ثبت نشده.', style: TextStyle(fontSize: 12)))
                          : ListView.builder(
                              controller: progressScrollController,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              itemCount: s.progressItems.length,
                              itemBuilder: (_, i) {
                                final it = s.progressItems[i];
                                final icon = it.kind == 'error'
                                    ? Icons.error_outline
                                    : it.kind == 'skip'
                                        ? Icons.skip_next_outlined
                                        : Icons.check_circle_outline;
                                final color = it.kind == 'error'
                                    ? Theme.of(context).colorScheme.error
                                    : it.kind == 'skip'
                                        ? Theme.of(context).colorScheme.outline
                                        : Theme.of(context).colorScheme.primary;
                                return ListTile(
                                  dense: true,
                                  leading: Icon(icon, color: color, size: 20),
                                  title: Text('شناسه ${it.id}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(
                                    it.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  if (showDebtStats || s.sessionNewSavedCount > 0 || s.sessionSkippedCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'این اجرا — جدید: ${s.sessionNewSavedCount} | رد: ${s.sessionSkippedCount}'
                      '${showDebtStats ? ' | بدهی صفر: ${s.sessionDebtZeroSkipped}' : ''}',
                      style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const Divider(height: 14),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (showRecoveryControls) ...[
                        FilledButton.tonal(
                          onPressed: (s.isBusy && !s.stopRequested) ? onStopFull : null,
                          child: const Text('توقف کامل'),
                        ),
                        FilledButton.tonal(
                          onPressed: (s.isBusy && !s.stopRequested && !s.isPaused) ? onPause : null,
                          child: const Text('توقف موقت'),
                        ),
                        FilledButton.tonal(
                          onPressed: ((s.isBusy && s.isPaused) || (!s.isBusy && s.canResumeRecovery)) ? onResume : null,
                          child: Text(s.isBusy && s.isPaused ? 'ادامه' : 'شروع مجدد'),
                        ),
                      ],
                      FilledButton.tonal(
                        onPressed: onShowDraft,
                        child: Text(s.draftCount > 0 ? 'حافظه (${s.draftCount})' : 'حافظه محلی'),
                      ),
                      FilledButton(
                        onPressed: (!s.isBusy && s.recoveryEndedAllowingSave && s.pendingSendCount > 0)
                            ? onSendToServer
                            : null,
                        child: const Text('ذخیره در سرور'),
                      ),
                      TextButton(
                        onPressed: s.isBusy ? null : onClose,
                        child: const Text('بستن'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AsnafLiveProgressRow {
  const AsnafLiveProgressRow({
    required this.id,
    required this.subtitle,
    required this.kind,
  });

  final String id;
  final String subtitle;
  final String kind;
}
