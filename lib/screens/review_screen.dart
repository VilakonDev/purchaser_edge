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
import 'package:unicons/unicons.dart';

class ReviewScreen extends StatelessWidget {
  final ReviewDocumentData documentData;

  const ReviewScreen({super.key, required this.documentData});

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ _buildMergedPdf
  // Fast path  : ไม่มี rotate+sig → extract page โดยตรง (font ไม่หาย)
  // Slow path  : มี rotate หรือ sig → drawPdfTemplate เหมือนเดิม
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List> _buildMergedPdf() async {
    final pages = documentData.pages;
    final rotations = documentData.pageRotations;
    final signatures = documentData.pageSignatures;

    final Map<String, Uint8List> fileCache = {};
    final List<Uint8List> pageBytesList = [];

    for (int i = 0; i < pages.length; i++) {
      final pageInfo = pages[i];
      final int rot = rotations[i] ?? 0;
      final List<SignatureInfo> sigs = signatures[i] ?? [];
      final bool needsRotate = rot != 0;
      final bool hasSigs = sigs.isNotEmpty;

      fileCache[pageInfo.filePath] ??= await File(
        pageInfo.filePath,
      ).readAsBytes();
      final Uint8List srcBytes = fileCache[pageInfo.filePath]!;

      if (!needsRotate && !hasSigs) {
        // ── Fast path ──────────────────────────────────────────────────────
        // โหลด full doc แล้วลบหน้าที่ไม่ต้องการออก → font resources ยังอยู่
        final PdfDocument fullDoc = PdfDocument(inputBytes: srcBytes);
        final int total = fullDoc.pages.count;

        // ลบจากท้ายไปหน้า เพื่อไม่ให้ index เลื่อน
        for (int p = total - 1; p >= 0; p--) {
          if (p != pageInfo.pageNumber - 1) {
            fullDoc.pages.removeAt(p);
          }
        }

        final List<int> extracted = await fullDoc.save();
        pageBytesList.add(Uint8List.fromList(extracted));
        fullDoc.dispose();
      } else {
        // ── Slow path ──────────────────────────────────────────────────────
        // ต้อง rotate หรือวาง signature → ใช้ drawPdfTemplate
        final PdfDocument loadedDoc = PdfDocument(inputBytes: srcBytes);
        final PdfPage sourcePage = loadedDoc.pages[pageInfo.pageNumber - 1];
        final Size orig = sourcePage.size;

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

        for (final SignatureInfo sig in sigs) {
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

        final List<int> singleBytes = await singleDoc.save();
        pageBytesList.add(Uint8List.fromList(singleBytes));
        singleDoc.dispose();
        loadedDoc.dispose();
      }
    }

    if (pageBytesList.isEmpty) return Uint8List(0);
    if (pageBytesList.length == 1) return pageBytesList.first;

    // ✅ merge โดยใช้ addPage loop — ใช้ได้ทุก Syncfusion version
    final PdfDocument mergedDoc = PdfDocument();
    mergedDoc.pageSettings.margins.all = 0;

    for (final Uint8List pb in pageBytesList) {
      final PdfDocument srcDoc = PdfDocument(inputBytes: pb);
      final PdfPage srcPage = srcDoc.pages[0];
      final Size srcSize = srcPage.size;

      mergedDoc.pageSettings.size = srcSize;
      mergedDoc.pageSettings.orientation = srcSize.width > srcSize.height
          ? PdfPageOrientation.landscape
          : PdfPageOrientation.portrait;

      final PdfPage destPage = mergedDoc.pages.add();
      final PdfTemplate srcTmpl = srcPage.createTemplate();
      destPage.graphics.drawPdfTemplate(srcTmpl, Offset.zero, srcSize);

      srcDoc.dispose();
    }

    final List<int> mergedBytes = await mergedDoc.save();
    mergedDoc.dispose();
    return Uint8List.fromList(mergedBytes);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Upload document
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _uploadDocument(BuildContext context) async {
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
          child: const Padding(
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
      final pdfBytes = await _buildMergedPdf();

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);

      final uri = Uri.parse('http://192.168.1.181:5000/documents/upload');
      final request = http.MultipartRequest('POST', uri);

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

      await tempFile.delete();

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
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
                    const Text(
                      'ສົ່ງເອກະສານສຳເລັດ!',
                      style: TextStyle(
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
                          Navigator.of(context)
                            ..pop()
                            ..pop();
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
      } else {
        if (context.mounted) {
          _showErrorDialog(
            context,
            'ເກີດຂໍ້ຜິດພາດ: ${response.statusCode}\n${response.body}',
          );
        }
      }
    } catch (e) {
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(UniconsLine.arrow_left),
                        const SizedBox(width: 10),
                        Text(
                          'ກັບຄືນ',
                          style: TextStyle(color: ColorService().mainTextColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'ກວດສອບເອກະສານກ່ອນສົ່ງ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => _uploadDocument(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    height: 40,
                    decoration: BoxDecoration(
                      color: ColorService().successColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'ສົ່ງເອກະສານ',
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(width: 10),
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
                        const SizedBox(height: 16),
                        const Text(
                          'ບໍ່ມີເອກະສານສຳລັບກວດສອບ',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
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
// _ReviewPageItem
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
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
              double aspectRatio;
              if (snapshot.hasData) {
                final Size pageSize = snapshot.data!;
                final double finalWidth = (rotation == 90 || rotation == 270)
                    ? pageSize.height
                    : pageSize.width;
                final double finalHeight = (rotation == 90 || rotation == 270)
                    ? pageSize.width
                    : pageSize.height;
                aspectRatio = finalWidth / finalHeight;
              } else {
                aspectRatio = (rotation == 90 || rotation == 270)
                    ? 297 / 210
                    : 210 / 297;
              }

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
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
                    aspectRatio: aspectRatio,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _ReviewPdfPageViewer(
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
// _ReviewPdfPageViewer
// ✅ ใช้ pdfrx render เป็น PNG — PDFium มี font engine ในตัว
//    ไม่พึ่ง Windows system font → ไม่เป็น □
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewPdfPageViewer extends StatefulWidget {
  final String filePath;
  final int pageNumber;
  final int rotation;

  const _ReviewPdfPageViewer({
    required this.filePath,
    required this.pageNumber,
    required this.rotation,
  });

  @override
  State<_ReviewPdfPageViewer> createState() => _ReviewPdfPageViewerState();
}

class _ReviewPdfPageViewerState extends State<_ReviewPdfPageViewer> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _renderPage();
  }

  @override
  void didUpdateWidget(_ReviewPdfPageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.rotation != widget.rotation) {
      _generation++;
      _renderPage();
    }
  }

  Future<void> _renderPage() async {
    final int myGen = _generation;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    pdfrx.PdfDocument? doc;
    try {
      doc = await pdfrx.PdfDocument.openFile(widget.filePath);
      if (myGen != _generation || !mounted) return;

      final int total = doc.pages.length;
      if (widget.pageNumber < 1 || widget.pageNumber > total) {
        throw Exception('page out of range');
      }

      final page = doc.pages[widget.pageNumber - 1];

      // render ความละเอียดสูง 2400px สำหรับ review
      const double targetLong = 2400.0;
      final double scale = page.width >= page.height
          ? targetLong / page.width
          : targetLong / page.height;
      final int imgW = (page.width * scale).round().clamp(1, 2400);
      final int imgH = (page.height * scale).round().clamp(1, 2400);

      final pdfrx.PdfImage? pageImage = await page.render(
        fullWidth: imgW.toDouble(),
        fullHeight: imgH.toDouble(),
      );

      if (pageImage == null) throw Exception('render returned null');
      if (myGen != _generation || !mounted) return;

      final Uint8List pixelsCopy = Uint8List.fromList(pageImage.pixels);
      final int pw = pageImage.width;
      final int ph = pageImage.height;

      doc.dispose();
      doc = null;

      // pixels → PNG
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
        pixelsCopy,
      );
      final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.raw(
        buffer,
        width: pw,
        height: ph,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final ui.Codec codec = await descriptor.instantiateCodec();
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? byteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frameInfo.image.dispose();
      codec.dispose();

      if (byteData == null) throw Exception('toByteData failed');
      if (myGen != _generation || !mounted) return;

      Uint8List pngBytes = byteData.buffer.asUint8List();

      if (widget.rotation != 0) {
        pngBytes = await _rotateImage(pngBytes, widget.rotation);
      }

      if (myGen != _generation || !mounted) return;
      setState(() {
        _imageBytes = pngBytes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ReviewPdfPageViewer] error: $e');
      if (myGen != _generation || !mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    } finally {
      doc?.dispose();
    }
  }

  Future<Uint8List> _rotateImage(Uint8List src, int rotation) async {
    final ui.Codec codec = await ui.instantiateImageCodec(src);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image img = frame.image;
    codec.dispose();

    final int w = img.width;
    final int h = img.height;
    final bool swap = rotation == 90 || rotation == 270;
    final int cw = swap ? h : w;
    final int ch = swap ? w : h;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(cw / 2, ch / 2);
    canvas.rotate(rotation * 3.141592653589793 / 180.0);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawImage(img, Offset.zero, Paint());
    img.dispose();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image rotated = await picture.toImage(cw, ch);
    final ByteData? bd = await rotated.toByteData(
      format: ui.ImageByteFormat.png,
    );
    rotated.dispose();
    return bd!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _imageBytes == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Colors.grey.shade400,
                size: 48,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  _generation++;
                  _renderPage();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ລອງໃໝ່',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: BoxFit.contain,
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
