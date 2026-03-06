import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/providers/file_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:purchaser_edge/screens/pdf_viewer_screen.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/utils/pdf_thumbnail_cache.dart';
import 'package:unicons/unicons.dart';

class ReviewScreen extends StatelessWidget {
  final ReviewDocumentData documentData;

  const ReviewScreen({super.key, required this.documentData});

  // ─────────────────────────────────────────────────────────────────────────
  // Merge ทุกหน้า (rotation + signature) ออกมาเป็น Uint8List
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List> _buildMergedPdf() async {
    final pages = documentData.pages;
    final rotations = documentData.pageRotations;
    final signatures = documentData.pageSignatures;

    List<Uint8List> pageBytesList = [];

    for (int i = 0; i < pages.length; i++) {
      final pageInfo = pages[i];
      final bytes = await File(pageInfo.filePath).readAsBytes();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      final sourcePage = loadedDoc.pages[pageInfo.pageNumber - 1];
      final Size orig = sourcePage.size;
      final int rot = rotations[i] ?? 0;

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

      // วาง signatures
      if (signatures.containsKey(i)) {
        for (final SignatureInfo sig in signatures[i]!) {
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
  // แสดง Dialog กรอกข้อมูล แล้วส่ง API
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _uploadDocument(BuildContext context) async {
    // แสดง loading
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
                  'ກຳລັງສົ່ງເອກະສານ...',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Merge PDF
      final pdfBytes = await _buildMergedPdf();

      // บันทึกไฟล์ temp
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);

      // สร้าง multipart request
      final uri = Uri.parse('http://localhost:5000/documents/upload');
      final request = http.MultipartRequest('POST', uri);

      // Form fields
      request.fields['document_number'] =
          context.read<DocumentProvider>().documentNumber ?? '';
      request.fields['document_title'] =
          context.read<DocumentProvider>().documentTitle ?? '';
      request.fields['branch'] = context.read<DocumentProvider>().branch ?? '';
      request.fields['category'] =
          context.read<DocumentProvider>().documentCategory ?? '';
      request.fields['status'] = 'pending';
      request.fields['created_by'] =
          context.read<DocumentProvider>().createBy ?? '';

      // PDF file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          tempFile.path,
          filename:
              '${context.read<DocumentProvider>().documentTitle?.replaceAll(' ', '_') ?? 'document'}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // ลบ temp file
      await tempFile.delete();

      // ปิด loading
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        // สำเร็จ
        if (context.mounted) {
          context.read<FileProvider>().clearFile();
          context.read<DocumentProvider>().resetDocumentInfo();

          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.green,
                        size: 36,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'ສົ່ງເອກະສານສຳເລັດ!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                          // ปิด success dialog
                          Navigator.of(context, rootNavigator: true).pop();
                          // กลับไป 2 หน้า (ReviewScreen + PdfViewerScreen)
                          Navigator.of(context)
                            ..pop()
                            ..pop();
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
      } else {
        // Error จาก server
        if (context.mounted) {
          _showErrorDialog(
            context,
            'ເກີດຂໍ້ຜິດພາດ: ${response.statusCode}\n${response.body}',
          );
        }
      }
    } catch (e) {
      // ปิด loading ก่อน
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        _showErrorDialog(context, 'ບໍ່ສາມາດເຊື່ອມຕໍ່ Server ໄດ້\n$e');
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
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
    final pages = documentData.pages;
    final rotations = documentData.pageRotations;
    final signatures = documentData.pageSignatures;

    return Scaffold(
      body: Column(
        children: [
          // ========== Header ==========
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: ColorService().mainGredientColor,
            ),
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
                  'ກວດສອບເອກະສານກ່ອນສົ່ງ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // ===== ปุ่มส่งเอกสาร =====
                GestureDetector(
                  onTap: () => _uploadDocument(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColorService().successColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Text(
                          'ສົ່ງເອກະສານ',
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(UniconsLine.sign_out_alt, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ========== Scrollable Page List ==========
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
                : Container(
                    color: Colors.grey.shade200,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 200,
                      ),
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        final pageInfo = pages[index];
                        final rotation = rotations[index] ?? 0;
                        final sigs = signatures[index] ?? [];

                        return _ReviewPageItem(
                          index: index,
                          pageInfo: pageInfo,
                          rotation: rotation,
                          signatures: sigs,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UploadDialog — form กรอกข้อมูลก่อนส่ง
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _ReviewPageItem — one card per page
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewPageItem extends StatelessWidget {
  final int index;
  final PageInfo pageInfo;
  final int rotation;
  final List<SignatureInfo> signatures;

  const _ReviewPageItem({
    required this.index,
    required this.pageInfo,
    required this.rotation,
    required this.signatures,
  });

  Future<Size> _getPageSize() async {
    final bytes = await File(pageInfo.filePath).readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final size = doc.pages[pageInfo.pageNumber - 1].size;
    doc.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'ໜ້າ ${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          FutureBuilder<Size>(
            future: _getPageSize(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              Size pageSize = snapshot.data!;
              double finalWidth = pageSize.width;
              double finalHeight = pageSize.height;
              if (rotation == 90 || rotation == 270) {
                finalWidth = pageSize.height;
                finalHeight = pageSize.width;
              }

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: finalWidth / finalHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _ReviewPdfPageImage(
                            filePath: pageInfo.filePath,
                            pageNumber: pageInfo.pageNumber,
                            rotation: rotation,
                          ),
                        ),
                        ...signatures.map(
                          (sig) => _ReadOnlySignatureOverlay(signature: sig),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReviewPdfPageImage
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

// ─────────────────────────────────────────────────────────────────────────────
// _ReadOnlySignatureOverlay
// ─────────────────────────────────────────────────────────────────────────────
class _ReadOnlySignatureOverlay extends StatelessWidget {
  final SignatureInfo signature;

  const _ReadOnlySignatureOverlay({required this.signature});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              left: signature.left * constraints.maxWidth,
              top: signature.top * constraints.maxHeight,
              width: signature.width * constraints.maxWidth,
              height: signature.height * constraints.maxHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.memory(
                  signature.imageBytes,
                  fit: BoxFit.fill,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
