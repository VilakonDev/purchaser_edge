import 'package:flutter/material.dart';
import 'package:purchaser_edge/screens/home_screen.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/text_filed_widget.dart';
import 'package:unicons/unicons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorService().mainBackGroundColor,
      body: Center(
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
                "ລະບົບຈັດຊື້ TCR HOME STORE",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorService().mainTextColor,
                ),
              ),
              TextFiledWidget(
                label: 'ຊື່ຜູ້ໃຊ້',
                controller: TextEditingController(),
              ),
              TextFiledWidget(
                label: 'ລະຫັດຜ່ານ',
                controller: TextEditingController(),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: ColorService().mainGredientColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 10,
                    children: [
                      Text(
                        'ເຂົ້າສູ່ລະບົບ',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Icon(UniconsLine.sign_out_alt, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
