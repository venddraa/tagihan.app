import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

class PaymentFormDialog extends StatefulWidget {
  const PaymentFormDialog({
    super.key,
    required this.database,
    required this.bills,
  });

  final AppDatabase database;
  final List<Bill> bills;

  @override
  State<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late Bill _selectedBill;
  late CalendarDate _dueDate;
  late DateTime _paidAt;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBill = widget.bills.first;
    _dueDate = _selectedBill.nextDueDate;
    _paidAt = DateTime.now().toUtc();
    _amountController = TextEditingController(
      text: _selectedBill.amount.minorUnits.toString(),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectBill(Bill bill) {
    setState(() {
      _selectedBill = bill;
      _dueDate = bill.nextDueDate;
      _amountController.text = bill.amount.minorUnits.toString();
    });
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate.toUtcDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() => _dueDate = CalendarDate.fromDateTime(selected));
  }

  Future<void> _pickPaidAt() async {
    final currentLocal = _paidAt.toLocal();
    final selected = await showDatePicker(
      context: context,
      initialDate: currentLocal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _paidAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        currentLocal.hour,
        currentLocal.minute,
        currentLocal.second,
      ).toUtc();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc();
      final payment = Payment(
        id: EntityId.generate(now: now),
        billId: _selectedBill.id,
        amount: Money(
          minorUnits: int.parse(_amountController.text),
          currency: _selectedBill.amount.currency,
        ),
        dueDate: _dueDate,
        paidAt: _paidAt,
        notes: _nullableText(_notesController.text),
        createdAt: now,
        updatedAt: now,
        version: 1,
      );

      await widget.database.recordPayment(payment);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      debugPrint('Gagal mencatat pembayaran: ${error.runtimeType}');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Pembayaran tidak dapat disimpan. Coba lagi.'),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Catat pembayaran',
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
                      DropdownButtonFormField<Bill>(
                        key: const ValueKey('payment-bill-field'),
                        initialValue: _selectedBill,
                        decoration: const InputDecoration(labelText: 'Tagihan'),
                        items: [
                          for (final bill in widget.bills)
                            DropdownMenuItem(
                              value: bill,
                              child: Text(
                                bill.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (bill) {
                                if (bill != null) _selectBill(bill);
                              },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        key: const ValueKey('payment-amount-field'),
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText:
                              'Nominal (${_selectedBill.amount.currency.code})',
                          prefixText:
                              _selectedBill.amount.currency == Currency.idr
                              ? 'Rp '
                              : null,
                          helperText:
                              'Disimpan sebagai integer minor unit yang aman.',
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _DateField(
                            label: 'Periode jatuh tempo',
                            value: formatCalendarDate(_dueDate),
                            onTap: _saving ? null : _pickDueDate,
                          ),
                          _DateField(
                            label: 'Tanggal pembayaran',
                            value: formatDateTimeDate(_paidAt),
                            onTap: _saving ? null : _pickPaidAt,
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
                            key: const ValueKey('save-payment-button'),
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
  final String value;
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
          child: Text(value),
        ),
      ),
    );
  }
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
