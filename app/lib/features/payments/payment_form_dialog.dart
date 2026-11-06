import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/core/widgets/adaptive_form_dialog.dart';
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
    this.initialBill,
  });

  final AppDatabase database;
  final List<Bill> bills;
  final Bill? initialBill;

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
    _selectedBill = widget.initialBill != null &&
            widget.bills.any((b) => b.id == widget.initialBill!.id)
        ? widget.bills.firstWhere((b) => b.id == widget.initialBill!.id)
        : (widget.initialBill ?? widget.bills.first);
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
    return AdaptiveFormDialog(
      maxHeight: 700,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            AdaptiveFormHeader(
              title: 'Catat pembayaran',
              subtitle:
                  'Simpan pembayaran sebagai riwayat terpisah dari tagihan.',
              icon: Icons.payments_outlined,
              onClose: _saving ? null : () => Navigator.of(context).pop(false),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FormSectionLabel('Informasi pembayaran'),
                      DropdownButtonFormField<Bill>(
                        key: const ValueKey('payment-bill-field'),
                        initialValue: _selectedBill,
                        isExpanded: true,
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
                          helperText: 'Masukkan angka tanpa titik atau koma.',
                          helperMaxLines: 2,
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
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _amountController,
                        builder: (context, value, _) {
                          final amount = int.tryParse(value.text);
                          if (amount == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Terbaca sebagai ${formatMoney(Money(minorUnits: amount, currency: _selectedBill.amount.currency))}',
                              key: const ValueKey('payment-amount-preview'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const FormSectionLabel('Jadwal'),
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
                      const SizedBox(height: 24),
                      const FormSectionLabel('Catatan'),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AdaptiveFormActions(
          saveKey: const ValueKey('save-payment-button'),
          saving: _saving,
          onCancel: _saving ? null : () => Navigator.of(context).pop(false),
          onSave: _saving ? null : _save,
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
        borderRadius: BorderRadius.circular(10),
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
