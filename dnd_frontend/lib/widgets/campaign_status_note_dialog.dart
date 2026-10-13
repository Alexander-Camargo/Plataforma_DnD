import 'package:flutter/material.dart';

/// El controlador vive hasta que el diálogo termina su animación de salida.
class CampaignStatusNoteDialog extends StatefulWidget {
  final String statusLabel;
  const CampaignStatusNoteDialog({super.key, required this.statusLabel});

  @override
  State<CampaignStatusNoteDialog> createState() =>
      _CampaignStatusNoteDialogState();
}

class _CampaignStatusNoteDialogState extends State<CampaignStatusNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Marcar como: ${widget.statusLabel}'),
      content: TextField(
        controller: _controller,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Nota (opcional)'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const Text('Confirmar')),
      ],
    );
  }
}
