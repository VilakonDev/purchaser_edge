import 'package:flutter/material.dart';
import 'package:purchaser_edge/services/color_service.dart';

class DropDownWidget extends StatefulWidget {
  const DropDownWidget({
    required this.label,
    required this.items,
    this.onChanged,
    super.key,
  });

  final String label;
  final List<String> items;
  final Function(String?)? onChanged;

  @override
  State<DropDownWidget> createState() => _DropDownWidgetState();
}

class _DropDownWidgetState extends State<DropDownWidget> {
  String? selectedValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: DropdownButtonFormField<String>(
            initialValue: selectedValue,
            onChanged: (val) {
              setState(() => selectedValue = val);
              widget.onChanged?.call(val);
            },
            decoration: InputDecoration(
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              fillColor: ColorService().mainTextFiledColor,
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(5),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            items: widget.items
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
          ),
        ),
      ],
    );
  }
}