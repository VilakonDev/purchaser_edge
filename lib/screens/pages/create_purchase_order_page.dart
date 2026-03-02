import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:purchaser_edge/screens/pages/text_filed_widget.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/app_bar_widget.dart';
import 'package:purchaser_edge/widgets/drop_down_widget.dart';
import 'package:unicons/unicons.dart';

class CreatePurchaseOrderPage extends StatefulWidget {
  const CreatePurchaseOrderPage({super.key});

  @override
  State<CreatePurchaseOrderPage> createState() =>
      _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ColorService().mainBackGroundColor),
      child: ListView(
        children: [
          AppBarWidget(label: 'ສ້າງເອກະສານສັ່ງຊື້', widget: Container()),
          Expanded(
            child: Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
              child: Column(
                spacing: 20,
                children: [
                  _buildDocumentInfo(),
                  Container(
                    height: 700,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ແນບຟາຍເອກະສານ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: ColorService().mainTextColor,
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            color: ColorService().mainTextFiledColor,
                            border: Border.all(
                              color: ColorService().borderTextFiledColor,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                UniconsLine.cloud_upload,
                                size: 120,
                                color: ColorService().mainTextColor,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: 20,
                                children: [
                                  Text(
                                    'ລາກ ແລະ ວາງຟາຍ ຫຼື',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: ColorService().mainTextColor,
                                    ),
                                  ),
                                  Text(
                                    'ກົດເພື່ອເລືອກຟາຍ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: ColorService().primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: ColorService().mainBackGroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        _buildBottomButton(),
                      ],
                    ),
                  ),
                  Container(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        spacing: 20,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ລາຍລະອຽດເອກະສານ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: ColorService().mainTextColor,
            ),
          ),
          TextFiledWidget(
            label: 'ຊື່ເອກະສານ',
            controller: TextEditingController(),
          ),
          Row(
            spacing: 20,
            children: [
              Expanded(
                child: DropDownWidget(
                  label: 'ກຸ່ມເອກະສານ',
                  items: ['HT.PT.HO', 'PA.HW.DW.DM'],
                ),
              ),
              Expanded(
                child: DropDownWidget(
                  label: 'ກຸ່ມເອກະສານ',
                  items: ['HT.PT.HO', 'PA.HW.DW.DM'],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentGeometry.centerEnd,
                  child: Text(
                    DateFormat('EEE, M/d/y').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 16,
                      color: ColorService().mainTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      width: double.infinity,
      height: 50,

      child: Row(
        spacing: 20,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(
                width: 2,
                color: ColorService().mainTextFiledColor,
              ),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              spacing: 10,
              children: [
                Icon(UniconsLine.times, color: ColorService().mainTextColor),
                Text(
                  'ຍົກເລີກ',
                  style: TextStyle(
                    color: ColorService().mainTextColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              height: 50,
              decoration: BoxDecoration(
                color: ColorService().primaryColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                spacing: 10,
                children: [
                  Text(
                    'ບັນທຶກເອກະສານ',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Icon(UniconsLine.save, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
