import 'package:flutter/material.dart';

/// وضعیت همگام‌سازی پرونده با سرور اتحادیه.
enum ParvandeSyncStatus {
  /// فقط روی دستگاه؛ هنوز به سرور ارسال نشده.
  local,

  /// با موفقیت در سرور ثبت شده.
  synced,

  /// پس از ارسال، داده دوباره از API گرفته یا ویرایش شده → نیاز به ارسال مجدد.
  dirty,
}

extension ParvandeSyncStatusX on ParvandeSyncStatus {
  String get storageValue => name;

  static ParvandeSyncStatus fromStorage(String? raw) {
    switch (raw?.trim()) {
      case 'synced':
        return ParvandeSyncStatus.synced;
      case 'dirty':
        return ParvandeSyncStatus.dirty;
      default:
        return ParvandeSyncStatus.local;
    }
  }

  String get labelFa => switch (this) {
        ParvandeSyncStatus.local => 'ارسال‌نشده',
        ParvandeSyncStatus.synced => 'ارسال‌شده',
        ParvandeSyncStatus.dirty => 'نیاز به ارسال مجدد',
      };

  /// برچسب کوتاه برای کارت و فیلتر مدیریت پرونده‌ها.
  String get labelFaCard => switch (this) {
        ParvandeSyncStatus.local => 'جدید',
        ParvandeSyncStatus.synced => 'ارسال‌شده',
        ParvandeSyncStatus.dirty => 'بروزرسانی‌شده',
      };

  Color get color => switch (this) {
        ParvandeSyncStatus.local => const Color(0xFF1565C0),
        ParvandeSyncStatus.synced => const Color(0xFF2E7D32),
        ParvandeSyncStatus.dirty => const Color(0xFFE65100),
      };

  Color get backgroundColor => color.withValues(alpha: 0.12);
}

/// فیلتر وضعیت همگام‌سازی در لیست مدیریت پرونده‌ها.
enum ParvandeListSyncFilter {
  all,
  localNew,
  synced,
  dirty,
}

extension ParvandeListSyncFilterX on ParvandeListSyncFilter {
  String get label => switch (this) {
        ParvandeListSyncFilter.all => 'همه',
        ParvandeListSyncFilter.localNew => 'جدید',
        ParvandeListSyncFilter.synced => 'ارسال‌شده',
        ParvandeListSyncFilter.dirty => 'بروزرسانی‌شده',
      };

  ParvandeSyncStatus? get statusOrNull => switch (this) {
        ParvandeListSyncFilter.all => null,
        ParvandeListSyncFilter.localNew => ParvandeSyncStatus.local,
        ParvandeListSyncFilter.synced => ParvandeSyncStatus.synced,
        ParvandeListSyncFilter.dirty => ParvandeSyncStatus.dirty,
      };
}

/// فیلتر لیست حافظهٔ محلی.
enum SyncStatusFilter {
  all,
  pendingSend,
  synced,
  dirty,
}
