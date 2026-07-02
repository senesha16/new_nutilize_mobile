import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/user/about_developers_page.dart';
import 'package:new_nutilize_mobile/features/user/about_nutilize_page.dart';
import 'package:new_nutilize_mobile/features/user/help_faq_page.dart';
import 'package:new_nutilize_mobile/features/user/edit_profile_page.dart';
import 'package:new_nutilize_mobile/features/user/personal_details_page.dart';
import 'package:new_nutilize_mobile/features/user/report_issue_page.dart';
import 'package:new_nutilize_mobile/features/user/request_history_page.dart';
import 'package:new_nutilize_mobile/features/request/reservation_history_page.dart';
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
                            content: Text('Item reservation coming soon.'),
                          ),
                        );
                      },
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

  Future<void> _pickTime(TextEditingController controller) async {
    final List<TimeOfDay> validTimes = List.generate(13 * 6, (index) {
      final int totalMinutes = 7 * 60 + (index * 10);
      final int hour = totalMinutes ~/ 60;
      final int minute = totalMinutes % 60;
      return TimeOfDay(hour: hour, minute: minute);
    });
    TimeOfDay initial = _parseTime(controller.text) ?? validTimes.first;
    if (!validTimes.contains(initial)) {
      initial = validTimes.first;
    }

    final List<int> minuteOptions = [0, 10, 20, 30, 40, 50];

    List<int> hourOptions(String period) {
      return period == 'AM'
          ? const [7, 8, 9, 10, 11, 12]
          : const [12, 1, 2, 3, 4, 5, 6, 7];
    }

    int currentMinute = minuteOptions.contains(initial.minute)
        ? initial.minute
        : 0;
    String currentPeriod = initial.period == DayPeriod.am ? 'AM' : 'PM';
    int currentHour = initial.hourOfPeriod == 0 ? 12 : initial.hourOfPeriod;
    if (!hourOptions(currentPeriod).contains(currentHour)) {
      currentPeriod = 'AM';
      currentHour = 7;
    }
    List<int> currentHourOptions = hourOptions(currentPeriod);
    int currentHourIndex = currentHourOptions.indexOf(currentHour);
    int currentMinuteIndex = minuteOptions.indexOf(currentMinute);
    int currentPeriodIndex = currentPeriod == 'AM' ? 0 : 1;

    Widget buildPickerWheel({
      required List<String> items,
      required int selectedIndex,
      required ValueChanged<int> onSelectedItemChanged,
    }) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: Color.fromRGBO(53, 72, 154, 0.18),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListWheelScrollView.useDelegate(
            itemExtent: 48,
            diameterRatio: 1.4,
            overAndUnderCenterOpacity: 0.4,
            physics: const FixedExtentScrollPhysics(),
            perspective: 0.002,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                final bool isSelected = index == selectedIndex;
                return Center(
                  child: Text(
                    items[index],
                    style: TextStyle(
                      fontSize: isSelected ? 20 : 16,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF111111)
                          : const Color(0xFF8F95A6),
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
            onSelectedItemChanged: onSelectedItemChanged,
            controller: FixedExtentScrollController(initialItem: selectedIndex),
          ),
        ],
      );
    }

    final TimeOfDay? result = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 80,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                currentHourOptions = hourOptions(currentPeriod);
                if (!currentHourOptions.contains(currentHour)) {
                  currentHour = currentHourOptions.first;
                  currentHourIndex = 0;
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: buildPickerWheel(
                              items: currentHourOptions
                                  .map((hour) => hour.toString())
                                  .toList(),
                              selectedIndex: currentHourIndex,
                              onSelectedItemChanged: (index) {
                                setDialogState(() {
                                  currentHourIndex = index;
                                  currentHour = currentHourOptions[index];
                                });
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                          Expanded(
                            child: buildPickerWheel(
                              items: minuteOptions
                                  .map(
                                    (minute) =>
                                        minute.toString().padLeft(2, '0'),
                                  )
                                  .toList(),
                              selectedIndex: currentMinuteIndex,
                              onSelectedItemChanged: (index) {
                                setDialogState(() {
                                  currentMinuteIndex = index;
                                  currentMinute = minuteOptions[index];
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: buildPickerWheel(
                              items: const ['AM', 'PM'],
                              selectedIndex: currentPeriodIndex,
                              onSelectedItemChanged: (index) {
                                setDialogState(() {
                                  currentPeriodIndex = index;
                                  currentPeriod = index == 0 ? 'AM' : 'PM';
                                  currentHourOptions = hourOptions(
                                    currentPeriod,
                                  );
                                  if (!currentHourOptions.contains(
                                    currentHour,
                                  )) {
                                    currentHour = currentHourOptions.first;
                                    currentHourIndex = 0;
                                  } else {
                                    currentHourIndex = currentHourOptions
                                        .indexOf(currentHour);
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF35489A),
                              side: const BorderSide(color: Color(0xFF94A0D1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final int selectedHour = currentHour == 12
                                  ? (currentPeriod == 'AM' ? 0 : 12)
                                  : (currentPeriod == 'PM'
                                        ? currentHour + 12
                                        : currentHour);
                              Navigator.of(context).pop(
                                TimeOfDay(
                                  hour: selectedHour,
                                  minute: currentMinute,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF6C914),
                              foregroundColor: const Color(0xFF1A2254),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('OK'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        controller.text = _formatTimeOfDay(result);
      });
    }
  }

  TimeOfDay? _parseTime(String text) {
    if (text.isEmpty) return null;
    final String normalized = text.toUpperCase().trim();
    final RegExp match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AP]M)$');
    final RegExpMatch? parsed = match.firstMatch(normalized);
    if (parsed == null) return null;
    final int rawHour = int.parse(parsed.group(1)!);
    final int minute = int.parse(parsed.group(2)!);
    final String period = parsed.group(3)!;
    int hour = rawHour == 12 ? 0 : rawHour;
    if (period == 'PM') hour += 12;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: false);
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
                    'Venue Reservation',
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
              child: Padding(
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
                    Expanded(
                      child: _submitted
                          ? _buildSuccessCard()
                          : _buildRequestCard(),
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

  Widget _buildDetailsStep() {
    return Column(
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
                readOnly: true,
                onTap: () => _pickTime(_fromTimeController),
                decoration: _fieldDecoration(hintText: 'From').copyWith(
                  suffixIcon: const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF35489A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _toTimeController,
                readOnly: true,
                onTap: () => _pickTime(_toTimeController),
                decoration: _fieldDecoration(hintText: 'To').copyWith(
                  suffixIcon: const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF35489A),
                  ),
                ),
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
      ],
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

  Widget _buildStickyHeader() {
    if (_currentStep == 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              'Top Picks for You',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Recommended classrooms based on your preferences',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6A6F86), fontSize: 12),
            ),
            SizedBox(height: 18),
          ],
        ),
      );
    }

    if (_currentStep == 4) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              'Terms and Conditions',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'By proceeding, you agree to the room and equipment rental policies. You must accept the terms before submitting your request.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6A6F86),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            SizedBox(height: 18),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRequestCard() {
    final bool isFinal = _currentStep == 4;
    final bool hasStickyHeader = _currentStep == 2 || _currentStep == 4;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (hasStickyHeader) _buildStickyHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                children: [
                  _buildStepCard(),
                  const SizedBox(height: 18),
                  _buildStepButtons(isFinal: isFinal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsStep() {
    return Column(
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
      ],
    );
  }

  Widget _buildRecommendationsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF35489A), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF5B7CFF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'CONFIRMATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Review and Confirm Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1C2A5A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildReviewDetailRow(
                      icon: Icons.meeting_room_rounded,
                      label: 'Room',
                      value: _selectedRoomRecommendation ?? 'Not selected',
                    ),
                    _buildReviewDetailRow(
                      icon: Icons.note_alt_rounded,
                      label: 'Purpose',
                      value: _activityTitleController.text.isEmpty
                          ? 'Not specified'
                          : _activityTitleController.text,
                    ),
                    _buildReviewDetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value:
                          _fromTimeController.text.isEmpty ||
                              _toTimeController.text.isEmpty
                          ? 'Not specified'
                          : '${_fromTimeController.text} - ${_toTimeController.text}',
                    ),
                    _buildReviewDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: _dateController.text.isEmpty
                          ? 'Not specified'
                          : _dateController.text,
                    ),
                    _buildReviewDetailRow(
                      icon: Icons.people_rounded,
                      label: 'Capacity',
                      value: _selectedAttendance ?? 'Not selected',
                    ),
                    _buildReviewDetailRow(
                      icon: Icons.event_seat_rounded,
                      label: 'Chair',
                      value: _addChairs
                          ? (_selectedChairType ?? 'Selected')
                          : 'No Need',
                    ),
                    _buildReviewDetailRow(
                      icon: Icons.devices_rounded,
                      label: 'Equipment',
                      value: _addEquipment
                          ? (_selectedEquipmentType ?? 'Selected')
                          : 'No Need',
                    ),
                    _buildReviewDetailRow(
                      icon: Icons.category_rounded,
                      label: 'Miscellaneous',
                      value: _addMisc
                          ? (_selectedMiscType ?? 'Selected')
                          : 'No Need',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'By clicking the \u2018Next\u2019, you confirm that the details are correct.',
          style: TextStyle(color: Color(0xFF6A6F86), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildReviewDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF5B7CFF), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '''Terms and Conditions for Room & Equipment Rental
1. Proper Use and Cleanliness

- The borrowed room/equipment must be used strictly for its declared purpose (e.g., meetings, classes, workshops).
- Users are required to maintain cleanliness. Please turn off lights, air conditioning, and projectors after use, and ensure all trash is properly disposed of.

2. Liability for Damage or Loss

- The borrower assumes full responsibility for the room and all borrowed items/equipment during the approved duration.
- Any loss, malfunction, or damage caused by negligence or misuse must be reported immediately and will be subject to repair or replacement costs.

3. Punctuality and Extensions

- Rooms and equipment must be vacated/returned strictly on or before the end of the approved reservation time.
- If an extension is needed, a new request must be submitted through the app, subject to availability.

4. Prohibited Activities

- Bringing hazardous materials, unauthorized food/drinks (for specific labs/tech rooms), or engaging in disruptive behavior inside the reserved spaces is strictly prohibited.

5. Cancellation & Revocation

- Cancellations should be made at least 1 hour before the schedule.
- The administration reserves the right to cancel or revoke any approved booking in case of institutional emergencies or violation of university/company policies.''',
          style: TextStyle(color: Color(0xFF4F566A), fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 18),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _acceptedTerms,
          onChanged: (value) => setState(() {
            _acceptedTerms = value ?? false;
          }),
          title: const Text(
            'I accept the Terms and Conditions',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 6),
      ],
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF35489A), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                'Your venue reservation request has been submitted successfully.',
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
                  onPressed: () {
                    final reservation = ReservationRecord(
                      reservationTitle: _activityTitleController.text.isEmpty
                          ? 'Venue Reservation'
                          : _activityTitleController.text,
                      roomName:
                          _selectedRoomRecommendation ??
                          _selectedRoomType ??
                          'Venue Reservation',
                      reservationType: 'Venue Reservation',
                      reservationStatus: 'Pending Approval',
                      date: _selectedDate ?? DateTime.now(),
                      reservationTime:
                          '${_fromTimeController.text} - ${_toTimeController.text}',
                    );
                    ReservationActivityStore.upsert(reservation);

                    Navigator.of(context).pop({
                      'room':
                          _selectedRoomRecommendation ??
                          _selectedRoomType ??
                          'Venue Reservation',
                      'subtitle': 'Venue Reservation',
                      'status': 'Pending Approval',
                      'date': _dateController.text,
                      'time':
                          '${_fromTimeController.text} - ${_toTimeController.text}',
                    });
                  },
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    const int totalSteps = 5;
    final double progress = (_currentStep + 1) / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFDEE1E6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6C914),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalSteps, (stepIndex) {
            final bool isCompleted = stepIndex <= _currentStep;
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFF6C914)
                    : const Color(0xFFB5B9C1),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
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

class UserPage extends StatelessWidget {
  const UserPage({super.key});

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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6EAF9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xFF35489A),
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Juan Agoncillo Dela Cruz',
                                  style: TextStyle(
                                    color: Color(0xFF111111),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'BSIT - 3rd Year',
                                  style: TextStyle(
                                    color: Color(0xFF6A6F86),
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'delacruzja@nu-lipa.edu.ph',
                                  style: TextStyle(
                                    color: Color(0xFF6A6F86),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            color: const Color(0xFFE6EAF9),
                            icon: Icons.event_note_rounded,
                            value: '1',
                            label: 'Active Reservations',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildStatusCard(
                            color: const Color(0xFFFFF7D8),
                            icon: Icons.check_circle_outline,
                            value: '0',
                            label: 'Completed Requests',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ACCOUNT',
                      style: TextStyle(
                        color: Color(0xFF0F2B68),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Personal Details',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PersonalDetailsPage(),
                              ),
                            );
                          },
                        ),
                        _MenuItem(
                          icon: Icons.edit_outlined,
                          label: 'Edit Profile',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfilePage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'ACTIVITY',
                      style: TextStyle(
                        color: Color(0xFF0F2B68),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.history_rounded,
                          label: 'Reservation History',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReservationHistoryPage(),
                              ),
                            );
                          },
                        ),
                        _MenuItem(
                          icon: Icons.description_outlined,
                          label: 'Request History',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RequestHistoryPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'SUPPORT',
                      style: TextStyle(
                        color: Color(0xFF0F2B68),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.report_problem_outlined,
                          label: 'Report an Issue',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReportIssuePage(),
                              ),
                            );
                          },
                        ),
                        _MenuItem(
                          icon: Icons.help_outline,
                          label: 'Help & FAQ',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HelpFaqPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'ABOUT',
                      style: TextStyle(
                        color: Color(0xFF0F2B68),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      items: [
                        _MenuItem(
                          icon: Icons.info_outline,
                          label: 'About NUtilize',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AboutNutilizePage(),
                              ),
                            );
                          },
                        ),
                        _MenuItem(
                          icon: Icons.group_outlined,
                          label: 'About the Developers',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AboutDevelopersPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD22828),
                          side: const BorderSide(color: Color(0xFFD22828)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required Color color,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF35489A), size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6A6F86), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required List<_MenuItem> items}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: items
            .map(
              (item) => Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: const Color(0xFF35489A),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF6A6F86),
                      size: 22,
                    ),
                    onTap: item.onTap ?? () {},
                  ),
                  if (item != items.last)
                    const Divider(height: 1, indent: 78, endIndent: 18),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}
