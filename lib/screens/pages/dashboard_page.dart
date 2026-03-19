import 'package:flutter/material.dart';
import 'package:pie_chart_sz/ValueSettings.dart';
import 'package:pie_chart_sz/pie_chart_sz.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/model/monthly_buy_model.dart';
import 'package:purchaser_edge/providers/document_provider.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/app_bar_widget.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:unicons/unicons.dart';

class DashBoardPage extends StatefulWidget {
  const DashBoardPage({super.key});

  @override
  State<DashBoardPage> createState() => _DashBoardPageState();
}

class _DashBoardPageState extends State<DashBoardPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: Column(
        children: [
          AppBarWidget(label: 'ໜ້າຫຼັກ', widget: Container()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                _buildSummaryCards(),
                const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPieChart(),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildChart()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildNotification()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary cards ──────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final documentProvider = context.watch<DocumentProvider>();

    final cards = [
      _SummaryData(
        label: 'ເອກະສານທັງໝົດ',
        sublabel: 'ທຸກສະຖານະ',
        count: documentProvider.documents.length,
        icon: UniconsLine.file_alt,
        color: const Color(0xFF2563EB),
      ),
      _SummaryData(
        label: 'ລໍຖ້າອະນຸມັດ',
        sublabel: 'ຍັງບໍ່ດຳເນີນການ',
        count:
            documentProvider.pendingDocument.length +
            documentProvider.dmApprovedDocument.length,
        icon: UniconsLine.clock,
        color: const Color(0xFFF59E0B),
      ),
      _SummaryData(
        label: 'ອະນຸມັດແລ້ວ',
        sublabel: 'ດຳເນີນການສຳເລັດ',
        count: documentProvider.directorApproved.length,
        icon: UniconsLine.check_circle,
        color: const Color(0xFF10B981),
      ),
      _SummaryData(
        label: 'ຕີກັບ',
        sublabel: 'ຕ້ອງດຳເນີນການໃໝ່',
        count: documentProvider.rejectedDocument.length,
        icon: UniconsLine.times_circle,
        color: const Color(0xFFEF4444),
      ),
    ];

    return Row(
      children: List.generate(cards.length, (i) {
        final card = cards[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < cards.length - 1 ? 16 : 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: card.color.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Left accent bar
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 5, color: card.color),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Row(
                      children: [
                        // Icon box
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: card.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(card.icon, size: 24, color: card.color),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.count.toString(),
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: card.color,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                card.sublabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Trend arrow
                        Icon(
                          UniconsLine.arrow_up_right,
                          size: 16,
                          color: card.color.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Pie chart ──────────────────────────────────────────────────
  Widget _buildPieChart() {
    final documentProvider = context.watch<DocumentProvider>();

    final legends = [
      _LegendData(
        'ທັງໝົດ',
        const Color(0xFF2563EB),
        documentProvider.documents.length,
      ),
      _LegendData(
        'ລໍຖ້າ',
        const Color(0xFFF59E0B),
        documentProvider.pendingDocument.length,
      ),
      _LegendData(
        'ອະນຸມັດ',
        const Color(0xFF10B981),
        documentProvider.directorApproved.length,
      ),
      _LegendData(
        'ຕີກັບ',
        const Color(0xFFEF4444),
        documentProvider.rejectedDocument.length,
      ),
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  UniconsLine.chart_pie,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ສະຖານະເອກະສານ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: ColorService().mainTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart centered
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: PieChartSz(
                colors: const [
                  Color(0xFF2563EB),
                  Color(0xFFF59E0B),
                  Color(0xFF10B981),
                  Color(0xFFEF4444),
                ],
                values: [
                  documentProvider.documents.length.toDouble(),
                  documentProvider.pendingDocument.length.toDouble(),
                  documentProvider.directorApproved.length.toDouble(),
                  documentProvider.rejectedDocument.length.toDouble(),
                ],
                gapSize: 0.25,
                centerText: '',
                centerTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorService().mainTextColor,
                ),
                valueSettings: Valuesettings(
                  showValues: false,
                  ValueTextStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Legend rows
          ...legends.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: l.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: l.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${l.count}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: l.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bar chart ──────────────────────────────────────────────────
  Widget _buildChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      UniconsLine.chart_bar,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ລາຍການສັ່ງຊື້ລາຍເດືອນ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: ColorService().mainTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  '2025',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              margin: EdgeInsets.zero,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  width: 1,
                  dashArray: const [4, 4],
                  color: Colors.grey.shade100,
                ),
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                labelFormat: '{value}',
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                ),
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: const Color(0xFF1E40AF),
                textStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              series: <CartesianSeries>[
                ColumnSeries<MonthlyBuyModel, String>(
                  dataSource: context.read<DocumentProvider>().getMonthlyBuy(),
                  xValueMapper: (MonthlyBuyModel data, _) => data.month,
                  yValueMapper: (MonthlyBuyModel data, _) => data.sales,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  width: 0.5,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF93C5FD)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Notification ──────────────────────────────────────────────
  Widget _buildNotification() {
    final docs = context.watch<DocumentProvider>();
    final pending = docs.pendingDocument;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      UniconsLine.bell,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ການແຈ້ງເຕືອນ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: ColorService().mainTextColor,
                    ),
                  ),
                ],
              ),
              if (pending.isNotEmpty)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${pending.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),

          pending.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            UniconsLine.bell_slash,
                            size: 24,
                            color: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ບໍ່ມີການແຈ້ງເຕືອນ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ທຸກເອກະສານດຳເນີນການແລ້ວ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: List.generate(pending.length, (index) {
                    final doc = pending[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              UniconsLine.file_exclamation,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.documentTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ColorService().mainTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  doc.documentNumber,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ລໍຖ້າ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ],
      ),
    );
  }
}

// ── Helper models ──────────────────────────────────────────────────
class _SummaryData {
  final String label;
  final String sublabel;
  final int count;
  final IconData icon;
  final Color color;

  const _SummaryData({
    required this.label,
    required this.sublabel,
    required this.count,
    required this.icon,
    required this.color,
  });
}

class _LegendData {
  final String label;
  final Color color;
  final int count;
  const _LegendData(this.label, this.color, this.count);
}
