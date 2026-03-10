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
      child: ListView(
        children: [
          AppBarWidget(label: 'ໜ້າຫຼັກ', widget: Container()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              spacing: 20,
              children: [
                _buildSummaryCard(),
                Row(
                  spacing: 20,
                  children: [
                    _buildPieChart(),
                    _buildChart(),
                    _buildNotification(),
                  ],
                ),

                Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    Widget SummaryCard(
      Color color,
      String label,
      int itemCount,
      IconData icon,
    ) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color, Colors.grey.shade400],
              begin: AlignmentGeometry.topCenter,
              end: AlignmentGeometry.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Icon(icon, size: 30, color: color)),
              ),
              Text(label, style: TextStyle(color: Colors.white, fontSize: 16)),
              Text(
                itemCount.toString(),
                style: TextStyle(color: Colors.white, fontSize: 30),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 200,
      child: Row(
        spacing: 20,
        children: [
          SummaryCard(
            ColorService().primaryColor,
            'ເອກະສານທັງໝົດ',
            context.watch<DocumentProvider>().documents.length,
            UniconsLine.file_alt,
          ),
          SummaryCard(
            ColorService().warningColor,
            'ເອກະສານລໍຖ້າອະນຸມັດ',
            context.watch<DocumentProvider>().pendingDocument.length +
                context.watch<DocumentProvider>().dmApprovedDocument.length,
            UniconsLine.clock,
          ),
          SummaryCard(
            ColorService().successColor,
            'ເອກະສານອະນຸມັດແລ້ວ',
            context.watch<DocumentProvider>().directorApproved.length,
            UniconsLine.check,
          ),
          SummaryCard(
            ColorService().errorColor,
            'ເອກະສານຕີກັບ',
            120,
            UniconsLine.times,
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return Container(
      padding: EdgeInsets.all(20),

      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ສະຖານະເອກະສານ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: ColorService().mainTextColor,
            ),
          ),
          Container(
            width: 300,
            height: 300,
            child: PieChartSz(
              colors: [
                ColorService().primaryColor,
                ColorService().warningColor,
                ColorService().successColor,
                ColorService().errorColor,
              ],
              values: [
                context.watch<DocumentProvider>().documents.length.toDouble(),

                context
                    .watch<DocumentProvider>()
                    .pendingDocument
                    .length
                    .toDouble(),
                context
                    .watch<DocumentProvider>()
                    .directorApproved
                    .length
                    .toDouble(),
                2,
              ],
              gapSize: 0.15,
              centerText: "",
              centerTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              valueSettings: Valuesettings(
                showValues: false,
                ValueTextStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Expanded(
      flex: 3,
      child: Container(
        padding: EdgeInsets.all(20),
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ລາຍການເອກະສານສັ່ງຊື້ລາຍເດືອນ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: ColorService().mainTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: const MajorGridLines(
                    width: 1,
                    dashArray: [4, 4],
                    color: Color(0xFFE0E0E0),
                  ),
                  axisLine: const AxisLine(width: 0),
                  labelFormat: '{value}',
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MonthlyBuyModel, String>(
                    dataSource: context.read<DocumentProvider>().getMonthlyBuy(),
                    xValueMapper: (MonthlyBuyModel data, _) => data.month,
                    yValueMapper: (MonthlyBuyModel data, _) => data.sales,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    color: Colors.blue.shade300, // หรือสีที่ต้องการ
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotification() {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),

        height: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ການແຈ້ງເຕືອນ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: ColorService().mainTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
