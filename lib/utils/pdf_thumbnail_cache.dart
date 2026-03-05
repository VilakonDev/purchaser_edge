import 'dart:typed_data';

/// Cache กลางสำหรับเก็บ thumbnail images ใช้ร่วมกันระหว่าง
/// PdfViewerScreen และ ReviewScreen เพื่อไม่ต้อง render ซ้ำ
final Map<String, Uint8List> pdfThumbnailCache = {};