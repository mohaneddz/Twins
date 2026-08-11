import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TwinsInput extends StatefulWidget {
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? errorText;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const TwinsInput({
    super.key,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.errorText,
    this.prefixIcon,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<TwinsInput> createState() => _TwinsInputState();
}

class _TwinsInputState extends State<TwinsInput> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(widget.prefixIcon, size: 20),
              )
            : null,
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(_hidden ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 20),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
