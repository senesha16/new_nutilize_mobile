import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_details_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

class ReservationHistoryPage extends StatefulWidget {
  const ReservationHistoryPage({super.key});

  @override
  State<ReservationHistoryPage> createState() => _ReservationHistoryPageState();
}

class _ReservationHistoryPageState extends State<ReservationHistoryPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  DateTime? _selectedDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF35489A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A2254),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReservationActivityStore.listenable,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final sourceReservations = collectReservations(DateTime.now());
        final filtered = sourceReservations.where((reservation) {
          final matchesQuery =
              query.isEmpty ||
              reservation.reservationTitle.toLowerCase().contains(query) ||
              reservation.roomName.toLowerCase().contains(query);
          final matchesStatus =
              _selectedStatus == 'All' ||
              reservation.reservationStatus == _selectedStatus;
          final matchesDate =
              _selectedDate == null ||
              DateUtils.isSameDay(reservation.date, _selectedDate);
          return matchesQuery && matchesStatus && matchesDate;
        }).toList()..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          backgroundColor: const Color(0xFFF3F5FB),
          body: SafeArea(
            child: Column(
              children: [
                const SecondaryHeader(title: 'Reservation History'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: _cardDecoration(),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search reservations',
                            hintStyle: const TextStyle(
                              color: Color(0xFF8A90A8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF35489A),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF3F5FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              [
                                'All',
                                'Pending',
                                'Approved',
                                'Completed',
                                'Cancelled',
                              ].map((status) {
                                final selected = status == _selectedStatus;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(status),
                                    selected: selected,
                                    showCheckmark: false,
                                    selectedColor: const Color(0xFF35489A),
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF464D6A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                    side: BorderSide(
                                      color: selected
                                          ? const Color(0xFF35489A)
                                          : const Color(0xFFD9DCE8),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    onSelected: (_) {
                                      setState(() => _selectedStatus = status);
                                    },
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: _cardDecoration(),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                color: Color(0xFF35489A),
                                size: 22,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Filter by Date',
                                      style: TextStyle(
                                        color: Color(0xFF4053A7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedDate == null
                                          ? 'All dates'
                                          : _formatDate(_selectedDate!),
                                      style: const TextStyle(
                                        color: Color(0xFF111111),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedDate != null)
                                IconButton(
                                  tooltip: 'Clear date filter',
                                  onPressed: () {
                                    setState(() => _selectedDate = null);
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF6A6F86),
                                    size: 20,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF8A90A8),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (filtered.isEmpty)
                        const _EmptyHistory()
                      else
                        ...filtered.map(
                          (reservation) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReservationHistoryCard(
                              reservation: reservation,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReservationDetailsPage(
                                      reservation: reservation,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AppBottomNav(
                  selectedIndex:
                      AppShellScope.maybeOf(context)?.currentIndex ?? 3,
                  onTap:
                      AppShellScope.maybeOf(context)?.onTabSelected ?? (_) {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReservationHistoryCard extends StatelessWidget {
  const _ReservationHistoryCard({
    required this.reservation,
    required this.onTap,
  });

  final ReservationRecord reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (reservation.reservationStatus) {
      'Approved' || 'Completed' => const Color(0xFF2E9D50),
      'Cancelled' => const Color(0xFFD22828),
      _ => const Color(0xFFD79700),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EAF9),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.meeting_room_outlined,
                      color: Color(0xFF35489A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.roomName,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reservation.reservationTitle,
                          style: const TextStyle(
                            color: Color(0xFF6A6F86),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      reservation.reservationStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Color(0xFF6A6F86),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _formatDate(reservation.date),
                    style: const TextStyle(
                      color: Color(0xFF6A6F86),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFF6A6F86),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reservation.reservationTime,
                      style: const TextStyle(
                        color: Color(0xFF6A6F86),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8A90A8),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.event_busy_outlined, color: Color(0xFF8A90A8), size: 38),
          SizedBox(height: 10),
          Text(
            'No reservations found.',
            style: TextStyle(
              color: Color(0xFF464D6A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}
