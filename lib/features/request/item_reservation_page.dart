import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/notifications/notification_data.dart';
import 'package:new_nutilize_mobile/features/notifications/notification_page.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';

class ItemReservationPage extends StatefulWidget {
  const ItemReservationPage({super.key});

  @override
  State<ItemReservationPage> createState() => _ItemReservationPageState();
}

class _ItemReservationPageState extends State<ItemReservationPage> {
  final List<String> _itemOptions = <String>[
    'TV',
    'Tables',
    'Chairs',
    'Podium',
    'Speaker',
    'Monitor',
  ];

  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  String? _selectedItem;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _quantity = 1;
  bool _submitted = false;

  @override
  void dispose() {
    _purposeController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF35489A),
            onPrimary: Colors.white,
            onSurface: Color(0xFF35489A),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _dateController.text =
          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  Future<void> _pickTime({required bool isStartTime}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF35489A),
            onPrimary: Colors.white,
            onSurface: Color(0xFF35489A),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStartTime) {
        _startTime = picked;
        _startTimeController.text = _formatTimeOfDay(picked);
      } else {
        _endTime = picked;
        _endTimeController.text = _formatTimeOfDay(picked);
      }
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }

  void _adjustQuantity(int delta) {
    setState(() {
      final next = _quantity + delta;
      if (next < 1) {
        return;
      }
      _quantity = next;
    });
  }

  void _submitRequest() {
    if (_selectedItem == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null ||
        _purposeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    final reservation = ReservationRecord(
      id: 'item-${DateTime.now().microsecondsSinceEpoch}',
      date: _selectedDate!,
      roomName: _selectedItem!,
      reservationType: 'Item Reservation',
      reservationTitle: _purposeController.text.trim(),
      reservationTime:
          '${_formatTimeOfDay(_startTime!)} - ${_formatTimeOfDay(_endTime!)}',
      reservationStatus: 'Pending Approval',
      roomNumber: 'Qty $_quantity',
      approvalState: ReservationApprovalState.pending,
      approvalTimeline: const [
        ReservationTimelineEntry(
          timestamp: '12:01 AM',
          title: 'Request Submitted',
          description: 'Your item reservation request has been submitted.',
          isCompleted: true,
        ),
        ReservationTimelineEntry(
          timestamp: 'Pending',
          title: 'Request Logged',
          description:
              'Your item reservation request will be reviewed by the team.',
          isCompleted: false,
        ),
      ],
    );

    ReservationActivityStore.addReservation(reservation);
    NotificationCenterStore.addReservationSubmittedNotification(reservation);

    setState(() {
      _submitted = true;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xD9000000),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6EAF9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF35B556),
                    size: 42,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Item Reservation Submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your $_selectedItem request has been sent for approval.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF35489A),
                          side: const BorderSide(color: Color(0xFF94A0D1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Close'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'NUtilize',
              onNotificationTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationPage()),
                );
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Item Reservation',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reserve equipment and movable items with the same familiar workflow.',
                      style: TextStyle(
                        color: Color(0xFF6A6F86),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionCard(
                      title: 'Choose Item',
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _itemOptions
                            .map(
                              (item) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedItem = item;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedItem == item
                                        ? const Color(0xFFF6C914)
                                        : const Color(0xFFF5F6FB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _selectedItem == item
                                          ? const Color(0xFFF6C914)
                                          : const Color(0xFFD9DEEE),
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: _selectedItem == item
                                          ? const Color(0xFF1A2254)
                                          : const Color(0xFF35489A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionCard(
                      title: 'Quantity',
                      child: Row(
                        children: [
                          _circleActionButton(
                            icon: Icons.remove_rounded,
                            onTap: () => _adjustQuantity(-1),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 84,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD9DEEE),
                              ),
                            ),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          _circleActionButton(
                            icon: Icons.add_rounded,
                            onTap: () => _adjustQuantity(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionCard(
                      title: 'Schedule',
                      child: Column(
                        children: [
                          _inputButton(
                            label: 'Date',
                            value: _dateController.text,
                            icon: Icons.calendar_month_rounded,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _inputButton(
                                  label: 'Start Time',
                                  value: _startTimeController.text,
                                  icon: Icons.schedule_rounded,
                                  onTap: () => _pickTime(isStartTime: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _inputButton(
                                  label: 'End Time',
                                  value: _endTimeController.text,
                                  icon: Icons.schedule_rounded,
                                  onTap: () => _pickTime(isStartTime: false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionCard(
                      title: 'Purpose',
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD9DEEE)),
                        ),
                        child: TextField(
                          controller: _purposeController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                'Describe what the item will be used for...',
                            hintStyle: TextStyle(
                              color: Color(0xFF8F95A6),
                              fontSize: 13,
                            ),
                            contentPadding: EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7D8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF6C914)),
                      ),
                      child: const Text(
                        'Please return all borrowed items in good condition after use.',
                        style: TextStyle(
                          color: Color(0xFF1A2254),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitted ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6C914),
                          foregroundColor: const Color(0xFF1A2254),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            'Submit Item Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: 2,
              onTap: (index) {
                if (index == 0) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarPage()),
                  );
                } else if (index == 2) {
                  Navigator.of(context).pop();
                } else if (index == 3) {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const UserPage()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4053A7),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _circleActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF35489A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _inputButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD9DEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6A6F86),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, color: const Color(0xFF35489A), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Select' : value,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
