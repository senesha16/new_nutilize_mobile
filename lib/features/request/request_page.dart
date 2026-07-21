import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/request/reservation_history_page.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';

class RequestPage extends StatelessWidget {
  const RequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'NUtilize'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a new reservation',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ReservationCard(
                      icon: Icons.home_work_rounded,
                      title: 'Room Reservation',
                      subtitle: 'Classrooms, gymnasium, AMP',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RoomReservationPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _ReservationCard(
                      icon: Icons.devices_outlined,
                      title: 'Item Reservation',
                      subtitle: 'TVs, tables, chairs, and equipment',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ItemReservationPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'More Actions',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      child: Divider(
                        color: Color(0xFFD0D0D6),
                        thickness: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ReservationCard(
                      icon: Icons.history_rounded,
                      title: 'View History of Reservation',
                      subtitle: '',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReservationHistoryPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Today’s reservations',
                      style: TextStyle(
                        color: Color(0xFF4053A7),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SmallInfoCard(
                      icon: Icons.info_outline,
                      title: 'Need help?',
                      subtitle: 'Tap a reservation card to continue.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF6C914), width: 2),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF6C914),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmallInfoCard extends StatelessWidget {
  const _SmallInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFE4E7FB),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF35489A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomReservationPage extends StatefulWidget {
  const RoomReservationPage({super.key});

  @override
  State<RoomReservationPage> createState() => _RoomReservationPageState();
}

class _RoomReservationPageState extends State<RoomReservationPage> {
  final _reservationService = ReservationService();
  final _activityController = TextEditingController();
  final _chairController = TextEditingController();
  final _miscController = TextEditingController();
  final _dateController = TextEditingController();

  int _currentStep = 1;
  String? _selectedRoomType;
  String? _selectedRoomTableType;
  String? _selectedAttendance;
  bool _chairsNeeded = false;
  bool _equipmentNeeded = false;
  bool _miscNeeded = false;
  bool _agreedToTerms = false;
  int? _selectedChairs;
  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  Room? _selectedRoom;
  List<Room> _availableRooms = [];
  List<ItemModel> _equipmentItems = [];
  final Set<int> _selectedItemIds = {};
  bool _isLoadingRooms = false;
  bool _isLoadingItems = false;
  String? _loadError;

  static const _roomTypes = [
    'Classroom',
    'Gym',
    'AVR',
    'Lobby',
    'Student Lounge',
  ];

  static const _roomTableTypes = [
    'Armchair',
    'Trapezoidal',
    'Accounting Table',
  ];

  static const _attendanceOptions = [
    '1 - 20',
    '21 - 50',
    '51 - 100',
    '101+',
  ];

  static final _timeOptions = List.generate(
    32,
    (index) => TimeOfDay(hour: 7 + index ~/ 2, minute: index.isOdd ? 30 : 0),
  );

  @override
  void initState() {
    super.initState();
    _loadEquipmentItems();
  }

  @override
  void dispose() {
    _activityController.dispose();
    _chairController.dispose();
    _miscController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadEquipmentItems() async {
    setState(() {
      _isLoadingItems = true;
    });
    final items = await _reservationService.getAllItems();
    if (mounted) {
      setState(() {
        _equipmentItems = items;
        _isLoadingItems = false;
      });
    }
  }

  void _startDatePicker() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 1),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF35489A),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = '${picked.month}/${picked.day}/${picked.year}';
      });
    }
  }

  String _timeLabel(TimeOfDay? time) {
    if (time == null) return 'Select';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTimestamp(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} $hour:$minute $period';
  }

  void _showTimePicker({required bool isStart}) async {
    final initial = isStart
        ? _selectedStartTime ?? const TimeOfDay(hour: 8, minute: 0)
        : _selectedEndTime ?? const TimeOfDay(hour: 10, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: const TimePickerThemeData(
            dialBackgroundColor: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartTime = picked;
          if (_selectedEndTime != null && _isBeforeOrEqual(_selectedEndTime!, picked)) {
            _selectedEndTime = null;
          }
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  bool _isBeforeOrEqual(TimeOfDay a, TimeOfDay b) {
    return a.hour < b.hour || (a.hour == b.hour && a.minute <= b.minute);
  }

  bool _matchesAttendance(Room room) {
    if (_selectedAttendance == null || room.roomCapacity == null) {
      return true;
    }
    switch (_selectedAttendance) {
      case '1 - 20':
        return room.roomCapacity! >= 1;
      case '21 - 50':
        return room.roomCapacity! >= 21;
      case '51 - 100':
        return room.roomCapacity! >= 51;
      case '101+':
        return room.roomCapacity! >= 101;
      default:
        return true;
    }
  }

  Future<void> _loadAvailableRooms() async {
    if (_selectedRoomType == null || _selectedDate == null || _selectedStartTime == null || _selectedEndTime == null) {
      return;
    }

    setState(() {
      _isLoadingRooms = true;
      _loadError = null;
      _availableRooms = [];
      _selectedRoom = null;
    });

    try {
      // Fetch rooms directly by type, using table type filter for classrooms
      final rooms = _selectedRoomType == 'Classroom' && _selectedRoomTableType != null
          ? await _reservationService.getClassroomsByTableType(_selectedRoomTableType!)
          : await _reservationService.getRoomsByType(_selectedRoomType!);
      
      print('DEBUG _loadAvailableRooms: Fetched ${rooms.length} rooms');
      
      final available = <Room>[];
      for (final room in rooms) {
        final hasConflict = await _reservationService.hasTimeConflict(
          roomId: room.roomId,
          reservationDate: _selectedDate!,
          startTime: DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedStartTime!.hour,
            _selectedStartTime!.minute,
          ),
          endTime: DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedEndTime!.hour,
            _selectedEndTime!.minute,
          ),
        );
        // Only add room if no time conflict and attendance matches
        if (!hasConflict && _matchesAttendance(room)) {
          print('DEBUG _loadAvailableRooms: Adding room ${room.roomNumber}');
          available.add(room);
        } else {
          print('DEBUG _loadAvailableRooms: Filtering out room ${room.roomNumber} (conflict: $hasConflict, matches attendance: ${_matchesAttendance(room)})');
        }
      }
      print('DEBUG _loadAvailableRooms: Final available rooms: ${available.length}');
      setState(() {
        _availableRooms = available;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Unable to load available rooms. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
        });
      }
    }
  }

  void _goToNextStep() async {
    if (_currentStep == 1) {
      if (_selectedRoomType == null) {
        _showError('Please select a room type.');
        return;
      }
      if (_activityController.text.isEmpty) {
        _showError('Enter the title of activity.');
        return;
      }
      if (_selectedDate == null) {
        _showError('Select the date of activity.');
        return;
      }
      if (_selectedStartTime == null || _selectedEndTime == null) {
        _showError('Select the start and end time.');
        return;
      }
      if (_isBeforeOrEqual(_selectedEndTime!, _selectedStartTime!)) {
        _showError('End time must be after start time.');
        return;
      }
      if (_selectedAttendance == null) {
        _showError('Select expected attendance.');
        return;
      }
      if (_selectedRoomType == 'Classroom' && _selectedRoomTableType == null) {
        _showError('Select a classroom table type.');
        return;
      }
      setState(() {
        _currentStep = 2;
      });
      return;
    }

    if (_currentStep == 2) {
      if (_chairsNeeded && _chairController.text.isEmpty) {
        _showError('Enter the number of chairs.');
        return;
      }
      if (_chairsNeeded) {
        final parsed = int.tryParse(_chairController.text);
        if (parsed == null || parsed < 0) {
          _showError('Chairs must be a valid number.');
          return;
        }
        _selectedChairs = parsed;
      } else {
        _selectedChairs = null;
      }
      setState(() {
        _currentStep = 3;
      });
      await _loadAvailableRooms();
      return;
    }

    if (_currentStep == 3) {
      if (_selectedRoom == null) {
        _showError('Choose a recommended room.');
        return;
      }
      setState(() {
        _currentStep = 4;
      });
      return;
    }

    if (_currentStep == 4) {
      setState(() {
        _currentStep = 5;
      });
      return;
    }
  }

  void _goToPreviousStep() {
    if (_currentStep == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _currentStep -= 1;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitReservation() async {
    if (!_agreedToTerms) {
      _showError('Please agree to the terms and conditions.');
      return;
    }
    if (_selectedRoom == null || _selectedDate == null || _selectedStartTime == null || _selectedEndTime == null) {
      _showError('Reservation is incomplete.');
      return;
    }

    final currentUser = AuthService.currentUser;
    if (currentUser == null || currentUser['user_id'] == null) {
      _showError('Please sign in again.');
      return;
    }

    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedStartTime!.hour,
      _selectedStartTime!.minute,
    );
    final endDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedEndTime!.hour,
      _selectedEndTime!.minute,
    );

    final approvalChain = await _reservationService.calculateApprovalChain(
      roomType: _selectedRoomType ?? '',
      itemIds: _selectedItemIds.isEmpty ? null : _selectedItemIds.toList(),
    );

    final reservationId = await _reservationService.createReservation(
      activityName: _activityController.text.trim(),
      userId: currentUser['user_id'] as int,
      roomId: _selectedRoom!.roomId,
      dateOfActivity: _selectedDate!,
      startTime: startDateTime,
      endTime: endDateTime,
      chairsQuantity: _selectedChairs != null ? [_selectedChairs!] : null,
      itemIds: _selectedItemIds.isEmpty ? null : _selectedItemIds.toList(),
      approvalChain: approvalChain.officeIds,
    );

    if (reservationId != null) {
      final reservationTime = '${_timeLabel(_selectedStartTime)} - ${_timeLabel(_selectedEndTime)}';
      final timeline = approvalChain.offices.map((office) {
        return ReservationTimelineEntry(
          title: office,
          status: 'Pending',
          date: _selectedDate!,
          timestamp: 'Pending',
          description: 'Waiting for approval from $office.',
        );
      }).toList();

      final newRecord = ReservationRecord(
        id: reservationId.toString(),
        userId: currentUser['user_id'] as int,
        reservationTitle: _activityController.text.trim().isEmpty
            ? 'Reservation Request'
            : _activityController.text.trim(),
        roomName: _selectedRoom!.roomNumber,
        reservationType: 'Venue Reservation',
        reservationStatus: 'Pending Approval',
        date: _selectedDate!,
        reservationTime: reservationTime,
        timeline: [
          ReservationTimelineEntry(
            title: 'Request Submitted',
            status: 'Completed',
            date: _selectedDate!,
            timestamp: _formatTimestamp(_selectedDate!),
            description: 'Your reservation request was submitted successfully.',
          ),
          ...timeline,
        ],
      );

      ReservationActivityStore.add(newRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room reservation submitted successfully.')));
        Navigator.of(context).pop();
      }
    } else {
      _showError('Reservation failed. Please try again.');
    }
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (index) {
        final active = index < _currentStep;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF6C914) : const Color(0xFFD9DCE8),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildStepHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $_currentStep out of 5',
          style: const TextStyle(color: Color(0xFF35489A), fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _buildProgressIndicator(),
      ],
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 26, offset: Offset(0, 10)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildStepOne() {
    return _buildFormCard(children: [
      _buildDropdownField(
        label: 'Room Type',
        hint: 'Select Room Type',
        value: _selectedRoomType,
        items: _roomTypes,
        onChanged: (value) => setState(() {
          _selectedRoomType = value;
          if (value != 'Classroom') {
            _selectedRoomTableType = null;
          }
        }),
      ),
      const SizedBox(height: 16),
      _ReservationInputField(label: 'Title of Activity', controller: _activityController, hintText: 'Enter title of activity'),
      const SizedBox(height: 16),
      const Align(alignment: Alignment.centerLeft, child: Text('Time of Activity', style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700))),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildTimeBox('From', _selectedStartTime, () => _showTimePicker(isStart: true))),
          const SizedBox(width: 12),
          Expanded(child: _buildTimeBox('To', _selectedEndTime, () => _showTimePicker(isStart: false))),
        ],
      ),
      const SizedBox(height: 16),
      const Align(alignment: Alignment.centerLeft, child: Text('Date of Activity', style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700))),
      const SizedBox(height: 12),
      _buildDateBox(),
      const SizedBox(height: 16),
      _buildDropdownField(
        label: 'Expected Attendance',
        hint: 'Select expected attendees',
        value: _selectedAttendance,
        items: _attendanceOptions,
        onChanged: (value) => setState(() => _selectedAttendance = value),
      ),
      if (_selectedRoomType == 'Classroom') ...[
        const SizedBox(height: 16),
        _buildDropdownField(
          label: 'Room Table Type',
          hint: 'Select table layout',
          value: _selectedRoomTableType,
          items: _roomTableTypes,
          onChanged: (value) => setState(() => _selectedRoomTableType = value),
        ),
      ],
    ]);
  }

  Widget _buildTimeBox(String label, TimeOfDay? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF6C914), width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'Select' : _timeLabel(value),
                style: TextStyle(color: value == null ? const Color(0xFFB0B6D7) : const Color(0xFF111111), fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.watch_later_outlined, color: Color(0xFF35489A)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBox() {
    return GestureDetector(
      onTap: _startDatePicker,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF6C914), width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedDate == null ? 'MM / DD / YYYY' : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                style: TextStyle(color: _selectedDate == null ? const Color(0xFFB0B6D7) : const Color(0xFF111111), fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.calendar_today, color: Color(0xFF35489A)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF6C914), width: 2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint, style: const TextStyle(color: Color(0xFFB0B6D7))),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF35489A)),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentSelection() {
    if (_isLoadingItems) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_equipmentItems.isEmpty) {
      return const Text(
        'No equipment is currently available to reserve.',
        style: TextStyle(color: Color(0xFF6A6F86)),
      );
    }

    return Column(
      children: _equipmentItems.map((item) {
        final selected = _selectedItemIds.contains(item.itemId);
        return CheckboxListTile(
          tileColor: selected ? const Color(0xFFE4E7FB) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Available: ${item.availableQuantity}'),
          value: selected,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedItemIds.add(item.itemId);
              } else {
                _selectedItemIds.remove(item.itemId);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildStepTwo() {
    return _buildFormCard(children: [
      const Align(alignment: Alignment.centerLeft, child: Text('Do you want to add chairs?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111111)))),
      const SizedBox(height: 14),
      _buildYesNoRow(value: _chairsNeeded, onChanged: (value) => setState(() => _chairsNeeded = value)),
      if (_chairsNeeded) ...[
        const SizedBox(height: 16),
        _ReservationInputField(label: 'Number of chairs', controller: _chairController, hintText: 'Enter number of chairs', keyboardType: TextInputType.number),
      ],
      const SizedBox(height: 24),
      const Align(alignment: Alignment.centerLeft, child: Text('Do you want to add other equipment?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111111)))),
      const SizedBox(height: 14),
      _buildYesNoRow(value: _equipmentNeeded, onChanged: (value) => setState(() => _equipmentNeeded = value)),
      if (_equipmentNeeded) ...[
        const SizedBox(height: 16),
        _buildEquipmentSelection(),
      ],
      const SizedBox(height: 24),
      const Align(alignment: Alignment.centerLeft, child: Text('Any extra request?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111111)))),
      const SizedBox(height: 14),
      _buildYesNoRow(value: _miscNeeded, onChanged: (value) => setState(() => _miscNeeded = value)),
      if (_miscNeeded) ...[
        const SizedBox(height: 16),
        _ReservationInputField(label: 'Miscellaneous details', controller: _miscController, hintText: 'Describe the item'),
      ],
    ]);
  }

  Widget _buildYesNoRow({required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(child: _buildSelectionOption('Yes, I want to add', value, () => onChanged(true))),
        const SizedBox(width: 12),
        Expanded(child: _buildSelectionOption('No need', !value, () => onChanged(false))),
      ],
    );
  }

  Widget _buildSelectionOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF6C914) : const Color(0xFFD9DCE8),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFFF6C914) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFFF6C914) : const Color(0xFF9A9A9A),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(child: Icon(Icons.circle, size: 12, color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF111111),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepThree() {
    return _buildFormCard(children: [
      const Align(alignment: Alignment.centerLeft, child: Text('Choose Available Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111111)))),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _selectedRoomType == 'Classroom'
              ? 'Showing rooms with ${_selectedRoomTableType ?? 'selected'} layout and no active reservations.'
              : 'Showing available ${_selectedRoomType ?? 'rooms'} with no active reservations.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6A6F86)),
        ),
      ),
      const SizedBox(height: 16),
      if (_isLoadingRooms) ...[
        const Center(child: CircularProgressIndicator()),
      ] else if (_loadError != null) ...[
        Text(_loadError!, style: const TextStyle(color: Colors.red)),
      ] else if (_availableRooms.isEmpty) ...[
        const SizedBox(height: 24),
        const Text('No rooms are available for your scheduled time. Try another time or room type.', style: TextStyle(color: Color(0xFF6A6F86))),
      ] else ..._availableRooms.map(_buildRoomCard).toList(),
    ]);
  }

  Widget _buildRoomCard(Room room) {
    final selected = _selectedRoom?.roomId == room.roomId;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoom = room),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6C914) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFF6C914) : const Color(0xFFD9DCE8)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? Colors.white24 : const Color(0xFFE4E7FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.meeting_room, color: Color(0xFF35489A)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.roomNumber, style: TextStyle(color: selected ? Colors.white : const Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    room.roomTableType != null ? room.roomTableType! : room.roomType,
                    style: TextStyle(color: selected ? Colors.white70 : const Color(0xFF6A6F86), fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white24 : const Color(0xFFE9F7EF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Available', style: TextStyle(color: selected ? Colors.white : const Color(0xFF27A35F), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepFour() {
    return _buildFormCard(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF35489A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirmation',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Review and confirm details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111111))),
      ),
      const SizedBox(height: 20),
      _buildReviewRow(Icons.meeting_room, 'Room', _selectedRoom?.roomNumber ?? 'Not selected'),
      _buildReviewRow(Icons.description, 'Purpose', _activityController.text.trim()),
      _buildReviewRow(Icons.watch_later_outlined, 'Time', '${_timeLabel(_selectedStartTime)} - ${_timeLabel(_selectedEndTime)}'),
      _buildReviewRow(Icons.calendar_today, 'Date', _selectedDate == null ? 'Not selected' : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'),
      _buildReviewRow(Icons.people_alt_outlined, 'Capacity', _selectedAttendance ?? 'Not selected'),
      _buildReviewRow(Icons.chair_alt, 'Chair', _chairsNeeded ? '${_selectedChairs ?? 'Requested'}' : 'None'),
      _buildReviewRow(Icons.tv, 'Equipment', _equipmentNeeded ? '${_selectedItemIds.length} selected' : 'None'),
      _buildReviewRow(Icons.miscellaneous_services, 'Miscellaneous', _miscNeeded ? _miscController.text.trim() : 'None'),
    ]);
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF35489A), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF6A6F86), fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Color(0xFF111111), fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepFive() {
    return _buildFormCard(children: [
      const Text('Terms and Conditions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111111))),
      const SizedBox(height: 12),
      Container(
        height: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(18)),
        child: SingleChildScrollView(
          child: const Text(
            'By proceeding, you agree to the room and equipment rental policies. You must maintain cleanliness, return any borrowed equipment on time, and report any damage immediately. Rooms must be vacated on or before the approved end time. Unauthorized materials, disruptive behavior, or damage to facilities are not permitted.',
            style: TextStyle(color: Color(0xFF6A6F86), fontSize: 14, height: 1.5),
          ),
        ),
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        value: _agreedToTerms,
        onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
        title: const Text('I agree to the terms and conditions.', style: TextStyle(fontWeight: FontWeight.w700)),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 92,
              decoration: const BoxDecoration(
                color: Color(0xFF35489A),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF2C94C), width: 4),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                  ),
                  const Text('Room Reservation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  _buildStepHeader(),
                  const SizedBox(height: 22),
                  if (_currentStep == 1) _buildStepOne() else if (_currentStep == 2) _buildStepTwo() else if (_currentStep == 3) _buildStepThree() else if (_currentStep == 4) _buildStepFour() else _buildStepFive(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _goToPreviousStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF35489A),
                            side: const BorderSide(color: Color(0xFF35489A)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _currentStep == 5 ? _submitReservation : _goToNextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF6C914),
                            foregroundColor: const Color(0xFF35489A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_currentStep == 5 ? 'Submit' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700)),
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
    );
  }
}

class ItemReservationPage extends StatefulWidget {
  const ItemReservationPage({super.key});

  @override
  State<ItemReservationPage> createState() => _ItemReservationPageState();
}

class _ItemReservationPageState extends State<ItemReservationPage> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    if (_itemController.text.isEmpty || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the item and quantity.')),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item reservation request submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 92,
              decoration: const BoxDecoration(
                color: Color(0xFF35489A),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF2C94C), width: 4),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const Text(
                    'Item Reservation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  const Text(
                    'Reserve equipment for your event.',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ReservationInputField(
                    label: 'Item',
                    controller: _itemController,
                    hintText: 'Enter item name',
                  ),
                  const SizedBox(height: 16),
                  _ReservationInputField(
                    label: 'Quantity',
                    controller: _quantityController,
                    hintText: 'Enter quantity',
                  ),
                  const SizedBox(height: 16),
                  _ReservationInputField(
                    label: 'Date',
                    controller: _dateController,
                    hintText: 'MM / DD / YYYY',
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF35489A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit Reservation',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationInputField extends StatelessWidget {
  const _ReservationInputField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4053A7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF8A90A8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD9DCE8)),
            ),
          ),
        ),
      ],
    );
  }
}
