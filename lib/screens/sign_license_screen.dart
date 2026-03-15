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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorService().primaryColor.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade800.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            top: 180,
            right: 200,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.withOpacity(0.08),
              ),
            ),
          ),

          // Main content
          Center(
            child: Container(
              width: 460,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 60,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                 

                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 36, 36, 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: ColorService().mainGredientColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: ColorService()
                                    .primaryColor
                                    .withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            UniconsLine.key_skeleton_alt,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Title
                        Text(
                          'ກວດສອບໃບອະນຸຍາດ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ກະລຸນາໃສ່ License Key\nເພື່ອເປີດໃຊ້ງານລະບົບ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                                child:
                                    Divider(color: Colors.grey.shade100)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  'License Key',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                                child:
                                    Divider(color: Colors.grey.shade100)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Input
                        TextFiledWidget(
                          label: 'Key',
                          isHidden: false,
                          controller: licenseKeyController,
                        ),

                        const SizedBox(height: 24),

                        // Submit button
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () async {
                                  final key =
                                      licenseKeyController.text.trim();
                                  if (key.isEmpty) return;

                                  setState(() => _isLoading = true);

                                  final success = await context
                                      .read<AuthProvider>()
                                      .activateLicense(key);

                                  if (!mounted) return;
                                  setState(() => _isLoading = false);

                                  if (success) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const AuthPage()),
                                    );
                                  }
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: _isLoading
                                  ? LinearGradient(colors: [
                                      Colors.grey.shade300,
                                      Colors.grey.shade300,
                                    ])
                                  : ColorService().mainGredientColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: _isLoading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: ColorService()
                                            .primaryColor
                                            .withOpacity(0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Text(
                                          'ຢືນຢັນລະຫັດ',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(UniconsLine.arrow_right,
                                            color: Colors.white, size: 20),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Footer
                        Text(
                          '© 2025 WorkStation Flow. All rights reserved.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
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
}