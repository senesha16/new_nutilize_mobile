import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

class RequestHistoryPage extends StatefulWidget {
  const RequestHistoryPage({super.key});

  @override
  State<RequestHistoryPage> createState() => _RequestHistoryPageState();
}

class _RequestHistoryPageState extends State<RequestHistoryPage> {
  final List<_RequestRecord> _requests = [
    _RequestRecord(
      room: 'Room 503',
      title: 'INF231 Christmas Party',
      date: DateTime(2026, 7, 1),
      time: '9:00 AM - 12:00 PM',
      status: 'Pending',
      dateSubmitted: DateTime(2026, 6, 28),
    ),
    _RequestRecord(
      room: 'Conference Room',
      title: 'Department Meeting',
      date: DateTime(2026, 6, 29),
      time: '1:00 PM - 3:00 PM',
      status: 'Approved',
      dateSubmitted: DateTime(2026, 6, 25),
    ),
    _RequestRecord(
      room: 'Studio 2',
      title: 'Audio Visual Workshop',
      date: DateTime(2026, 6, 24),
      time: '9:30 AM - 11:30 AM',
      status: 'Rejected',
      dateSubmitted: DateTime(2026, 6, 21),
    ),
    _RequestRecord(
      room: 'Meeting Room A',
      title: 'Faculty Consultation',
      date: DateTime(2026, 6, 18),
      time: '2:00 PM - 4:00 PM',
      status: 'Cancelled',
      dateSubmitted: DateTime(2026, 6, 16),
    ),
  ];

  String _selectedStatus = 'All';

  List<_RequestRecord> get _filteredRequests {
    final filtered = _requests.where((request) {
      return _selectedStatus == 'All' || request.status == _selectedStatus;
    }).toList();

    filtered.sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
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
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Filter by status',
                        labelStyle: const TextStyle(color: Color(0xFF4053A7)),
                        filled: true,
                        fillColor: const Color(0xFFF3F5FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'Approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'Rejected',
                          child: Text('Rejected'),
                        ),
                        DropdownMenuItem(
                          value: 'Cancelled',
                          child: Text('Cancelled'),
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
                  const SizedBox(height: 16),
                  if (_filteredRequests.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
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
                        'No request history matches the selected filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6A6F86),
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    ..._filteredRequests.map((request) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      request.room,
                                      style: const TextStyle(
                                        color: Color(0xFF111111),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _StatusBadge(label: request.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                request.title,
                                style: const TextStyle(
                                  color: Color(0xFF4053A7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                icon: Icons.event_note_rounded,
                                label: _formatDate(request.date),
                              ),
                              const SizedBox(height: 6),
                              _DetailRow(
                                icon: Icons.access_time_rounded,
                                label: request.time,
                              ),
                              const SizedBox(height: 6),
                              _DetailRow(
                                icon: Icons.calendar_today_rounded,
                                label:
                                    'Submitted ${_formatDate(request.dateSubmitted)}',
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            AppBottomNav(
              selectedIndex: AppShellScope.maybeOf(context)?.currentIndex ?? 3,
              onTap: AppShellScope.maybeOf(context)?.onTabSelected ?? (_) {},
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

class _RequestRecord {
  const _RequestRecord({
    required this.room,
    required this.title,
    required this.date,
    required this.time,
    required this.status,
    required this.dateSubmitted,
  });

  final String room;
  final String title;
  final DateTime date;
  final String time;
  final String status;
  final DateTime dateSubmitted;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  Color get _backgroundColor {
    switch (label) {
      case 'Approved':
        return const Color(0xFFE7F7EA);
      case 'Rejected':
        return const Color(0xFFFDE8E8);
      case 'Cancelled':
        return const Color(0xFFF5E7E7);
      case 'Pending':
        return const Color(0xFFFFF7D8);
      default:
        return const Color(0xFFE6EAF9);
    }
  }

  Color get _foregroundColor {
    switch (label) {
      case 'Approved':
        return const Color(0xFF2F8F4E);
      case 'Rejected':
        return const Color(0xFFDA1E1E);
      case 'Cancelled':
        return const Color(0xFF8B5E3C);
      case 'Pending':
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6A6F86)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6A6F86), fontSize: 12),
          ),
        ),
      ],
    );
  }
}
