import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_details_page.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/notifications/notification_page.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';

class ReservationHistoryPage extends StatefulWidget {
  const ReservationHistoryPage({super.key});

  @override
  State<ReservationHistoryPage> createState() => _ReservationHistoryPageState();
}

class _ReservationHistoryPageState extends State<ReservationHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  DateTime? _selectedDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = 'All';
      _selectedDate = null;
    });
  }

  List<ReservationRecord> _filterReservations(
    List<ReservationRecord> reservations,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = reservations.where((reservation) {
      final matchesQuery =
          query.isEmpty ||
          reservation.roomName.toLowerCase().contains(query) ||
          reservation.reservationTitle.toLowerCase().contains(query) ||
          reservation.reservationType.toLowerCase().contains(query) ||
          reservation.reservationTime.toLowerCase().contains(query);

      final matchesStatus =
          _selectedStatus == 'All' ||
          _statusMatches(reservation.reservationStatus, _selectedStatus);

      final matchesDate =
          _selectedDate == null ||
          _dateOnly(
            reservation.date,
          ).isAtSameMomentAs(_dateOnly(_selectedDate!));

      return matchesQuery && matchesStatus && matchesDate;
    }).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  bool _statusMatches(String status, String filter) {
    final normalizedStatus = status.toLowerCase();
    switch (filter.toLowerCase()) {
      case 'approved':
        return normalizedStatus.contains('approved');
      case 'pending':
        return normalizedStatus.contains('pending');
      case 'processing':
        return normalizedStatus.contains('processing');
      case 'rejected':
        return normalizedStatus.contains('rejected');
      default:
        return true;
    }
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
              child: ValueListenableBuilder<List<ReservationRecord>>(
                valueListenable: ReservationActivityStore.listenable,
                builder: (context, reservations, child) {
                  final filteredReservations = _filterReservations(
                    reservations,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                    children: [
                      const Text(
                        'Reservation History',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
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
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search reservations',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF4053A7),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF3F5FB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedStatus,
                                    decoration: InputDecoration(
                                      labelText: 'Status',
                                      labelStyle: const TextStyle(
                                        color: Color(0xFF4053A7),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF3F5FB),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'All',
                                        child: Text('All'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Approved',
                                        child: Text('Approved'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Pending',
                                        child: Text('Pending'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Processing',
                                        child: Text('Processing'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Rejected',
                                        child: Text('Rejected'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedStatus = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickDate,
                                    icon: const Icon(
                                      Icons.calendar_today_rounded,
                                    ),
                                    label: Text(
                                      _selectedDate == null
                                          ? 'Date'
                                          : _formatDate(_selectedDate!),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF35489A),
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedDate != null ||
                                _selectedStatus != 'All' ||
                                _searchController.text.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Clear filters'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (reservations.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
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
                            children: [
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6EAF9),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Icon(
                                  Icons.history_rounded,
                                  color: Color(0xFF35489A),
                                  size: 46,
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'No reservation history yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Submitted venue and item reservations will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF6A6F86),
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (filteredReservations.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
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
                          child: const Text(
                            'No reservations match the current filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6A6F86),
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        )
                      else
                        ...filteredReservations.map((reservation) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReservationDetailsPage(
                                      reservation: reservation,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
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
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color:
                                            reservation.reservationType ==
                                                'Item Reservation'
                                            ? const Color(0xFFFFF7D8)
                                            : const Color(0xFFE6EAF9),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        reservation.reservationType ==
                                                'Item Reservation'
                                            ? Icons.inventory_2_rounded
                                            : Icons.meeting_room_rounded,
                                        color: const Color(0xFF35489A),
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  reservation.roomName,
                                                  style: const TextStyle(
                                                    color: Color(0xFF111111),
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              _StatusChip(
                                                label: reservation
                                                    .reservationStatus,
                                                status: reservation
                                                    .reservationStatus,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            reservation.reservationTitle,
                                            style: const TextStyle(
                                              color: Color(0xFF4053A7),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.event_note_rounded,
                                                size: 15,
                                                color: Color(0xFF6A6F86),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  _formatDate(reservation.date),
                                                  style: const TextStyle(
                                                    color: Color(0xFF6A6F86),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time_rounded,
                                                size: 15,
                                                color: Color(0xFF6A6F86),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  reservation.reservationTime,
                                                  style: const TextStyle(
                                                    color: Color(0xFF6A6F86),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
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

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final String status;

  Color get _backgroundColor {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFFE7F7EA);
      case 'rejected':
        return const Color(0xFFFDE8E8);
      case 'processing':
        return const Color(0xFFFFF7D8);
      default:
        return const Color(0xFFE6EAF9);
    }
  }

  Color get _foregroundColor {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2F8F4E);
      case 'rejected':
        return const Color(0xFFDA1E1E);
      case 'processing':
        return const Color(0xFFF29F05);
      default:
        return const Color(0xFF4053A7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
