import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Constancia Fiscal'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoadFailed: (details) {
          // Si falla la carga, mostramos un mensaje
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar el PDF: ${details.error}')),
          );
        },
      ),
    );
  }
}