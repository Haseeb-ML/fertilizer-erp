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
    final bytes = Uint8List.fromList(utf8.encode(csvData));
    final xFile = XFile.fromData(
      bytes,
      name: fileName,
      mimeType: 'text/csv',
    );

    await Share.shareXFiles([xFile], text: 'Exported report: $fileName');
  }
}
