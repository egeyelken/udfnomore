import 'dart:io';
import 'dart:convert'; // Import for UTF-8 decoding
import 'package:archive/archive.dart'; // For extracting files
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart'; // For XML parsing

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UDF to PDF Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedFilePath;

  Future<void> pickUdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['udf'],
    );

    if (result != null) {
      selectedFilePath = result.files.single.path;
      setState(() {});
    }
  }

  Future<void> convertToPdf() async {
    if (selectedFilePath == null) return;

    try {
      // Read the UDF file
      final udfFile = File(selectedFilePath!);
      final bytes = await udfFile.readAsBytes();

      // Decode the UDF file as a ZIP archive
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find and extract content.xml
      String? contentXml;
      for (var file in archive.files) {
        if (file.name == 'content.xml') {
          // Decode the content as UTF-8, ensuring proper character handling
          contentXml = utf8.decode(file.content);
          break;
        }
      }

      if (contentXml == null) {
        throw Exception('content.xml not found in the UDF file');
      }

      // Parse the XML content
      final xmlDocument = XmlDocument.parse(contentXml);
      final contentText = xmlDocument.rootElement.text;

      // Load custom font for PDF
      final fontData = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);

      // Generate PDF from the XML content
      final pdf = pw.Document();

      // Split the content into multiple pages
      const pageSize = 800;  // Adjust as needed
      final chunks = _splitText(contentText, pageSize);

      for (final chunk in chunks) {
        pdf.addPage(pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(chunk, style: pw.TextStyle(font: ttf)),
            );
          },
        ));
      }

      // Save PDF
      final outputDir = await getApplicationDocumentsDirectory();
      final outputFile = File('${outputDir.path}/output.pdf');
      await outputFile.writeAsBytes(await pdf.save());

      // Share PDF
      Share.shareFiles([outputFile.path], text: 'Here is your PDF file');
    } catch (e) {
      print('Error during file processing: $e');
    }
  }

  List<String> _splitText(String text, int size) {
    final List<String> chunks = [];
    int startIndex = 0;
    while (startIndex < text.length) {
      int endIndex = startIndex + size;
      if (endIndex > text.length) endIndex = text.length;
      chunks.add(text.substring(startIndex, endIndex));
      startIndex = endIndex;
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('UDF to PDF Converter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickUdfFile,
              child: Text('Pick UDF File'),
            ),
            if (selectedFilePath != null) ...[
              SizedBox(height: 20),
              Text('Selected File: $selectedFilePath'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: convertToPdf,
                child: Text('Convert to PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
