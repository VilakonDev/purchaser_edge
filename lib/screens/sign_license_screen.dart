import 'package:flutter/material.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/text_filed_widget.dart';
import 'package:unicons/unicons.dart';

class SignLicenseScreen extends StatefulWidget {
  const SignLicenseScreen({super.key});

  @override
  State<SignLicenseScreen> createState() => _SignLicenseScreenState();
}

class _SignLicenseScreenState extends State<SignLicenseScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Expanded(
        child: Container(
          decoration: BoxDecoration(gradient: ColorService().mainGredientColor),
          child: Center(
            child: Container(
              padding: EdgeInsets.all(20),
              width: 500,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 20,
                children: [
                  Text(
                    'ລະຫັດຢືນຢັນການໃຊ້ງານ',
                    style: TextStyle(
                      color: ColorService().mainTextColor,
                      fontSize: 16,
                    ),
                  ),
                  TextFiledWidget(
                    label: 'LicenseKey',
                    controller: TextEditingController(),
                  ),
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: ColorService().mainGredientColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [
                        Text(
                          'ຢືນຢັນລະຫັດ',
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(UniconsLine.key_skeleton,color: Colors.white,)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
