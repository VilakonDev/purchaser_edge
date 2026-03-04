import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdfrx/pdfrx.dart' as rx;
import 'package:purchaser_edge/providers/file_provider.dart';

// ─── A4 (PDF points = 1/72 inch) ─────────────────────────────
// Portrait : 595.28 × 841.89
// Landscape: 841.89 × 595.28
const double _a4W = 595.28;
const double _a4H = 841.89;
const double _pad = 28.35; // 10 mm

// ─── Thumbnail sizing ─────────────────────────────────────────
// Portrait  thumbnail : width=112, height=112×(842/595)≈158  → aspect 595/842
// Landscape thumbnail : width=112, height=112×(595/842)≈79   → aspect 842/595
const double _thumbW = 112.0;

class PDFViewerHome extends StatefulWidget {
  const PDFViewerHome({super.key});
  @override
  State<PDFViewerHome> createState() => _PDFViewerHomeState();
}

class _PDFViewerHomeState extends State<PDFViewerHome> {
  int  _currentPage    = 1;
  int  _totalPages     = 0;
  int  _selectedThumb  = 0;
  bool _sidebarVisible = true;
  bool _isRotating     = false;

  Key _viewerKey     = const ValueKey(0);
  int _viewerVersion = 0;

  final PdfViewerController _controller = PdfViewerController();
  Future<_PDFData>? _pdfFuture;

  /// ต้นฉบับ raw merge — ไม่เคยเปลี่ยน
  Uint8List? _srcBytes;

  /// bytes ที่ viewer ใช้ (หลัง rotate+normalize)
  Uint8List? _displayBytes;

  /// rotation สะสมต่อหน้า: 0 / 90 / 180 / 270
  final Map<int, int> _rotations = {};

  /// thumbnail cache — key = "idx_deg"
  final Map<String, Uint8List> _thumbCache = {};
  static const int _maxCache = 20;

  // ══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final files = context.read<FileProvider>().files;
    if (files.isNotEmpty && _pdfFuture == null) {
      _pdfFuture = _init(files);
    }
  }

  @override
  void dispose() {
    _thumbCache.clear();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS — PURE MATH (ไม่มี side-effect)
  // ══════════════════════════════════════════════════════════════

  /// aspect ratio ของ thumbnail สำหรับหน้า [idx]
  /// portrait  → 595/842 ≈ 0.707   (สูงกว่ากว้าง)
  /// landscape → 842/595 ≈ 1.415   (กว้างกว่าสูง)
  double _thumbAspect(int idx) {
    final bool land = _isLandscape(idx);
    return land ? (_a4H / _a4W) : (_a4W / _a4H);
  }

  /// page นี้อยู่ใน landscape หรือเปล่า
  bool _isLandscape(int idx) {
    final deg = _rotations[idx] ?? 0;
    return deg == 90 || deg == 270;
  }

  // ══════════════════════════════════════════════════════════════
  // PDF PROCESSING
  // ══════════════════════════════════════════════════════════════

  /// Step 1: merge ไฟล์ดิบ — เก็บขนาดต้นฉบับ
  Future<Uint8List> _mergeRaw(List<File> files) async {
    final doc = sf.PdfDocument();
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final src   = sf.PdfDocument(inputBytes: bytes);
      for (int i = 0; i < src.pages.count; i++) {
        final sp  = src.pages[i];
        final sec = doc.sections!.add();
        sec.pageSettings
          ..margins.all = 0
          ..size        = sp.size;
        sec.pages.add().graphics
            .drawPdfTemplate(sp.createTemplate(), Offset.zero, sp.size);
      }
      src.dispose();
    }
    final out = Uint8List.fromList(await doc.save());
    doc.dispose();
    return out;
  }

  /// Step 2: สร้าง display PDF
  ///
  /// สำหรับแต่ละหน้า:
  ///   deg 0/180  → page = A4 Portrait  (595 × 842)
  ///   deg 90/270 → page = A4 Landscape (842 × 595)
  ///
  /// วิธีการ (render-to-image ไม่ใช้ transform):
  ///   1. render ต้นฉบับเป็น PNG @2x
  ///   2. หมุน PNG ด้วย Flutter Canvas (แม่นยำ 100%)
  ///   3. scale-to-fit ลงใน A4 area (หัก _pad รอบทุกด้าน)
  ///   4. วาง image กึ่งกลาง page
  Future<Uint8List> _buildDisplay(
    Uint8List srcBytes,
    Map<int, int> rotations,
  ) async {
    final srcDoc = sf.PdfDocument(inputBytes: srcBytes);
    final outDoc = sf.PdfDocument();

    // เปิด rxDoc ครั้งเดียว reuse ทุกหน้า
    final rxDoc = await rx.PdfDocument.openData(srcBytes);

    for (int i = 0; i < srcDoc.pages.count; i++) {
      final deg = rotations[i] ?? 0;

      // ── A. Render page ต้นฉบับ @2x ──────────────────────────
      final rxPage = rxDoc.pages[i];
      const double rScale = 2.0;
      final double rW = rxPage.width  * rScale;
      final double rH = rxPage.height * rScale;

      final rendered = await rxPage.render(
        fullWidth: rW, fullHeight: rH,
        backgroundColor: 0xFFFFFFFF,
      );
      final uiImg   = await rendered?.createImage();
      final imgData = await uiImg?.toByteData(format: ui.ImageByteFormat.png);
      uiImg?.dispose();

      if (imgData == null) continue;
      final rawPng = imgData.buffer.asUint8List();

      // ── B. หมุน PNG (Flutter Canvas) ─────────────────────────
      final Uint8List rotPng = deg == 0
          ? rawPng
          : await _rotatePng(rawPng, deg, rW.round(), rH.round());

      // ขนาด image หลัง rotate (pixels)
      final bool   swap = (deg == 90 || deg == 270);
      final double iW   = swap ? rH : rW;
      final double iH   = swap ? rW : rH;

      // ── C. กำหนดขนาด output page ─────────────────────────────
      //   Portrait  (deg 0/180)  → 595 × 842
      //   Landscape (deg 90/270) → 842 × 595
      final bool   land  = swap;
      final double pageW = land ? _a4H : _a4W;
      final double pageH = land ? _a4W : _a4H;

      // area หลังหัก padding
      final double areaW = pageW - _pad * 2;
      final double areaH = pageH - _pad * 2;

      // scale-to-fit (เลือก scale ที่น้อยกว่า เพื่อไม่ล้น area)
      final double s  = (areaW / iW) < (areaH / iH)
          ? (areaW / iW)
          : (areaH / iH);
      final double dW = iW * s;
      final double dH = iH * s;

      // จัดกึ่งกลาง
      final double ox = _pad + (areaW - dW) / 2;
      final double oy = _pad + (areaH - dH) / 2;

      // ── D. สร้าง output page ─────────────────────────────────
      final sec = outDoc.sections!.add();
      sec.pageSettings
        ..margins.all = 0
        ..size        = Size(pageW, pageH);
      final np = sec.pages.add();
      final g  = np.graphics;

      g.drawRectangle(
        brush : sf.PdfSolidBrush(sf.PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(0, 0, pageW, pageH),
      );
      g.drawImage(sf.PdfBitmap(rotPng), Rect.fromLTWH(ox, oy, dW, dH));
    }

    await rxDoc.dispose();
    srcDoc.dispose();
    final out = Uint8List.fromList(await outDoc.save());
    outDoc.dispose();
    return out;
  }

  /// หมุน PNG ด้วย Flutter Canvas — ถูกต้อง 100% ไม่มี drift
  Future<Uint8List> _rotatePng(
    Uint8List png, int deg, int origW, int origH,
  ) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final src   = frame.image;

    final bool swap = (deg == 90 || deg == 270);
    final int  outW = swap ? origH : origW;
    final int  outH = swap ? origW : origH;

    final rec    = ui.PictureRecorder();
    final canvas = Canvas(rec);

    canvas.translate(outW / 2.0, outH / 2.0);
    canvas.rotate(deg * 3.141592653589793 / 180.0);
    canvas.translate(-origW / 2.0, -origH / 2.0);
    canvas.drawImage(src, Offset.zero, Paint());
    src.dispose();

    final pic    = rec.endRecording();
    final outImg = await pic.toImage(outW, outH);
    final bdata  = await outImg.toByteData(format: ui.ImageByteFormat.png);
    outImg.dispose();

    return bdata!.buffer.asUint8List();
  }

  // ── Init ─────────────────────────────────────────────────────
  Future<_PDFData> _init(List<File> files) async {
    _srcBytes     = await _mergeRaw(files);
    _displayBytes = await _buildDisplay(_srcBytes!, {});

    final doc   = await rx.PdfDocument.openData(_displayBytes!);
    final count = doc.pages.length;
    await doc.dispose();

    return _PDFData(pageCount: count);
  }

  // ── Rotate single page ───────────────────────────────────────
  Future<void> _rotatePage(int idx) async {
    if (_isRotating || _srcBytes == null) return;
    setState(() => _isRotating = true);

    _rotations[idx] = ((_rotations[idx] ?? 0) + 90) % 360;
    // ไม่ต้อง clear cache แบบ manual เพราะ version เปลี่ยนทำให้ cache miss อัตโนมัติ

    _displayBytes = await _buildDisplay(_srcBytes!, _rotations);
    _viewerVersion++;

    setState(() {
      _viewerKey  = ValueKey(_viewerVersion);
      _isRotating = false;
    });
  }

  // ── Rotate all pages ─────────────────────────────────────────
  Future<void> _rotateAll(int count) async {
    if (_isRotating || _srcBytes == null) return;
    setState(() => _isRotating = true);

    for (int i = 0; i < count; i++) {
      _rotations[i] = ((_rotations[i] ?? 0) + 90) % 360;
    }
    _thumbCache.clear();

    _displayBytes = await _buildDisplay(_srcBytes!, _rotations);
    _viewerVersion++;

    setState(() {
      _viewerKey  = ValueKey(_viewerVersion);
      _isRotating = false;
    });
  }

  /// Render thumbnail จาก _displayBytes (ซึ่ง rotate + normalize แล้ว)
  /// cache key รวม _viewerVersion เพื่อ invalidate ทุกครั้งที่ _displayBytes เปลี่ยน
  Future<Uint8List?> _thumb(int idx, int version) async {
    final cacheKey = '${idx}_v$version';
    if (_thumbCache.containsKey(cacheKey)) return _thumbCache[cacheKey];
    if (_displayBytes == null) return null;

    final doc  = await rx.PdfDocument.openData(_displayBytes!);
    final page = doc.pages[idx];

    // render ให้พอดีกับ _thumbW — height ตาม aspect จริงของ display page
    final double tH = _thumbW * (page.height / page.width);
    final img = await page.render(
      fullWidth: _thumbW, fullHeight: tH,
      backgroundColor: 0xFFFFFFFF,
    );
    final uiImg = await img?.createImage();
    final bdata = await uiImg?.toByteData(format: ui.ImageByteFormat.png);
    uiImg?.dispose();
    await doc.dispose();

    final result = bdata?.buffer.asUint8List();
    if (result != null) {
      if (_thumbCache.length >= _maxCache) {
        _thumbCache.remove(_thumbCache.keys.first);
      }
      _thumbCache[cacheKey] = result;
    }
    return result;
  }

  void _goTo(int page) {
    setState(() { _selectedThumb = page - 1; _currentPage = page; });
    _controller.jumpToPage(page);
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final files  = context.watch<FileProvider>().files;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        title: Row(children: [
          const Icon(Icons.picture_as_pdf),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              files.length == 1
                  ? files.first.uri.pathSegments.last
                  : 'Merged PDF (${files.length} files)',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ]),
        actions: [
          if (_isRotating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$_currentPage / $_totalPages',
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
          IconButton(
            icon: Icon(_sidebarVisible
                ? Icons.view_sidebar
                : Icons.view_sidebar_outlined),
            onPressed: () =>
                setState(() => _sidebarVisible = !_sidebarVisible),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: files.isEmpty
          ? _emptyState()
          : FutureBuilder<_PDFData>(
              future: _pdfFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF1A73E8)),
                        const SizedBox(height: 16),
                        Text(
                          files.length > 1
                              ? 'Merging ${files.length} files...'
                              : 'Loading PDF...',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                if (snap.hasError || !snap.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text('Error: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }

                final data = snap.data!;
                return Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _sidebarVisible ? 200 : 0,
                    child: _sidebarVisible
                        ? _sidebar(data.pageCount, isDark)
                        : const SizedBox.shrink(),
                  ),
                  if (_sidebarVisible)
                    const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: _viewer()),
                ]);
              },
            ),
    );
  }

  Widget _emptyState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.picture_as_pdf_outlined, size: 80, color: Color(0xFF1A73E8)),
        SizedBox(height: 16),
        Text('No PDF Files',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('ຍັງບໍ່ມີໄຟລ໌ PDF ກະລຸນາເພີ່ມໄຟລ໌ຈາກໜ້າກ່ອນ',
            style: TextStyle(color: Colors.grey)),
      ],
    ),
  );

  // ── Sidebar ──────────────────────────────────────────────────
  Widget _sidebar(int pageCount, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF252525) : const Color(0xFFEEEEEE),
      child: Column(children: [

        // header
        Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E0E0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            Expanded(
              child: Text('Pages ($pageCount)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            Tooltip(
              message: 'หมุนทุกหน้า 90°',
              child: InkWell(
                onTap: _isRotating ? null : () => _rotateAll(pageCount),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.rotate_right, size: 16,
                      color: _isRotating
                          ? Colors.grey
                          : (isDark ? Colors.white70 : const Color(0xFF555555))),
                ),
              ),
            ),
          ]),
        ),

        // thumbnail list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pageCount,
            cacheExtent: 400,
            itemBuilder: (ctx, index) {
              final isSelected = _selectedThumb == index;
              final deg        = _rotations[index] ?? 0;
              // capture version เพื่อ pass ลง _thumb() และ ValueKey
              final int    ver    = _viewerVersion;
              // aspect ratio ของ thumbnail: เปลี่ยนเมื่อ rotate
              final double aspect = _thumbAspect(index);

              return GestureDetector(
                onTap: () => _goTo(index + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1A73E8).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1A73E8)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(children: [
                    Stack(children: [
                      // ✅ Container ปรับ aspect ratio ตาม portrait/landscape
                      Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AspectRatio(
                          aspectRatio: aspect,
                          child: FutureBuilder<Uint8List?>(
                            // key เปลี่ยนเมื่อ deg เปลี่ยน → rebuild + re-fetch
                            key: ValueKey('t_${index}_$ver'),
                            future: _thumb(index, ver),
                            builder: (ctx, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Color(0xFF1A73E8)),
                                  ),
                                );
                              }
                              if (!snap.hasData || snap.data == null) {
                                return const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey, size: 24),
                                );
                              }
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  snap.data!,
                                  fit: BoxFit.fill, // fill เพราะ aspect ratio ถูกต้องแล้ว
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // ✅ ปุ่ม rotate ต่อหน้า
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: _isRotating ? null : () => _rotatePage(index),
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: _isRotating
                                  ? Colors.grey.withOpacity(0.55)
                                  : Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.rotate_right,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF1A73E8)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ── Viewer ───────────────────────────────────────────────────
  Widget _viewer() {
    final bytes = _displayBytes;
    if (bytes == null) return const SizedBox.shrink();

    return SfPdfViewer.memory(
      bytes,
      key: _viewerKey,
      controller: _controller,
      pageLayoutMode: PdfPageLayoutMode.continuous,
      scrollDirection: PdfScrollDirection.vertical,
      canShowScrollHead: true,
      pageSpacing: 8,
     
      onDocumentLoaded: (details) {
        final page = _currentPage;
        setState(() => _totalPages = details.document.pages.count);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (page > 1) _controller.jumpToPage(page);
        });
      },
      onPageChanged: (details) {
        setState(() {
          _currentPage   = details.newPageNumber;
          _selectedThumb = details.newPageNumber - 1;
        });
      },
    );
  }
}

class _PDFData {
  final int pageCount;
  const _PDFData({required this.pageCount});
}