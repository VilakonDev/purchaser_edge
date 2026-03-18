import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/providers/user_provider.dart';
import 'package:purchaser_edge/services/send_email_service.dart';

import 'package:purchaser_edge/services/url_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:purchaser_edge/screens/pdf_viewer_screen.dart';
import 'package:purchaser_edge/services/color_service.dart';

import 'package:unicons/unicons.dart';

class ApproveScreen extends StatefulWidget {
  final ReviewDocumentData? documentData;
  final String? fileName;
  final String? documentId;
  final String? documentNumber;
  final String? documentTitle;
  final String? creatorEmail;

  const ApproveScreen({
    super.key,
    this.documentData,
    this.fileName,
    this.documentNumber,
    this.documentTitle,
    this.documentId,
    this.creatorEmail,
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

  bool _isLoadingFile = false;
  String? _loadError;
  String? _downloadedFilePath;

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

  Future<void> _downloadAndLoadFile() async {
    setState(() {
      _isLoadingFile = true;
      _loadError = null;
    });

    try {
      final url = '${UrlService().baseUrl}/uploads/${widget.fileName}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
          'ດາວໂຫຼດບໍ່ສຳເລັດ: ${response.statusCode} ${widget.fileName}',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/review_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(response.bodyBytes);
      _downloadedFilePath = tempPath;

      final doc = PdfDocument(inputBytes: response.bodyBytes);
      final pageCount = doc.pages.count;
      doc.dispose();

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
    if (_downloadedFilePath != null) {
      File(_downloadedFilePath!).deleteSync(recursive: true);
    }
    super.dispose();
  }

  Future<void> _pickSignatureFromUrl(String url) async {
    if (selectedPageIndex == null) return;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final bytes = response.bodyBytes;
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
        pageSignatures.putIfAbsent(selectedPageIndex!, () => []);
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
    } catch (e) {
      debugPrint('Error loading signature from URL: $e');
    }
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
          newPage.graphics.drawImage(
            PdfBitmap(sig.imageBytes),
            Rect.fromLTWH(sl, st, sw, sh),
          );
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

  Future<void> _onSubmit() async {
    if (_isApproveMode) {
      context.read<AuthProvider>().currentUser!.role == "DISTRICT_MANAGER"
          ? await _approveDocumentByDM()
          : context.read<AuthProvider>().currentUser!.role == "DIRECTOR"
          ? await _approveDocumentByDirector()
          : setState(() {});
    } else {
      return;
    }
  }

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
        '${UrlService().baseUrl}/documents/dmApprove/${widget.documentId}',
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

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200) {
        _showSuccessDialog('Approve ເອກະສານສຳເລັດ!', popCount: 1);

        SendEmailService().sendEmail(
          widget.creatorEmail.toString(),
          'District Manager',
          'เอกสาร ${widget.documentNumber} เรื่อง : ${widget.documentTitle} ถูกอนุมัติแล้ว',
        );

        SendEmailService().sendEmail(
          context.read<UserProvider>().directorsEmail,
          'District Manager',
          'มีเอกสาร ${widget.documentNumber} เรื่อง : ${widget.documentTitle} รออนุมัติ',
        );
      } else {
        _showErrorDialog(
          'ເກີດຂໍ້ຜິດພາດ: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        _showErrorDialog('ບໍ່ສາມາດເຊື່ອມຕໍ່ Server ໄດ້\n$e');
      }
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
        '${UrlService().baseUrl}/documents/directorApprove/${widget.documentId}',
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

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200) {
        _showSuccessDialog('Approve ເອກະສານສຳເລັດ!', popCount: 1);

        SendEmailService().sendEmail(
          widget.creatorEmail.toString(),
          'Director',
          'เอกสาร ${widget.documentNumber} เรื่อง : ${widget.documentTitle} ถูกอนุมัติแล้ว',
        );
      } else {
        debugPrint('ເກີດຂໍ້ຜິດພາດ: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        _showErrorDialog('ບໍ່ສາມາດເຊື່ອມຕໍ່ Server ໄດ້\n$e');
      }
    }
  }

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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
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
          padding: const EdgeInsets.all(32),
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
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.green,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    for (int i = 0; i < popCount; i++) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text(
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
          padding: const EdgeInsets.all(32),
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
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ເກີດຂໍ້ຜິດພາດ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text(
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
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    const Text(
                      'ບໍ່ສາມາດໂຫຼດເອກະສານໄດ້',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _downloadAndLoadFile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ລອງໃໝ່'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                        const SizedBox(height: 16),
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

  Widget _buildHeader() {
    final title = _isApproveMode
        ? 'ກວດສອບ ແລະ Approve ເອກະສານ'
        : 'ກວດສອບ ແລະ ເຊັນເອກະສານ';
    final submitLabel = _isApproveMode ? 'Approve' : 'ສົ່ງເອກະສານ';

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: ColorService().mainGredientColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(UniconsLine.arrow_left, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'ກັບຄືນ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          Row(
            children: [
              if (selectedPageIndex != null) ...[
                GestureDetector(
                  onTap: () {
                    _pickSignatureFromUrl(
                      '${UrlService().baseUrl}/signature/${context.read<AuthProvider>().currentUser!.fileSignature}',
                    );
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.edit_road, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'ເພີ່ມລາຍເຊັນ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: pages.isEmpty || _isLoadingFile ? null : _onSubmit,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: pages.isEmpty || _isLoadingFile
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: pages.isEmpty || _isLoadingFile
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isApproveMode
                            ? Icons.check_circle_outline
                            : UniconsLine.sign_out_alt,
                        size: 16,
                        color: pages.isEmpty || _isLoadingFile
                            ? Colors.white.withOpacity(0.5)
                            : _isApproveMode
                            ? Colors.orange.shade600
                            : ColorService().successColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        submitLabel,
                        style: TextStyle(
                          color: pages.isEmpty || _isLoadingFile
                              ? Colors.white.withOpacity(0.5)
                              : _isApproveMode
                              ? Colors.orange.shade600
                              : ColorService().successColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildThumbnailStrip() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ColorService().primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    UniconsLine.layers,
                    size: 14,
                    color: ColorService().primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ໜ້າທັງໝົດ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorService().mainTextColor,
                  ),
                ),
                const Spacer(),
                if (pages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ColorService().primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${pages.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ColorService().primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final pageInfo = pages[index];
                final bool isSelected = selectedPageIndex == index;
                final bool hasSignature =
                    pageSignatures.containsKey(index) &&
                    pageSignatures[index]!.isNotEmpty;

                return GestureDetector(
                  onTap: () => setState(() => selectedPageIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? ColorService().primaryColor
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? ColorService().primaryColor.withOpacity(0.12)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: isSelected ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ColorService().primaryColor.withOpacity(0.05)
                                : Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(9),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ໜ້າ ${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? ColorService().primaryColor
                                      : Colors.grey.shade500,
                                ),
                              ),
                              if (hasSignature)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorService().primaryColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: ColorService().primaryColor,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${pageSignatures[index]!.length}',
                                        style: TextStyle(
                                          color: ColorService().primaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: OptimizedPdfThumbnail(
                              filePath: pageInfo.filePath,
                              pageNumber: pageInfo.pageNumber,
                              rotation: pageRotations[index] ?? 0,
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

  Widget _buildPreviewArea() {
    return Container(
      color: Colors.grey.shade100,
      child: selectedPageIndex == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.touch_app,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ກົດເລືອກໜ້າຈາກດ້ານຊ້າຍ',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ເພື່ອກວດສອບ ຫຼື ເພີ່ມລາຍເຊັນ',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            )
          : _buildInteractivePreview(selectedPageIndex!),
    );
  }

  Widget _buildInteractivePreview(int pageIdx) {
    final pageInfo = pages[pageIdx];
    final rotation = pageRotations[pageIdx] ?? 0;
    final sigs = pageSignatures[pageIdx] ?? [];

    return FutureBuilder<Size>(
      future: _getPageSizeCached(pageInfo.filePath, pageInfo.pageNumber),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.blue, width: 3),
              ),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRect(
                  child: Stack(
                    children: [
                      // ✅ PDF จริง ไม่ใช่ bitmap
                      Positioned.fill(
                        child: RotatedBox(
                          quarterTurns: rotation ~/ 90,
                          child: _PdfPageViewer(
                            filePath: pageInfo.filePath,
                            pageNumber: pageInfo.pageNumber,
                          ),
                        ),
                      ),

                      // Signature overlays
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
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PdfPageViewer — แสดง PDF จริงด้วย SfPdfViewer
// ─────────────────────────────────────────────────────────────────────────────
class _PdfPageViewer extends StatefulWidget {
  final String filePath;
  final int pageNumber;

  const _PdfPageViewer({required this.filePath, required this.pageNumber});

  @override
  State<_PdfPageViewer> createState() => _PdfPageViewerState();
}

class _PdfPageViewerState extends State<_PdfPageViewer> {
  late PdfViewerController _controller;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _controller.jumpToPage(widget.pageNumber);
      }
    });
  }

  @override
  void didUpdateWidget(_PdfPageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.filePath != widget.filePath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _controller.jumpToPage(widget.pageNumber);
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.file(
      File(widget.filePath),
      controller: _controller,
      key: ValueKey('${widget.filePath}_${widget.pageNumber}'),
      enableDoubleTapZooming: false,
      enableTextSelection: false,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      pageLayoutMode: PdfPageLayoutMode.single,
      interactionMode: PdfInteractionMode.pan,
      scrollDirection: PdfScrollDirection.vertical,
      onPageChanged: (PdfPageChangedDetails details) {
        if (!_isDisposed &&
            details.newPageNumber != widget.pageNumber &&
            mounted) {
          Future.microtask(() {
            if (!_isDisposed && mounted) {
              _controller.jumpToPage(widget.pageNumber);
            }
          });
        }
      },
    );
  }
}
