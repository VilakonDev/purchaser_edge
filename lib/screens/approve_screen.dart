import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:purchaser_edge/screens/pdf_viewer_screen.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/utils/pdf_thumbnail_cache.dart';
import 'package:unicons/unicons.dart';

// Base URL ของ server — ปรับตามจริง
const String _kBaseUrl = 'http://localhost:5000';

class ApproveScreen extends StatefulWidget {
  /// โหมด 1: เปิดจาก PdfViewerScreen (ส่ง documentData มา)
  final ReviewDocumentData? documentData;

  /// โหมด 2: เปิดจาก AllDocumentScreen (ส่ง fileName + documentId มา)
  final String? fileName; // ชื่อไฟล์ที่ server เก็บ เช่น "report_1234.pdf"
  final String? documentId; // id เอกสาร ใช้สำหรับ approve API

  const ApproveScreen({
    super.key,
    this.documentData,
    this.fileName,
    this.documentId,
  }) : assert(
         documentData != null || fileName != null,
         'ต้องส่ง documentData หรือ fileName อย่างใดอย่างหนึ่ง',
       );

  @override
  State<ApproveScreen> createState() => _ApproveScreenState();
}

class _ApproveScreenState extends State<ApproveScreen> {
  List<PageInfo> pages = [];
  Map<int, int> pageRotations = {};
  Map<int, List<SignatureInfo>> pageSignatures = {};
  int? selectedPageIndex;
  final Map<String, Size> _pageSizeCache = {};

  // สถานะ loading ไฟล์จาก URL
  bool _isLoadingFile = false;
  String? _loadError;
  String? _downloadedFilePath; // path temp ที่ download มาเก็บ

  // ─── โหมด ───────────────────────────────────────────────────────────────
  bool get _isApproveMode => widget.fileName != null;

  @override
  void initState() {
    super.initState();
    if (_isApproveMode) {
      _downloadAndLoadFile();
    } else {
      _initFromDocumentData();
    }
  }

  // ── โหมด 1: โหลดจาก documentData ────────────────────────────────────────
  void _initFromDocumentData() {
    final data = widget.documentData!;
    pages = List.from(data.pages);
    pageRotations = Map.from(data.pageRotations);
    pageSignatures = {};
    data.pageSignatures.forEach((key, sigs) {
      pageSignatures[key] = sigs
          .map(
            (s) => SignatureInfo(
              imageBytes: Uint8List.fromList(s.imageBytes),
              left: s.left,
              top: s.top,
              width: s.width,
              height: s.height,
              pageIndex: s.pageIndex,
            ),
          )
          .toList();
    });
  }

  // ── โหมด 2: Download จาก URL แล้วสร้าง pages ───────────────────────────
  Future<void> _downloadAndLoadFile() async {
    setState(() {
      _isLoadingFile = true;
      _loadError = null;
    });

    try {
      final url = '$_kBaseUrl/uploads/${widget.fileName}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
          'ດາວໂຫຼດບໍ່ສຳເລັດ: ${response.statusCode} ${widget.fileName}',
        );
      }

      // บันทึกไฟล์ temp
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/review_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(response.bodyBytes);
      _downloadedFilePath = tempPath;

      // อ่านจำนวนหน้า
      final doc = PdfDocument(inputBytes: response.bodyBytes);
      final pageCount = doc.pages.count;
      doc.dispose();

      // สร้าง pages
      final List<PageInfo> loadedPages = List.generate(
        pageCount,
        (i) => PageInfo(
          filePath: tempPath,
          fileName: widget.fileName!,
          pageNumber: i + 1,
          totalPages: pageCount,
        ),
      );

      if (mounted) {
        setState(() {
          pages = loadedPages;
          pageRotations = {};
          pageSignatures = {};
          _isLoadingFile = false;
        });
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() {
          _isLoadingFile = false;
          _loadError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _pageSizeCache.clear();
    // ลบ temp file ที่ download มา
    if (_downloadedFilePath != null) {
      File(_downloadedFilePath!).deleteSync(recursive: true);
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pick + attach signature image to selectedPageIndex
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickSignature() async {
    if (selectedPageIndex == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null || result.files.single.path == null) return;

    final bytes = await File(result.files.single.path!).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 800);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final compressedBytes = byteData!.buffer.asUint8List();
    double aspectRatio = image.width / image.height;

    if (!mounted) return;

    final pageInfo = pages[selectedPageIndex!];
    final originalSize = await _getPageSizeCached(
      pageInfo.filePath,
      pageInfo.pageNumber,
    );
    final rotation = pageRotations[selectedPageIndex!] ?? 0;

    Size rotatedSize = originalSize;
    if (rotation == 90 || rotation == 270) {
      rotatedSize = Size(originalSize.height, originalSize.width);
    }

    double signatureWidthRatio = 3.0 / 21.0;
    if (rotatedSize.width > rotatedSize.height) {
      signatureWidthRatio = 3.0 / 29.7;
    }
    double sigWidth = signatureWidthRatio;
    double sigHeight = sigWidth / aspectRatio;

    setState(() {
      if (!pageSignatures.containsKey(selectedPageIndex!)) {
        pageSignatures[selectedPageIndex!] = [];
      }
      pageSignatures[selectedPageIndex!]!.add(
        SignatureInfo(
          imageBytes: compressedBytes,
          left: 0.05,
          top: 0.85,
          width: sigWidth,
          height: sigHeight,
          pageIndex: selectedPageIndex!,
        ),
      );
    });

    image.dispose();
  }

  Future<Size> _getPageSizeCached(String filePath, int pageNumber) async {
    final key = '${filePath}_$pageNumber';
    if (_pageSizeCache.containsKey(key)) return _pageSizeCache[key]!;
    final bytes = await File(filePath).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final size = doc.pages[pageNumber - 1].size;
    doc.dispose();
    _pageSizeCache[key] = size;
    return size;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Merge ทุกหน้า (rotation + signature) ออกมาเป็น Uint8List
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List> _buildMergedPdf() async {
    List<Uint8List> pageBytesList = [];

    for (int i = 0; i < pages.length; i++) {
      final pageInfo = pages[i];
      final bytes = await File(pageInfo.filePath).readAsBytes();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      final sourcePage = loadedDoc.pages[pageInfo.pageNumber - 1];
      final Size orig = sourcePage.size;
      final int rot = pageRotations[i] ?? 0;

      final bool needsSwap = rot == 90 || rot == 270;
      final double rW = needsSwap ? orig.height : orig.width;
      final double rH = needsSwap ? orig.width : orig.height;

      final PdfDocument singleDoc = PdfDocument();
      singleDoc.pageSettings.margins.all = 0;
      singleDoc.pageSettings.size = Size(rW, rH);
      singleDoc.pageSettings.orientation = rW > rH
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      final PdfPage newPage = singleDoc.pages.add();
      final Size a = newPage.size;
      final PdfTemplate tmpl = sourcePage.createTemplate();
      newPage.graphics.save();

      switch (rot) {
        case 0:
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
        case 90:
          newPage.graphics.translateTransform(a.width, 0);
          newPage.graphics.rotateTransform(90);
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
        case 180:
          newPage.graphics.translateTransform(a.width, a.height);
          newPage.graphics.rotateTransform(180);
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
        case 270:
          newPage.graphics.translateTransform(0, a.height);
          newPage.graphics.rotateTransform(-90);
          newPage.graphics.drawPdfTemplate(tmpl, Offset.zero, orig);
          break;
      }
      newPage.graphics.restore();

      if (pageSignatures.containsKey(i)) {
        for (final SignatureInfo sig in pageSignatures[i]!) {
          final bool wasFlipped = (a.width - rW).abs() > 1.0;
          double sl, st, sw, sh;
          if (!wasFlipped) {
            sl = sig.left * a.width;
            st = sig.top * a.height;
            sw = sig.width * a.width;
            sh = sig.height * a.height;
          } else {
            sl = sig.top * a.width;
            st = sig.left * a.height;
            sw = sig.height * a.width;
            sh = sig.width * a.height;
          }
          final PdfBitmap bmp = PdfBitmap(sig.imageBytes);
          newPage.graphics.drawImage(bmp, Rect.fromLTWH(sl, st, sw, sh));
        }
      }

      final singleBytes = await singleDoc.save();
      pageBytesList.add(Uint8List.fromList(singleBytes));
      singleDoc.dispose();
      loadedDoc.dispose();
    }

    if (pageBytesList.isEmpty) return Uint8List(0);
    if (pageBytesList.length == 1) return pageBytesList.first;

    final PdfDocument mergedDoc = PdfDocument();
    for (int i = 0; i < pageBytesList.length; i++) {
      final PdfDocument srcDoc = PdfDocument(inputBytes: pageBytesList[i]);
      final PdfPage srcPage = srcDoc.pages[0];
      final Size srcSize = srcPage.size;

      mergedDoc.pageSettings.margins.all = 0;
      mergedDoc.pageSettings.size = srcSize;
      mergedDoc.pageSettings.orientation = srcSize.width > srcSize.height
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      final PdfPage destPage = mergedDoc.pages.add();
      final Size da = destPage.size;
      final PdfTemplate srcTmpl = srcPage.createTemplate();

      if ((da.width - srcSize.width).abs() < 1.0) {
        destPage.graphics.drawPdfTemplate(srcTmpl, Offset.zero, srcSize);
      } else {
        destPage.graphics.save();
        destPage.graphics.translateTransform(da.width, 0);
        destPage.graphics.rotateTransform(90);
        destPage.graphics.drawPdfTemplate(srcTmpl, Offset.zero, srcSize);
        destPage.graphics.restore();
      }
      srcDoc.dispose();
    }

    final List<int> mergedBytes = await mergedDoc.save();
    mergedDoc.dispose();
    return Uint8List.fromList(mergedBytes);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit: แยกตาม mode
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onSubmit() async {
    if (_isApproveMode) {
      context.read<AuthProvider>().currentUser!.role == "DISTRICT_MANAGER"
          ? await _approveDocumentByDM()
          : context.read<AuthProvider>().currentUser!.role == "DIRECTOR"
          ? await _approveDocumentByDirector()
          : setState(() {});
    } else {
      await _uploadDocument();
    }
  }

  // ── โหมด 2: Approve — upload PDF ที่ signed แล้ว ────────────────────────
  Future<void> _approveDocumentByDM() async {
    _showLoadingDialog('ກຳລັງ Approve ເອກະສານ...');
    try {
      final pdfBytes = await _buildMergedPdf();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/approved_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);

      final uri = Uri.parse(
        'http://localhost:5000/documents/dmApprove/${widget.documentId}',
      );

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          tempFile.path,
          filename: widget.fileName ?? 'approved.pdf',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      await tempFile.delete();

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        _showSuccessDialog('Approve ເອກະສານສຳເລັດ!', popCount: 1);
      } else {
        _showErrorDialog(
          'ເກີດຂໍ້ຜິດພາດ: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) _showErrorDialog('ບໍ່ສາມາດເຊື່ອມຕໍ່ Server ໄດ້\n$e');
    }
  }

  Future<void> _approveDocumentByDirector() async {
    _showLoadingDialog('ກຳລັງ Approve ເອກະສານ...');
    try {
      final pdfBytes = await _buildMergedPdf();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/approved_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);

      final uri = Uri.parse(
        'http://localhost:5000/documents/directorApprove/${widget.documentId}',
      );

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          tempFile.path,
          filename: widget.fileName ?? 'approved.pdf',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      await tempFile.delete();

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        _showSuccessDialog('Approve ເອກະສານສຳເລັດ!', popCount: 1);
      } else {
        print('ເກີດຂໍ້ຜິດພາດ: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) _showErrorDialog('ບໍ່ສາມາດເຊື່ອມຕໍ່ Server ໄດ້\n$e');
    }
  }

  // ── โหมด 1: Upload ปกติ ─────────────────────────────────────────────────
  Future<void> _uploadDocument() async {
    _showLoadingDialog('ກຳລັງສົ່ງເອກະສານ...');
    try {
      final pdfBytes = await _buildMergedPdf();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);

      final uri = Uri.parse('$_kBaseUrl/documents/upload');
      final request = http.MultipartRequest('POST', uri);

      final docProvider = context.read<DocumentProvider>();
      request.fields['document_number'] = docProvider.documentNumber ?? '';
      request.fields['document_title'] = docProvider.documentTitle ?? '';
      request.fields['branch'] = docProvider.branch ?? '';
      request.fields['category'] = docProvider.documentCategory ?? '';
      request.fields['status'] = 'pending';
      request.fields['created_by'] = docProvider.createBy ?? '';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          tempFile.path,
          filename:
              '${docProvider.documentTitle?.replaceAll(' ', '_') ?? 'document'}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      await tempFile.delete();

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        if (context.mounted) {
          docProvider.resetDocumentInfo();
          _showSuccessDialog('ສົ່ງເອກະສານສຳເລັດ!', popCount: 2);
        }
      } else {
        if (context.mounted) {
          _showErrorDialog(
            'ເກີດຂໍ້ຜິດພາດ: ${response.statusCode}\n${response.body}',
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) _showErrorDialog('ບໍ່ສາມາດເຊື່ອມຕໍ່ Server ໄດ້\n$e');
    }
  }

  // ── Dialog helpers ────────────────────────────────────────────────────────
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  message,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String message, {required int popCount}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: Colors.green, size: 36),
              ),
              SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    for (int i = 0; i < popCount; i++) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    'ກັບສູ່ໜ້າຫຼັກ',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: Colors.red, size: 36),
              ),
              SizedBox(height: 16),
              Text(
                'ເກີດຂໍ້ຜິດພາດ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: Text(
                    'ປິດ',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading state (download from URL) ────────────────────────────────
    if (_isLoadingFile) {
      return Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'ກຳລັງດາວໂຫຼດເອກະສານ...',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Error state ───────────────────────────────────────────────────────
    if (_loadError != null) {
      return Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'ບໍ່ສາມາດໂຫຼດເອກະສານໄດ້',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _downloadAndLoadFile,
                      icon: Icon(Icons.refresh),
                      label: Text('ລອງໃໝ່'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Main UI ───────────────────────────────────────────────────────────
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: pages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'ບໍ່ມີເອກະສານສຳລັບກວດສອບ',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      _buildThumbnailStrip(),
                      Expanded(child: _buildPreviewArea()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final title = _isApproveMode
        ? 'ກວດສອບ ແລະ Approve ເອກະສານ'
        : 'ກວດສອບ ແລະ ເຊັນເອກະສານ';
    final submitLabel = _isApproveMode ? 'Approve' : 'ສົ່ງເອກະສານ';

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(gradient: ColorService().mainGredientColor),
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                spacing: 10,
                children: [
                  Icon(UniconsLine.arrow_left),
                  Text(
                    'ກັບຄືນ',
                    style: TextStyle(color: ColorService().mainTextColor),
                  ),
                ],
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            spacing: 10,
            children: [
              if (selectedPageIndex != null)
                GestureDetector(
                  onTap: _pickSignature,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Text(
                          'ເພີ່ມລາຍເຊັນ',
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(Icons.edit_road, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                onTap: pages.isEmpty || _isLoadingFile ? null : _onSubmit,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  height: 40,
                  decoration: BoxDecoration(
                    color: pages.isEmpty || _isLoadingFile
                        ? Colors.grey.shade300
                        : (_isApproveMode
                              ? Colors.orange.shade400
                              : ColorService().successColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    spacing: 10,
                    children: [
                      Text(submitLabel, style: TextStyle(color: Colors.white)),
                      Icon(
                        _isApproveMode
                            ? Icons.check_circle_outline
                            : UniconsLine.sign_out_alt,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Thumbnail strip ───────────────────────────────────────────────────────
  Widget _buildThumbnailStrip() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.view_module, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'ທຸກໜ້າ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final pageInfo = pages[index];
                final bool isSelected = selectedPageIndex == index;
                final bool hasSignature =
                    pageSignatures.containsKey(index) &&
                    pageSignatures[index]!.isNotEmpty;

                return GestureDetector(
                  onTap: () => setState(() => selectedPageIndex = index),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (hasSignature)
                          Padding(
                            padding: EdgeInsets.only(top: 6, right: 6),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      '${pageSignatures[index]!.length}',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: OptimizedPdfThumbnail(
                            filePath: pageInfo.filePath,
                            pageNumber: pageInfo.pageNumber,
                            rotation: pageRotations[index] ?? 0,
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(7),
                            ),
                          ),
                          child: Text(
                            'ໜ້າ ${index + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview area ──────────────────────────────────────────────────────────
  Widget _buildPreviewArea() {
    return Container(
      color: Colors.grey.shade200,
      child: selectedPageIndex == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 80, color: Colors.grey.shade400),
                  SizedBox(height: 16),
                  Text(
                    'ກົດເລືອກໜ້າຈາກດ້ານຊ້າຍ\nເພື່ອກວດສອບ ຫຼື ເພີ່ມລາຍເຊັນ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            )
          : _buildInteractivePreview(selectedPageIndex!),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Interactive preview (editable signatures) for selected page
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInteractivePreview(int pageIdx) {
    final pageInfo = pages[pageIdx];
    final rotation = pageRotations[pageIdx] ?? 0;
    final sigs = pageSignatures[pageIdx] ?? [];

    return FutureBuilder<Size>(
      future: _getPageSizeCached(pageInfo.filePath, pageInfo.pageNumber),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        Size pageSize = snapshot.data!;
        double finalWidth = pageSize.width;
        double finalHeight = pageSize.height;
        if (rotation == 90 || rotation == 270) {
          finalWidth = pageSize.height;
          finalHeight = pageSize.width;
        }
        double aspectRatio = finalWidth / finalHeight;

        return Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.blue, width: 3),
              ),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        // PDF page render
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: finalWidth,
                              height: finalHeight,
                              child: _ReviewPdfPageImage(
                                filePath: pageInfo.filePath,
                                pageNumber: pageInfo.pageNumber,
                                rotation: rotation,
                              ),
                            ),
                          ),
                        ),
                        // Draggable/resizable signatures
                        ...sigs.asMap().entries.map((entry) {
                          final sigIndex = entry.key;
                          final sig = entry.value;
                          return SignatureOverlay(
                            signature: sig,
                            rotation: rotation,
                            onUpdate: (updated) {
                              setState(() {
                                pageSignatures[pageIdx]![sigIndex] = updated;
                              });
                            },
                            onDelete: () {
                              setState(() {
                                pageSignatures[pageIdx]!.removeAt(sigIndex);
                                if (pageSignatures[pageIdx]!.isEmpty) {
                                  pageSignatures.remove(pageIdx);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReviewPdfPageImage  (render PNG ด้วย pdfrx)
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewPdfPageImage extends StatefulWidget {
  final String filePath;
  final int pageNumber;
  final int rotation;

  const _ReviewPdfPageImage({
    required this.filePath,
    required this.pageNumber,
    required this.rotation,
  });

  @override
  State<_ReviewPdfPageImage> createState() => _ReviewPdfPageImageState();
}

class _ReviewPdfPageImageState extends State<_ReviewPdfPageImage> {
  Uint8List? _bytes;
  bool _isLoading = true;

  String get _cacheKey =>
      'review_hq_${widget.filePath}_${widget.pageNumber}_${widget.rotation}';

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(_ReviewPdfPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.rotation != widget.rotation) {
      _render();
    }
  }

  Future<void> _render() async {
    if (!mounted) return;

    if (pdfThumbnailCache.containsKey(_cacheKey)) {
      if (mounted) {
        setState(() {
          _bytes = pdfThumbnailCache[_cacheKey];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final document = await pdfrx.PdfDocument.openFile(widget.filePath);
      final page = document.pages[widget.pageNumber - 1];

      const double dpi = 150.0;
      final double scale = dpi / 72.0;
      final int imgW = (page.width * scale).round();
      final int imgH = (page.height * scale).round();

      final pdfrx.PdfImage? pageImage = await page.render(
        fullWidth: imgW.toDouble(),
        fullHeight: imgH.toDouble(),
      );
      document.dispose();

      if (pageImage == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final buffer = await ui.ImmutableBuffer.fromUint8List(pageImage.pixels);
      final descriptor = await ui.ImageDescriptor.raw(
        buffer,
        width: pageImage.width,
        height: pageImage.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frameInfo = await codec.getNextFrame();
      final byteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frameInfo.image.dispose();

      if (byteData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      if (widget.rotation != 0) {
        pngBytes = await _rotateImage(pngBytes, widget.rotation);
      }

      pdfThumbnailCache[_cacheKey] = pngBytes;
      if (mounted) {
        setState(() {
          _bytes = pngBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ReviewPdfPageImage error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _rotateImage(Uint8List src, int rotation) async {
    final codec = await ui.instantiateImageCodec(src);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final w = img.width;
    final h = img.height;
    final canvasW = (rotation == 90 || rotation == 270) ? h : w;
    final canvasH = (rotation == 90 || rotation == 270) ? w : h;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(canvasW / 2, canvasH / 2);
    canvas.rotate(rotation * 3.141592653589793 / 180.0);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawImage(img, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final rotated = await picture.toImage(canvasW, canvasH);
    final bd = await rotated.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    rotated.dispose();
    return bd!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.white,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_bytes == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.grey,
            size: 48,
          ),
        ),
      );
    }
    return Image.memory(
      _bytes!,
      fit: BoxFit.fill,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
  }
}
