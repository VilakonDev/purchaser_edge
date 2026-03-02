import 'package:flutter/material.dart';
import 'package:purchaser_edge/services/color_service.dart';


class DropDownWidget extends StatefulWidget {
  const DropDownWidget({
    required this.label,
    required this.items,
    this.width = 0,
    this.onChanged,
    super.key,
  });

  final String label;
  final List<String> items;
  final double width;
  final Function(String?)? onChanged; // callback ส่งค่าไป parent

  @override
  State<DropDownWidget> createState() => _DropDownWidgetState();
}

class _DropDownWidgetState extends State<DropDownWidget> {
  String? selectedValue;

  @override
  Widget build(BuildContext context) {
    Widget dropdown = SizedBox(
      width: widget.width == 0 ? double.infinity : widget.width,
      height: 40,
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: (val) {
          setState(() {
            selectedValue = val;
          });
          if (widget.onChanged != null) {
            widget.onChanged!(val); // ส่งค่าใหม่ไป parent
          }
        },
        decoration: InputDecoration(
          filled: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          fillColor: ColorService().mainTextFiledColor,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.transparent),
            borderRadius: BorderRadius.circular(5),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.transparent),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        items: widget.items
            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
            .toList(),
      ),
    );

    return widget.width == 0
        ? Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label),
                const SizedBox(height: 5),
                dropdown,
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(widget.label), const SizedBox(height: 5), dropdown],
          );
  }
}
