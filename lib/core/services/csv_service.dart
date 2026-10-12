import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvService {
  /// Converts rows of data to CSV and triggers file sharing
  static Future<void> exportAndShareCsv({
    required String fileName,
    required List<List<dynamic>> rows,
  }) async {
    final csvData = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(csvData);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Exported report: $fileName');
  }
}
