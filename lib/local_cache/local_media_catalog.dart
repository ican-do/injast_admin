import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:injast_admin/file_management/media_file_urls.dart';
import 'package:injast_admin/file_management/store_image_logger.dart';
import 'package:injast_admin/local_cache/cached_media_item.dart';
import 'package:injast_admin/local_cache/parvande_local_db.dart';

/// فهرست فایل‌های یک پرونده — محلی و/یا URL سرور.
class LocalMediaCatalog {
  LocalMediaCatalog._();
  static final LocalMediaCatalog instance = LocalMediaCatalog._();

  /// در لیست مدارک نمایش داده نمی‌شوند (پروانه جداگانه دارد).
  static const _skipInDocuments = {'image_parvaneh', 'licence_file'};

  static const _parvandeFieldLabels = {
    'image_profile': 'تصویر پروفایل',
  };

  Future<List<CachedMediaItem>> listForParvandeh({
    required String codeCo,
    required String idParvandeh,
    Map<String, String>? payload,
    bool includeServerUrls = false,
    List<Map<String, dynamic>>? serverDocRows,
  }) async {
    if (kIsWeb) return const [];

    final docMeta = _parseDocsMeta(payload?['_docs_json']);
    final assets =
        await ParvandeLocalDb.instance.listMedia(codeCo, idParvandeh);
    final out = <CachedMediaItem>[];
    final seenKeys = <String>{};

    int docOrder(String key) {
      if (key.startsWith('doc:')) {
        return int.tryParse(key.substring(4)) ?? 999;
      }
      if (key.startsWith('doc_')) return 1000;
      return 0;
    }

    void addItem(CachedMediaItem item) {
      if (_skipInDocuments.contains(item.fieldKey)) return;
      if (seenKeys.contains(item.fieldKey)) return;
      seenKeys.add(item.fieldKey);
      out.add(item);
    }

    final sorted = [...assets]..sort((a, b) {
        final order = {'image_profile': 0};
        final ao = order[a.fieldKey] ?? (100 + docOrder(a.fieldKey));
        final bo = order[b.fieldKey] ?? (100 + docOrder(b.fieldKey));
        return ao.compareTo(bo);
      });

    for (final a in sorted) {
      if (_skipInDocuments.contains(a.fieldKey)) continue;

      final path = a.localPath?.trim() ?? '';
      final existsLocal = path.isNotEmpty && await File(path).exists();
      var urls = MediaFileUrls.mediaUrlCandidates(a.remoteUrl);
      if (urls.isEmpty) {
        urls = MediaFileUrls.mediaUrlCandidates(a.serverUrl);
      }

      if (!existsLocal && !includeServerUrls) continue;

      var label = _parvandeFieldLabels[a.fieldKey];
      String? idDoc;
      if (label == null && a.fieldKey.startsWith('doc')) {
        if (a.fieldKey.startsWith('doc_')) {
          idDoc = a.fieldKey.substring(4);
          label = idDoc.isNotEmpty ? 'سند (شناسه $idDoc)' : 'سند';
        } else if (a.fieldKey.startsWith('doc:')) {
          final idx = int.tryParse(a.fieldKey.substring(4));
          final meta =
              idx != null && idx < docMeta.length ? docMeta[idx] : null;
          idDoc = meta?['id_doc'];
          label = idDoc != null && idDoc.isNotEmpty
              ? 'سند (شناسه $idDoc)'
              : 'سند ${(idx ?? 0) + 1}';
        }
      }
      label ??= a.fieldKey;

      addItem(
        CachedMediaItem(
          fieldKey: a.fieldKey,
          label: label,
          localPath: existsLocal ? path : null,
          networkUrls: urls,
          idDoc: idDoc,
          isOnServerOnly: !existsLocal && urls.isNotEmpty,
        ),
      );
    }

    if (includeServerUrls && payload != null) {
      for (final entry in _parvandeFieldLabels.entries) {
        if (seenKeys.contains(entry.key)) continue;
        final urls = MediaFileUrls.mediaUrlCandidates(payload[entry.key]);
        if (urls.isEmpty) continue;
        logMediaUrl('payload ${entry.key} -> ${urls.join(' | ')}');
        addItem(
          CachedMediaItem(
            fieldKey: entry.key,
            label: entry.value,
            networkUrls: urls,
            isOnServerOnly: true,
          ),
        );
      }

      for (var i = 0; i < docMeta.length; i++) {
        final meta = docMeta[i];
        _addDocFromLink(
          addItem: addItem,
          seenKeys: seenKeys,
          link: _docLinkFromStringMap(meta),
          idDoc: meta['id_doc']?.trim() ?? '',
          index: i,
        );
      }

      if (serverDocRows != null) {
        for (var i = 0; i < serverDocRows.length; i++) {
          final row = serverDocRows[i];
          _addDocFromLink(
            addItem: addItem,
            seenKeys: seenKeys,
            link: _docLinkFromDynamicMap(row),
            idDoc: row['id_doc']?.toString().trim() ?? '',
            index: i,
          );
        }
      }
    }

    out.sort((a, b) {
      final order = {
        'image_profile': 0,
        'store:p1': 3,
        'store:p2': 4,
        'store:p3': 5,
        'store:p4': 6,
      };
      final ao = order[a.fieldKey] ?? (100 + docOrder(a.fieldKey));
      final bo = order[b.fieldKey] ?? (100 + docOrder(b.fieldKey));
      return ao.compareTo(bo);
    });

    return out;
  }

  void _addDocFromLink({
    required void Function(CachedMediaItem item) addItem,
    required Set<String> seenKeys,
    required String link,
    required String idDoc,
    required int index,
  }) {
    if (link.isEmpty || link.toLowerCase() == 'null') return;
    final fieldKey = idDoc.isNotEmpty ? 'doc_$idDoc' : 'doc:$index';
    if (seenKeys.contains(fieldKey)) return;
    final urls = MediaFileUrls.mediaUrlCandidates(link);
    if (urls.isEmpty) return;
    logMediaUrl('doc $fieldKey raw=$link -> ${urls.join(' | ')}');
    addItem(
      CachedMediaItem(
        fieldKey: fieldKey,
        label: idDoc.isNotEmpty ? 'سند (شناسه $idDoc)' : 'سند ${index + 1}',
        networkUrls: urls,
        idDoc: idDoc.isEmpty ? null : idDoc,
        isOnServerOnly: true,
      ),
    );
  }

  List<Map<String, String>> _parseDocsMeta(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final d = jsonDecode(raw);
      if (d is! List) return const [];
      return d
          .whereType<Map>()
          .map(
            (e) => {
              'id_doc': e['id_doc']?.toString() ?? '',
              'link_doc': _docLinkFromDynamicMap(e),
            },
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _docLinkFromStringMap(Map<String, String> row) {
    const keys = [
      'link_doc',
      'file_url',
      'url',
      'link',
      'download_url',
      'href',
      'file_doc',
      'file',
      'file_path',
      'path_doc',
      'path',
      'src',
    ];
    for (final key in keys) {
      final value = row[key]?.trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  String _docLinkFromDynamicMap(Map row) {
    const keys = [
      'link_doc',
      'file_url',
      'url',
      'link',
      'download_url',
      'href',
      'file_doc',
      'file',
      'file_path',
      'path_doc',
      'path',
      'src',
    ];
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }
}
