import 'package:flutter/material.dart';

/// Input for the customer name / key that labels the generated report.
/// Presentation-only; the value is owned by the page via [controller].
class CustomerKeyField extends StatelessWidget {
  const CustomerKeyField({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.none,
      decoration: const InputDecoration(
        labelText: 'Customer name / key',
        hintText: 'e.g. john-doe',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
    );
  }
}
