import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/features/user/profile_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

class RequestHistoryPage extends StatefulWidget {
  const RequestHistoryPage({super.key});

  @override
  State<RequestHistoryPage> createState() => _RequestHistoryPageState();
}

class _RequestHistoryPageState extends State<RequestHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ReservationRecord> sourceReservations = _buildRequestList();
    final filteredReservations = sourceReservations.where((request) {
      final searchText = _searchController.text.trim().toLowerCase();
      final matchesSearch =
          searchText.isEmpty ||
          request.reservationTitle.toLowerCase().contains(searchText) ||
          request.roomName.toLowerCase().contains(searchText);
      final matchesStatus =
          _selectedStatus == 'All' ||
          _statusBucket(request.reservationStatus) == _selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'Request History'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search requests',
                        hintStyle: const TextStyle(color: Color(0xFF8A90A8)),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF35489A),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F5FB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
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
                            'Rejected',
                            'Cancelled',
                          ].map((status) {
                            final isSelected = _selectedStatus == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                selectedColor: const Color(0xFFE6EAF9),
                                checkmarkColor: const Color(0xFF35489A),
                                label: Text(
                                  status,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF35489A)
                                        : const Color(0xFF6A6F86),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedStatus = status;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filteredReservations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
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
                        'No requests match the selected filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6A6F86),
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ...filteredReservations.map((request) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    request.reservationTitle,
                                    style: const TextStyle(
                                      color: Color(0xFF111111),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _StatusChip(
                                  label: request.reservationStatus,
                                  status: request.reservationStatus,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(label: 'Room', value: request.roomName),
                            _InfoRow(
                              label: 'Date',
                              value: _formatDate(request.date),
                            ),
                            _InfoRow(
                              label: 'Time',
                              value: request.reservationTime,
                            ),
                            _InfoRow(
                              label: 'Date Submitted',
                              value: _formatDate(request.date),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
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
                  ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<ReservationRecord> _buildRequestList() {
    final storeReservations = ReservationActivityStore.listenable.value;
    final fallbackReservations = ReservationRepository.sample(
      DateTime.now(),
    ).reservations;
    final combined = <ReservationRecord>[];
    final seenIds = <String>{};

    for (final reservation in [...storeReservations, ...fallbackReservations]) {
      if (seenIds.add(reservation.stableId)) {
        combined.add(reservation);
      }
    }

    combined.sort((a, b) => b.date.compareTo(a.date));
    return combined;
  }

  String _statusBucket(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('approved')) {
      return 'Approved';
    }
    if (normalized.contains('reject')) {
      return 'Rejected';
    }
    if (normalized.contains('cancel')) {
      return 'Cancelled';
    }
    return 'Pending';
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6A6F86),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
      case 'cancelled':
        return const Color(0xFFF1F2F6);
      default:
        return const Color(0xFFFFF7D8);
    }
  }

  Color get _foregroundColor {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2F8F4E);
      case 'rejected':
        return const Color(0xFFDA1E1E);
      case 'cancelled':
        return const Color(0xFF6A6F86);
      default:
        return const Color(0xFFF29F05);
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
