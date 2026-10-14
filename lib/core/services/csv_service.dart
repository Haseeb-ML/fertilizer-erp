import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class CsvService {
  /// Converts rows of data to CSV and triggers file sharing/download
  static Future<void> exportAndShareCsv({
    required String fileName,
    required List<List<dynamic>> rows,
  }) async {
    final csvData = const ListToCsvConverter().convert(rows);
    // Prepend UTF-8 BOM [0xEF, 0xBB, 0xBF] so MS Excel recognizes UTF-8 formatting cleanly
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);
    final xFile = XFile.fromData(
      bytes,
      name: fileName,
      mimeType: 'text/csv',
    );

    await Share.shareXFiles([xFile], text: fileName);
  }
}
