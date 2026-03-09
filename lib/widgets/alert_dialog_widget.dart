import 'package:flutter/material.dart';

class AlertDialogWidget extends StatefulWidget {
  const AlertDialogWidget({
    required this.type,
    required this.textContent,
    super.key,
  });

  final String type;
  final String textContent;

  @override
  State<AlertDialogWidget> createState() => _AlertDialogWidgetState();
}

class _AlertDialogWidgetState extends State<AlertDialogWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(20),
          width: 500,

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: Column(
              spacing: 20,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: widget.type == "error"
                          ? NetworkImage(
                              'https://cdn3d.iconscout.com/3d/premium/thumb/error-3d-icon-png-download-12692245.png',
                            )
                          : NetworkImage(
                              'https://cdn3d.iconscout.com/3d/premium/thumb/successfully-done-3d-icon-png-download-4288033.png',
                            ),
                    ),
                  ),
                ),
                Text(
                  widget.type == "error" ? "ມີຂໍ້ຜິດພາດ" : "ດຳເນີນການສຳເລັດ",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(widget.textContent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
