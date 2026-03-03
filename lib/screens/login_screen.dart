import 'package:flutter/material.dart';
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
      body: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ColorService().mainBackGroundColor,
              ),
              child: Center(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: NetworkImage(
                        'https://cdn3d.iconscout.com/3d/premium/thumb/business-process-and-workflow-3d-icon-png-download-4367787.png',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                gradient: ColorService().mainGredientColor,
              ),
              child: Center(
                child: Container(
                  width: 380,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ເຂົ້າສູ່ລະບົບ | WorkStation Flow',
                        style: TextStyle(
                          fontSize: 18,
                          color: ColorService().mainTextColor,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextFiledWidget(
                        label: 'ຊື່ຜູ້ໃຊ້',
                        controller: TextEditingController(),
                      ),
                      TextFiledWidget(
                        label: 'ລະຫັດຜ່ານ',
                        controller: TextEditingController(),
                      ),
                      SizedBox(height: 20),
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
                              'ເຂົ້າສູ່ລະບົບ',
                              style: TextStyle(color: Colors.white),
                            ),
                            Icon(UniconsLine.sign_out_alt, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
