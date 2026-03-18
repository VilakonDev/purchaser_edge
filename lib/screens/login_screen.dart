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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // ── Left panel ─────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Dark background
                Container(color: const Color(0xFF0F172A)),

                // Decorative blobs
                Positioned(
                  top: -100,
                  left: -100,
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
                  bottom: -80,
                  right: -80,
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
                  top: 200,
                  right: 60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.indigo.withOpacity(0.1),
                    ),
                  ),
                ),

                // Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo / Icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: ColorService().mainGredientColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: ColorService()
                                  .primaryColor
                                  .withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          UniconsLine.layer_group,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'WorkStation\nFlow',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'ລະບົບຈັດການເອກະສານ\nສັ່ງຊື້ອັດຕະໂນມັດ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.5),
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Feature pills
                      _featurePill(UniconsLine.file_check_alt,
                          'ຈັດການເອກະສານ PO'),
                      const SizedBox(height: 12),
                      _featurePill(
                          UniconsLine.check_circle, 'ອະນຸມັດຫຼາຍລຳດັບຊັ້ນ'),
                      const SizedBox(height: 12),
                      _featurePill(
                          UniconsLine.chart_line, 'ຕິດຕາມສະຖານະ Real-time'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Right panel ─────────────────────────────────────────
          Container(
            width: 480,
            height: double.infinity,
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'ຍິນດີຕ້ອນຮັບ 👋',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ກະລຸນາເຂົ້າສູ່ລະບົບດ້ວຍບັນຊີຂອງທ່ານ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Username field
                    
                    const SizedBox(height: 8),
                    TextFiledWidget(
                      label: 'ຊື່ຜູ້ໃຊ້',
                      isHidden: false,
                      controller: usernameController,
                    ),

                    const SizedBox(height: 16),

                    // Password field
                   
                    const SizedBox(height: 8),
                    TextFiledWidget(
                      label: 'ລະຫັດຜ່ານ',
                      isHidden: true,
                      controller: passwordController,
                    ),

                    const SizedBox(height: 32),

                    // Login button
                    GestureDetector(
                      onTap: _isLoading ? null : _handleLogin,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'ເຂົ້າສູ່ລະບົບ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
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

                    const SizedBox(height: 40),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: Colors.grey.shade200)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ຫຼື',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: Colors.grey.shade200)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Setup connection button
                   

                    const SizedBox(height: 40),

                    // Footer
                    Center(
                      child: Text(
                        '© 2025 WorkStation Flow. All rights reserved.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.white70),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  

  Future<void> _handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) return;

    if (username == "Admin" && password == "setupConnection") {
      showDialog(
        context: context,
        builder: (_) => _buildSetupConnection(),
      );
      return;
    }

    setState(() => _isLoading = true);

    final isLogin = await context
        .read<AuthProvider>()
        .login(context, username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (isLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialogWidget(
          type: "error",
          textContent: 'ຊື່ຜູ້ໃຊ້ ຫຼື ລະຫັດຜ່ານ ບໍ່ຖືກຕ້ອງ',
        ),
      );
    }
  }

  Widget _buildSetupConnection() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 520,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ColorService().mainGredientColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        UniconsLine.server_connection,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ຈັດການການເຊື່ອມຕໍ່ Server',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add row
                    Row(
                      children: [
                        Expanded(
                          child: TextFiledWidget(
                            label: 'ຊື່ສາຂາ',
                            isHidden: false,
                            controller: TextEditingController(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFiledWidget(
                            label: 'IP Address',
                            isHidden: false,
                            controller: TextEditingController(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            const SizedBox(height: 22),
                            GestureDetector(
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient:
                                      ColorService().mainGredientColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(UniconsLine.plus,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // List header
                    Row(
                      children: [
                        Icon(UniconsLine.list_ul,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          'ລາຍການ Server',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // List
                    Container(
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: 10,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: ColorService()
                                        .primaryColor
                                        .withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    UniconsLine.server,
                                    size: 16,
                                    color: ColorService().primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TCR HOME STORE VTE 02',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '192.168.1.142',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: ColorService()
                                        .errorColor
                                        .withOpacity(0.08),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    UniconsLine.trash_alt,
                                    size: 14,
                                    color: ColorService().errorColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(UniconsLine.times,
                                    size: 16,
                                    color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'ຍົກເລີກ',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: ColorService().mainGredientColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: ColorService()
                                    .primaryColor
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: const [
                              Icon(UniconsLine.save,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'ບັນທຶກ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
    );
  }
}