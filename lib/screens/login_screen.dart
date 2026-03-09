import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchaser_edge/providers/auth_provider.dart';
import 'package:purchaser_edge/screens/home_screen.dart';
import 'package:purchaser_edge/services/color_service.dart';
import 'package:purchaser_edge/widgets/alert_dialog_widget.dart';
import 'package:purchaser_edge/widgets/text_filed_widget.dart';
import 'package:unicons/unicons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

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
                        controller: usernameController,
                      ),
                      TextFiledWidget(
                        label: 'ລະຫັດຜ່ານ',
                        controller: passwordController,
                      ),
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: () async {
                          final username = usernameController.text.trim();
                          final password = passwordController.text.trim();

                          if (username.isEmpty ||
                              username == "" ||
                              password.isEmpty ||
                              password == "")
                            return;

                          if (username == "Admin" &&
                              password == "setupConnection") {
                            showDialog(
                              context: context,
                              builder: (_) => _buildSetupConnection(),
                            );
                          } else {
                            bool isLogin = await context
                                .read<AuthProvider>()
                                .login(context, username, password);

                            if (isLogin) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => HomeScreen()),
                              );
                            } else {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialogWidget(type: "error",textContent:'ຊື່ຜູ້ໃຊ້ ຫຼື ລະຫັດຜ່ານ ບໍ່ຖືກຕ້ອງ',),
                              );
                            }
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
                                'ເຂົ້າສູ່ລະບົບ',
                                style: TextStyle(color: Colors.white),
                              ),
                              Icon(
                                UniconsLine.sign_out_alt,
                                color: Colors.white,
                              ),
                            ],
                          ),
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

  Widget _buildSetupConnection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 500,

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 50,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: ColorService().mainGredientColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ຈັດການການເຊື່ອມຕໍ່',
                        style: TextStyle(color: Colors.white),
                      ),
                      Icon(UniconsLine.server_connection, color: Colors.white),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    spacing: 10,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          Expanded(
                            child: TextFiledWidget(
                              label: 'ຊື່',
                              controller: TextEditingController(),
                            ),
                          ),
                          Expanded(
                            child: TextFiledWidget(
                              label: 'IP Address',
                              controller: TextEditingController(),
                            ),
                          ),
                          Column(
                            children: [
                              SizedBox(height: 40),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: ColorService().mainGredientColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Icon(
                                    UniconsLine.plus,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: ListView.builder(
                          itemCount: 10,
                          itemBuilder: (context, index) {
                            return Container(
                              width: double.infinity,
                              margin: EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    width: 1,
                                    color: ColorService().mainTextFiledColor,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('TCR HOME STORE VTE 02'),
                                      Text('192.168.1.142'),
                                    ],
                                  ),
                                  Icon(
                                    UniconsLine.trash,
                                    color: ColorService().errorColor,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        spacing: 10,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                spacing: 10,
                                children: [
                                  Text(
                                    'ຍົກເລີກ',
                                    style: TextStyle(
                                      color: ColorService().mainTextColor,
                                    ),
                                  ),
                                  Icon(
                                    UniconsLine.times,
                                    color: ColorService().mainTextColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: ColorService().mainGredientColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              spacing: 10,
                              children: [
                                Text(
                                  'ບັນທິກ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Icon(UniconsLine.save, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
