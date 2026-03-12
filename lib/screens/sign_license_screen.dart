import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/main.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/text_filed_widget.dart';
import 'package:unicons/unicons.dart';

class SignLicenseScreen extends StatefulWidget {
  const SignLicenseScreen({super.key});

  @override
  State<SignLicenseScreen> createState() => _SignLicenseScreenState();
}

class _SignLicenseScreenState extends State<SignLicenseScreen> {
  final licenseKeyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(  // ✅ ลบ Expanded ออก
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
                  isHidden: false,
                  controller: licenseKeyController,
                ),
                GestureDetector(
                  onTap: () async {
                    bool success = await context
                        .read<AuthProvider>()
                        .activateLicense(licenseKeyController.text.trim());

                    if (success) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                      );
                    }
                  },
                  child: Container(
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
                        Icon(UniconsLine.key_skeleton, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}