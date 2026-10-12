import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

class BillFormDialog extends StatefulWidget {
  const BillFormDialog({super.key, required this.database, this.bill});

  final AppDatabase database;
  final Bill? bill;

  @override
  State<BillFormDialog> createState() => _BillFormDialogState();
}

class _BillFormDialogState extends State<BillFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late BillingCycle _billingCycle;
  late CalendarDate _startDate;
  late CalendarDate _nextDueDate;
  var _saving = false;

  bool get _editing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    final today = CalendarDate.fromDateTime(DateTime.now());
    _nameController = TextEditingController(text: bill?.name);
    _categoryController = TextEditingController(text: bill?.category);
    _amountController = TextEditingController(
      text: bill?.amount.minorUnits.toString(),
    );
    _notesController = TextEditingController(text: bill?.notes);
    _billingCycle = bill?.billingCycle ?? BillingCycle.monthly;
    _startDate = bill?.startDate ?? today;
    _nextDueDate = bill?.nextDueDate ?? today;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool startDate}) async {
    final current = startDate ? _startDate : _nextDueDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.toUtcDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;
    setState(() {
      final date = CalendarDate.fromDateTime(selected);
      if (startDate) {
        _startDate = date;
        if (_nextDueDate.isBefore(date)) _nextDueDate = date;
      } else {
        _nextDueDate = date;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nextDueDate.isBefore(_startDate)) {
      _showError('Jatuh tempo tidak boleh sebelum tanggal mulai.');
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = widget.bill;
      final now = DateTime.now().toUtc();
      final bill = Bill(
        id: existing?.id ?? EntityId.generate(now: now),
        name: _nameController.text.trim(),
        category: _nullableText(_categoryController.text),
        amount: Money(
          minorUnits: int.parse(_amountController.text),
          currency: Currency.idr,
        ),
        billingCycle: _billingCycle,
        startDate: _startDate,
        nextDueDate: _nextDueDate,
        status: existing?.status ?? BillStatus.active,
        notes: _nullableText(_notesController.text),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: existing?.deletedAt,
        version: existing == null ? 1 : existing.version + 1,
      );

      if (existing == null) {
        await widget.database.insertBill(bill);
      } else {
        await widget.database.updateBill(bill);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Tagihan tidak dapat disimpan. Coba lagi.');
      }
      debugPrint('Gagal menyimpan tagihan: ${error.runtimeType}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Edit tagihan' : 'Tambah tagihan',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const ValueKey('bill-name-field'),
                        controller: _nameController,
                        autofocus: !_editing,
                        decoration: const InputDecoration(
                          labelText: 'Nama tagihan',
                          hintText: 'Contoh: Spotify',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Nama tagihan wajib diisi.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Kategori (opsional)',
                          hintText: 'Contoh: Hiburan',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const ValueKey('bill-amount-field'),
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Nominal (IDR)',
                          prefixText: 'Rp ',
                          helperText: 'Masukkan angka tanpa titik atau koma.',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nominal wajib diisi.';
                          }
                          return int.tryParse(value) == null
                              ? 'Nominal tidak valid.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<BillingCycle>(
                        key: const ValueKey('bill-cycle-field'),
                        initialValue: _billingCycle,
                        decoration: const InputDecoration(
                          labelText: 'Siklus tagihan',
                        ),
                        items: [
                          for (final cycle in BillingCycle.values)
                            DropdownMenuItem(
                              value: cycle,
                              child: Text(_billingCycleLabel(cycle)),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _billingCycle = value);
                                }
                              },
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _DateField(
                            label: 'Tanggal mulai',
                            value: _startDate,
                            onTap: _saving
                                ? null
                                : () => _pickDate(startDate: true),
                          ),
                          _DateField(
                            label: 'Jatuh tempo berikutnya',
                            value: _nextDueDate,
                            onTap: _saving
                                ? null
                                : () => _pickDate(startDate: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            key: const ValueKey('save-bill-button'),
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final CalendarDate value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          ),
          child: Text(_formatDate(value)),
        ),
      ),
    );
  }
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _billingCycleLabel(BillingCycle cycle) {
  return switch (cycle) {
    BillingCycle.oneTime => 'Satu kali',
    BillingCycle.weekly => 'Mingguan',
    BillingCycle.monthly => 'Bulanan',
    BillingCycle.yearly => 'Tahunan',
  };
}

String _formatDate(CalendarDate date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
