import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdfrx/pdfrx.dart' as rx;
import 'package:purchaser_edge/providers/file_provider.dart';

class PDFViewerHome extends StatefulWidget {
  const PDFViewerHome({super.key});

  @override
  State<PDFViewerHome> createState() => _PDFViewerHomeState();
}

class _PDFViewerHomeState extends State<PDFViewerHome> {
  int _currentPage = 1;
  int _totalPages = 0;
  int _selectedThumbnail = 0;
  bool _sidebarVisible = true;

  final PdfViewerController _controller = PdfViewerController();

  Future<_PDFData>? _pdfDataFuture;
  Uint8List? _mergedBytes;

  // ✅ cache แค่ 15 หน้า — ป้องกัน RAM ล้น
  final Map<int, Uint8List> _thumbCache = {};
  static const int _maxCacheSize = 15;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final files = context.read<FileProvider>().files;
    if (files.isNotEmpty && _pdfDataFuture == null) {
      _pdfDataFuture = _prepareData(files);
    }
  }

  @override
  void dispose() {
    _thumbCache.clear();
    _mergedBytes = null;
    super.dispose();
  }

  // ── Step 1: Merge files (ทีละไฟล์ ไม่โหลดพร้อมกัน) ────────
  Future<Uint8List> _mergeFiles(List<File> files) async {
    final mergedDoc = sf.PdfDocument();

    for (final file in files) {
      // อ่านทีละไฟล์ dispose ทันทีหลังใช้
      final bytes = await file.readAsBytes();
      final srcDoc = sf.PdfDocument(inputBytes: bytes);

      for (int i = 0; i < srcDoc.pages.count; i++) {
        final srcPage = srcDoc.pages[i];
        final pageSize = srcPage.size;

        final section = mergedDoc.sections!.add();
        section.pageSettings.margins.all = 0;
        section.pageSettings.size = pageSize;

        final newPage = section.pages.add();
        newPage.graphics.drawPdfTemplate(
          srcPage.createTemplate(),
          Offset.zero,
          Size(pageSize.width, pageSize.height),
        );
      }

      // ✅ dispose ทันทีหลังใช้ ไม่ค้างใน RAM
      srcDoc.dispose();
    }

    final mergedBytes = Uint8List.fromList(await mergedDoc.save());
    mergedDoc.dispose();
    return mergedBytes;
  }

  // ── Step 2: นับหน้าอย่างเดียว ไม่ render ทั้งหมด ───────────
  Future<_PDFData> _prepareData(List<File> files) async {
    final mergedBytes = await _mergeFiles(files);
    _mergedBytes = mergedBytes;

    // เปิดแค่เพื่อนับหน้า แล้ว dispose ทันที
    final doc = await rx.PdfDocument.openData(mergedBytes);
    final pageCount = doc.pages.length;
    await doc.dispose();

    return _PDFData(mergedBytes: mergedBytes, pageCount: pageCount);
  }

  // ── Render เฉพาะหน้าที่ขอ (Lazy) ──────────────────────────
  Future<Uint8List?> _renderOnePage(int pageIndex) async {
    // คืนจาก cache ถ้ามี
    if (_thumbCache.containsKey(pageIndex)) {
      return _thumbCache[pageIndex];
    }

    if (_mergedBytes == null) return null;

    // เปิด document เฉพาะหน้านี้ แล้ว dispose ทันที
    final doc = await rx.PdfDocument.openData(_mergedBytes!);
    final page = doc.pages[pageIndex];

    const maxW = 150.0;
    final scale = maxW / page.width;

    final pageImage = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xFFFFFFFF,
    );

    final uiImage = await pageImage?.createImage();
    final byteData = await uiImage?.toByteData(
      format: ui.ImageByteFormat.png,
    );
    uiImage?.dispose();
    await doc.dispose(); // ✅ dispose ทันทีหลังใช้

    final result = byteData?.buffer.asUint8List();
    if (result != null) {
      // ✅ ถ้า cache เต็ม ลบหน้าเก่าสุดออกก่อน
      if (_thumbCache.length >= _maxCacheSize) {
        _thumbCache.remove(_thumbCache.keys.first);
      }
      _thumbCache[pageIndex] = result;
    }
    return result;
  }

  void _goToPage(int page) {
    setState(() {
      _selectedThumbnail = page - 1;
      _currentPage = page;
    });
    _controller.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final files = context.watch<FileProvider>().files;
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
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(color: Colors.white70),
              ),
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
          ? _buildEmptyState()
          : FutureBuilder<_PDFData>(
              future: _pdfDataFuture,
              builder: (context, snapshot) {

                // ── Loading ──────────────────────────────
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: Color(0xFF1A73E8)),
                        const SizedBox(height: 16),
                        Text(
                          files.length > 1
                              ? 'Merging ${files.length} files...'
                              : 'Loading PDF...',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                // ── Error ────────────────────────────────
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // ── Success ──────────────────────────────
                final data = snapshot.data!;
                return Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: _sidebarVisible ? 200 : 0,
                    child: _sidebarVisible
                        ? _buildSidebar(data.pageCount, isDark)
                        : const SizedBox.shrink(),
                  ),
                  if (_sidebarVisible)
                    const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _buildPDFViewer(data.mergedBytes),
                  ),
                ]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_outlined,
              size: 80, color: Color(0xFF1A73E8)),
          SizedBox(height: 16),
          Text('No PDF Files',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('ຍັງບໍ່ມີໄຟລ໌ PDF ກະລຸນາເພີ່ມໄຟລ໌ຈາກໜ້າກ່ອນ',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ── Sidebar: ใช้ ListView lazy — render เฉพาะที่เห็น ────────
  Widget _buildSidebar(int pageCount, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF252525) : const Color(0xFFEEEEEE),
      child: Column(children: [

        Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E0E0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            'Pages ($pageCount)',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),

        Expanded(
          // ✅ ListView.builder — render เฉพาะ item ที่อยู่บน screen
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pageCount,
            // ✅ cacheExtent ต่ำ — ไม่ pre-render ล่วงหน้าเยอะ
            cacheExtent: 300,
            itemBuilder: (context, index) {
              final pageNum = index + 1;
              final isSelected = _selectedThumbnail == index;

              return GestureDetector(
                onTap: () => _goToPage(pageNum),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
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
                    Container(
                      margin: const EdgeInsets.all(6),
                      height: 120,
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
                      // ✅ render ทีละหน้า เฉพาะที่ ListView สร้าง
                      child: FutureBuilder<Uint8List?>(
                        future: _renderOnePage(index),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Color(0xFF1A73E8),
                                ),
                              ),
                            );
                          }
                          if (!snap.hasData || snap.data == null) {
                            return const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey, size: 30),
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              snap.data!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              // ✅ ลด memory ของ image decoder
                              cacheWidth: 150,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF1A73E8)
                              : (isDark
                                  ? Colors.white60
                                  : Colors.black54),
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

  Widget _buildPDFViewer(Uint8List pdfBytes) {
    return SfPdfViewer.memory(
      pdfBytes,
      key: const ValueKey('merged_pdf'),
      controller: _controller,
      pageLayoutMode: PdfPageLayoutMode.continuous,
      scrollDirection: PdfScrollDirection.vertical,
      canShowScrollHead: true,
      onDocumentLoaded: (details) {
        setState(() => _totalPages = details.document.pages.count);
      },
      onPageChanged: (details) {
        setState(() {
          _currentPage = details.newPageNumber;
          _selectedThumbnail = details.newPageNumber - 1;
        });
      },
    );
  }
}

class _PDFData {
  final Uint8List mergedBytes;
  final int pageCount;
  const _PDFData({required this.mergedBytes, required this.pageCount});
}