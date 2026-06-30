import 'package:flutter/material.dart';

class RequestPage extends StatelessWidget {
  const RequestPage({super.key});

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
                  const Text(
                    'NUtilize',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF35489A),
                          size: 25,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                      icon: Icons.meeting_room_rounded,
                      title: 'Venue Reservation',
                      subtitle: 'Classrooms, Gymnasium, AVR',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RoomReservationPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _ReservationCard(
                      icon: Icons.tv_rounded,
                      title: 'Item Reservation',
                      subtitle: 'TV, Tables, Chairs, etc.',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Item reservation flow coming soon.'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Color(0xFFBCC2D9),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'More Actions',
                            style: TextStyle(
                              color: Color(0xFF4053A7),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Color(0xFFBCC2D9),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Reservation history is not available yet.',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF6C914),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF6C914),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'View History of Reservation',
                                    style: TextStyle(
                                      color: Color(0xFF1C1F2A),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Review your past room and item reservations.',
                                    style: TextStyle(
                                      color: Color(0xFF6A6F86),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF6A6F86),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFF35489A),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const _BottomNavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const _BottomNavItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'Calendar',
                    ),
                  ),
                  const _BottomNavItem(
                    icon: Icons.post_add_outlined,
                    label: 'Request',
                    selected: true,
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const _UserPage()),
                    ),
                    child: const _BottomNavItem(
                      icon: Icons.person_outline_rounded,
                      label: 'User',
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

class RoomReservationPage extends StatefulWidget {
  const RoomReservationPage({super.key});

  @override
  State<RoomReservationPage> createState() => _RoomReservationPageState();
}

class _RoomReservationPageState extends State<RoomReservationPage> {
  final List<String> _roomTypes = [
    'Classrooms',
    'Laboratory',
    'Gym',
    'Audio Visual Room',
  ];
  final List<String> _attendanceOptions = [
    '1 - 20',
    '21 - 50',
    '51 - 100',
    '101+',
  ];
  final List<String> _chairTypes = ['Monoblock', 'Steel', 'Armchairs'];
  final List<String> _equipmentTypes = ['TV', 'Speaker', 'Monitor'];
  final List<String> _miscTypes = ['Podium', 'Industrial Fans', 'Tables'];
  final List<Map<String, Object>> _roomRecommendations = [
    {
      'room': 'Room 503',
      'capacity': '50',
      'floor': '5th Floor',
      'features': 'TV, Chair',
      'status': 'Available (All Day)',
    },
    {
      'room': 'Room 526',
      'capacity': '30',
      'floor': '5th Floor',
      'features': 'TV, Chair',
      'status': 'Available (8:00AM - 12:00PM)',
    },
    {
      'room': 'Room 101',
      'capacity': '70',
      'floor': '1st Floor',
      'features': 'TV',
      'status': 'Available (10:00PM - 12:00PM)',
    },
    {
      'room': 'Room 618',
      'capacity': '40',
      'floor': '6th Floor',
      'features': 'TV, Chair',
      'status': 'Available (All Day)',
    },
  ];

  int _currentStep = 0;
  bool _addChairs = false;
  bool _addEquipment = false;
  bool _addMisc = false;
  bool _acceptedTerms = false;
  bool _submitted = false;

  String? _selectedRoomType;
  String? _selectedAttendance;
  String? _selectedChairType;
  String? _selectedEquipmentType;
  String? _selectedMiscType;
  String? _selectedRoomRecommendation;
  final TextEditingController _activityTitleController =
      TextEditingController();
  final TextEditingController _fromTimeController = TextEditingController();
  final TextEditingController _toTimeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _activityTitleController.dispose();
    _fromTimeController.dispose();
    _toTimeController.dispose();
    _dateController.dispose();
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

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goNext() {
    if (_submitted) return;

    switch (_currentStep) {
      case 0:
        if (_selectedRoomType == null ||
            _activityTitleController.text.isEmpty ||
            _fromTimeController.text.isEmpty ||
            _toTimeController.text.isEmpty ||
            _dateController.text.isEmpty ||
            _selectedAttendance == null) {
          _showValidationMessage('Please complete all required fields.');
          return;
        }
        break;
      case 1:
        if (_addChairs && _selectedChairType == null) {
          _showValidationMessage('Please select a chair type.');
          return;
        }
        if (_addEquipment && _selectedEquipmentType == null) {
          _showValidationMessage('Please select equipment to add.');
          return;
        }
        if (_addMisc && _selectedMiscType == null) {
          _showValidationMessage('Please select a miscellaneous item.');
          return;
        }
        break;
      case 2:
        if (_selectedRoomRecommendation == null) {
          _showValidationMessage('Please choose one of the recommended rooms.');
          return;
        }
        break;
      case 3:
        // Review step always passes through.
        break;
      case 4:
        if (!_acceptedTerms) {
          _showValidationMessage('You must accept the terms and conditions.');
          return;
        }
        setState(() {
          _submitted = true;
        });
        return;
    }

    setState(() {
      if (_currentStep < 4) {
        _currentStep += 1;
      }
    });
  }

  void _goBack() {
    if (_submitted) return;
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    } else {
      Navigator.of(context).pop();
    }
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
                    onTap: _goBack,
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Text(
                    'VENUE RESERVATION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_submitted) ...[
                      Text(
                        'Step ${_currentStep + 1} out of 5',
                        style: const TextStyle(
                          color: Color(0xFF35489A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildProgressBar(),
                      const SizedBox(height: 24),
                    ],
                    _submitted ? _buildSuccessCard() : _buildStepCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard() {
    switch (_currentStep) {
      case 1:
        return _buildOptionsStep();
      case 2:
        return _buildRecommendationsStep();
      case 3:
        return _buildReviewStep();
      case 4:
        return _buildTermsStep();
      default:
        return _buildDetailsStep();
    }
  }

  Widget _buildDetailsStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35489A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Type',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedRoomType,
            decoration: _fieldDecoration(hintText: 'Select Room Type'),
            items: _roomTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _selectedRoomType = value),
          ),
          const SizedBox(height: 18),
          const Text(
            'Title of Activity',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _activityTitleController,
            decoration: _fieldDecoration(hintText: 'Enter title of activity'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Time of Activity',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fromTimeController,
                  decoration: _fieldDecoration(hintText: 'From'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _toTimeController,
                  decoration: _fieldDecoration(hintText: 'To'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Date of Activity',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dateController,
            readOnly: true,
            onTap: _pickDate,
            decoration: _fieldDecoration(hintText: 'MM / DD / YYYY').copyWith(
              suffixIcon: const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF35489A),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Expected Attendance',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedAttendance,
            decoration: _fieldDecoration(hintText: 'Select expected attendees'),
            items: _attendanceOptions
                .map(
                  (count) => DropdownMenuItem(value: count, child: Text(count)),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedAttendance = value),
          ),
          const SizedBox(height: 24),
          _buildStepButtons(isFinal: false),
        ],
      ),
    );
  }

  Widget _buildOptionsStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35489A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOptionGroup(
            title: 'Do you want to add chairs?',
            value: _addChairs,
            onChanged: (value) => setState(() => _addChairs = value),
            selectionBuilder: _addChairs
                ? _buildSelectionList(
                    items: _chairTypes,
                    selectedValue: _selectedChairType,
                    onChanged: (value) =>
                        setState(() => _selectedChairType = value),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          _buildOptionGroup(
            title: 'Do you want to add other equipment?',
            value: _addEquipment,
            onChanged: (value) => setState(() => _addEquipment = value),
            selectionBuilder: _addEquipment
                ? _buildSelectionList(
                    items: _equipmentTypes,
                    selectedValue: _selectedEquipmentType,
                    onChanged: (value) =>
                        setState(() => _selectedEquipmentType = value),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          _buildOptionGroup(
            title: 'Do you want to add miscellaneous item?',
            value: _addMisc,
            onChanged: (value) => setState(() => _addMisc = value),
            selectionBuilder: _addMisc
                ? _buildSelectionList(
                    items: _miscTypes,
                    selectedValue: _selectedMiscType,
                    onChanged: (value) =>
                        setState(() => _selectedMiscType = value),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          _buildStepButtons(isFinal: false),
        ],
      ),
    );
  }

  Widget _buildRecommendationsStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35489A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Picks for You',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Recommended classrooms based on your preferences',
            style: TextStyle(color: Color(0xFF6A6F86), fontSize: 12),
          ),
          const SizedBox(height: 18),
          ..._roomRecommendations.map((room) {
            final bool selected = room['room'] == _selectedRoomRecommendation;
            return _buildRecommendationCard(
              room['room']! as String,
              room['capacity']! as String,
              room['floor']! as String,
              room['features']! as String,
              room['status']! as String,
              selected,
            );
          }).toList(),
          const SizedBox(height: 24),
          _buildStepButtons(isFinal: false),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35489A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review and Confirm Details',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _buildReviewRow(
            'Room',
            _selectedRoomRecommendation ?? 'Not selected',
          ),
          _buildReviewRow(
            'Purpose',
            _activityTitleController.text.isEmpty
                ? 'Not specified'
                : _activityTitleController.text,
          ),
          _buildReviewRow(
            'Time',
            _fromTimeController.text.isEmpty || _toTimeController.text.isEmpty
                ? 'Not specified'
                : '${_fromTimeController.text} - ${_toTimeController.text}',
          ),
          _buildReviewRow(
            'Date',
            _dateController.text.isEmpty
                ? 'Not specified'
                : _dateController.text,
          ),
          _buildReviewRow('Capacity', _selectedAttendance ?? 'Not selected'),
          _buildReviewRow(
            'Chair',
            _addChairs ? (_selectedChairType ?? 'Selected') : 'No Need',
          ),
          _buildReviewRow(
            'Equipment',
            _addEquipment ? (_selectedEquipmentType ?? 'Selected') : 'No Need',
          ),
          _buildReviewRow(
            'Miscellaneous',
            _addMisc ? (_selectedMiscType ?? 'Selected') : 'No Need',
          ),
          const SizedBox(height: 24),
          _buildStepButtons(isFinal: false),
        ],
      ),
    );
  }

  Widget _buildTermsStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35489A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Terms and Conditions',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'By proceeding, you agree to the room and equipment rental policies. You must accept the terms before submitting your request.',
            style: TextStyle(
              color: Color(0xFF6A6F86),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '''1. Proper use and cleanliness. The borrowed room/equipment must be used for its declared purpose and returned in good condition.
2. Liability for damage or loss is the responsibility of the requester.
3. Punctuality and extensions must be handled through the app.
4. Unauthorized materials, disruptive activities, or hazardous behavior are prohibited.
5. Cancellations must be made at least 1 hour before the scheduled time.''',
            style: TextStyle(
              color: Color(0xFF4F566A),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          CheckboxListTile(
            value: _acceptedTerms,
            onChanged: (value) => setState(() {
              _acceptedTerms = value ?? false;
            }),
            title: const Text(
              'I accept the Terms and Conditions',
              style: TextStyle(
                color: Color(0xFF111111),
                fontWeight: FontWeight.w700,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 6),
          _buildStepButtons(isFinal: true),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    String room,
    String capacity,
    String floor,
    String features,
    String status,
    bool selected,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRoomRecommendation = room),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6C914) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFF6C914) : const Color(0xFFE6EAF9),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  room,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF111111),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : const Color(0xFFE6F5E8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF35489A)
                          : const Color(0xFF2F8F40),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Cap: $capacity | $floor',
              style: TextStyle(
                color: selected ? Colors.white70 : const Color(0xFF6A6F86),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              features,
              style: TextStyle(
                color: selected ? Colors.white70 : const Color(0xFF6A6F86),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF6A6F86),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGroup({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? selectionBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: true,
                groupValue: value,
                title: const Text('Yes, I want to add'),
                onChanged: (value) => onChanged(true),
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: false,
                groupValue: value,
                title: const Text('No need'),
                onChanged: (value) => onChanged(false),
              ),
            ),
          ],
        ),
        if (selectionBuilder != null) ...[
          const SizedBox(height: 12),
          selectionBuilder,
        ],
      ],
    );
  }

  Widget _buildSelectionList({
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      children: items.map((item) {
        final bool selected = selectedValue == item;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF1FF) : const Color(0xFFF8F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF35489A)
                  : const Color(0xFFD9DCE4),
            ),
          ),
          child: RadioListTile<String>(
            value: item,
            groupValue: selectedValue,
            onChanged: onChanged,
            title: Text(item),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepButtons({required bool isFinal}) {
    final String buttonLabel = isFinal ? 'Submit' : 'Next';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _goBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF35489A),
              side: const BorderSide(color: Color(0xFF94A0D1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Back'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _goNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF6C914),
              foregroundColor: const Color(0xFF1A2254),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35489A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.celebration_rounded,
            size: 86,
            color: Color(0xFFF6C914),
          ),
          const SizedBox(height: 24),
          const Text(
            'Congratulations!',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your room reservation request has been submitted successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6A6F86),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF6C914),
                foregroundColor: const Color(0xFF1A2254),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Finish',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFE1E7F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FractionallySizedBox(
        widthFactor: (_currentStep + 1) / 5,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6C914),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String hintText,
  Widget? prefix,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFB9B9B9),
      fontStyle: FontStyle.italic,
    ),
    prefixIcon: prefix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: prefix,
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF8F8FA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: const Color(0xFFF6C914), width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: const Color(0xFFF6C914), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF35489A), width: 1.5),
    ),
  );
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
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF6C914), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: Color(0xFFF6C914),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6A6F86), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? Colors.white : Colors.white70;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _UserPage extends StatelessWidget {
  const _UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.person_outline_rounded,
                size: 72,
                color: Color(0xFF35489A),
              ),
              SizedBox(height: 16),
              Text(
                'User screen is coming soon.',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
