import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';

class InstitutionalEventReservationPage extends StatefulWidget {
  const InstitutionalEventReservationPage({super.key});

  @override
  State<InstitutionalEventReservationPage> createState() =>
      _InstitutionalEventReservationPageState();
}

class _InstitutionalEventReservationPageState
    extends State<InstitutionalEventReservationPage> {
  static const _navy = Color(0xFF35489A);
  static const _brandRed = Color(0xFFE53935);
  static const _ink = Color(0xFF17213A);
  static const _muted = Color(0xFF69758D);
  static const _line = Color(0xFFDDE2EF);
  static const _canvas = Color(0xFFF3F5FB);
  static const _roomTypes = [
    'Classroom',
    'Gym',
    'AVR',
    'Lobby',
    'Student Lounge',
  ];
  static const _classroomTableTypes = [
    'Arm Chairs',
    'Trapezoidals',
    'Accounting Table',
  ];

  final _service = ReservationService();
  final _activityController = TextEditingController();
  final _quantityControllers = <int, TextEditingController>{};
  final _quantityByItem = <int, int>{};
  final _invalidEquipmentQuantityIds = <int>{};
  final _venueIndexByItem = <int, int>{};
  final _selectedRooms = <int, Room>{};
  final _visibleRoomTypes = _roomTypes.toSet();
  final _visibleClassroomTableTypes = _classroomTableTypes.toSet();
  final _startTimeByRoom = <int, TimeOfDay>{};
  final _endTimeByRoom = <int, TimeOfDay>{};
  final _roomAvailabilityById = <int, bool>{};
  final _equipmentAvailabilityByRoom = <int, Map<int, int>>{};
  int _availabilityRequestId = 0;

  List<Room> _rooms = [];
  List<ItemModel> _items = [];
  DateTime? _sharedDate;
  TimeOfDay? _sharedStartTime;
  TimeOfDay? _sharedEndTime;
  File? _proofFile;
  String? _proofUrl;
  bool _sharedSchedule = true;
  bool _outsideParticipants = false;
  bool _loading = true;
  bool _uploading = false;
  bool _submitting = false;
  bool _availabilityLoading = false;
  bool _equipmentAvailabilityLoading = false;
  String? _loadError;
  String? _availabilityError;
  String? _equipmentAvailabilityError;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    _activityController.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        Future.wait(_roomTypes.map(_service.getRoomsByType)),
        _service.getAllItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _rooms = (results[0] as List<List<Room>>)
            .expand((rooms) => rooms)
            .toList();
        _items = results[1] as List<ItemModel>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load venues and equipment: $error';
      });
    }
  }

  Future<void> _pickDate({int? roomId}) async {
    final now = DateTime.now();
    final earliest = DateTime(now.year, now.month, now.day + 3);
    final selected = roomId == null ? _sharedDate : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected ?? earliest,
      firstDate: earliest,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (roomId == null) {
        _sharedDate = picked;
      }
      if (roomId != null) _venueDates[roomId] = picked;
    });
    await _refreshAvailability();
  }

  final _venueDates = <int, DateTime>{};

  Future<void> _pickTime({required bool start, int? roomId}) async {
    final initial = roomId == null
        ? (start ? _sharedStartTime : _sharedEndTime)
        : (start ? _startTimeByRoom[roomId] : _endTimeByRoom[roomId]);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay(hour: start ? 8 : 9, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (roomId == null) {
        if (start) {
          _sharedStartTime = picked;
        } else {
          _sharedEndTime = picked;
        }
      } else if (start) {
        _startTimeByRoom[roomId] = picked;
      } else {
        _endTimeByRoom[roomId] = picked;
      }
    });
    await _refreshAvailability();
  }

  Future<void> _pickProof() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _proofFile = File(picked.path);
        _proofUrl = null;
        _uploading = true;
      });
      final userId = AuthService.currentUser?['user_id']?.toString();
      if (userId == null || userId.isEmpty) {
        throw StateError('Sign in again before uploading proof of consent.');
      }
      final path =
          '$userId/institutional_event_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _service.uploadProofOfConsent(_proofFile!, path);
      if (!mounted) return;
      setState(() {
        _proofUrl = _service.getProofOfConsentUrl(path);
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showMessage('Could not upload proof of consent: $error');
    }
  }

  DateTime? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  List<InstitutionalEventVenueSchedule>? _buildSchedules() {
    if (_selectedRooms.isEmpty) return null;
    final schedules = <InstitutionalEventVenueSchedule>[];
    for (final room in _selectedRooms.values) {
      final schedule = _scheduleForRoom(room);
      if (schedule == null) return null;
      schedules.add(schedule);
    }
    return schedules;
  }

  InstitutionalEventVenueSchedule? _scheduleForRoom(Room room) {
    final customDate = _venueDates[room.roomId];
    final customStart = _startTimeByRoom[room.roomId];
    final customEnd = _endTimeByRoom[room.roomId];
    final hasCustomSchedule =
        !_sharedSchedule &&
        (customDate != null || customStart != null || customEnd != null);
    if (hasCustomSchedule &&
        (customDate == null || customStart == null || customEnd == null)) {
      return null;
    }
    final useCustom = hasCustomSchedule;
    final date = useCustom ? customDate : _sharedDate;
    final start = _combine(date, useCustom ? customStart : _sharedStartTime);
    final end = _combine(date, useCustom ? customEnd : _sharedEndTime);
    if (start == null || end == null || !end.isAfter(start)) return null;
    return InstitutionalEventVenueSchedule(
      roomId: room.roomId,
      startTime: start,
      endTime: end,
    );
  }

  InstitutionalEventVenueSchedule? get _searchSchedule {
    final start = _combine(_sharedDate, _sharedStartTime);
    final end = _combine(_sharedDate, _sharedEndTime);
    if (start == null || end == null || !end.isAfter(start)) return null;
    return InstitutionalEventVenueSchedule(
      roomId: -1,
      startTime: start,
      endTime: end,
    );
  }

  Future<void> _refreshAvailability({bool clearSubmissionError = true}) async {
    final requestId = ++_availabilityRequestId;
    final filterSchedule = _searchSchedule;
    final scheduleByKey = <String, InstitutionalEventVenueSchedule>{};
    final roomIdsBySchedule = <String, List<int>>{};
    for (final room in _rooms) {
      final schedule = _selectedRooms.containsKey(room.roomId)
          ? _scheduleForRoom(room)
          : filterSchedule;
      if (schedule == null) continue;
      final key =
          '${schedule.startTime.toIso8601String()}|${schedule.endTime.toIso8601String()}';
      scheduleByKey[key] = schedule;
      roomIdsBySchedule.putIfAbsent(key, () => <int>[]).add(room.roomId);
    }
    setState(() {
      _availabilityLoading = scheduleByKey.isNotEmpty;
      _availabilityError = null;
      _equipmentAvailabilityLoading = _selectedRooms.isNotEmpty;
      _equipmentAvailabilityError = null;
      if (clearSubmissionError) _submissionError = null;
    });

    if (scheduleByKey.isEmpty) {
      setState(() {
        _roomAvailabilityById.clear();
        _availabilityLoading = false;
      });
    } else {
      try {
        final occupiedBySchedule = await Future.wait(
          scheduleByKey.values.map(
            (schedule) => _service.takenRoomIds(
              startTime: schedule.startTime,
              endTime: schedule.endTime,
            ),
          ),
        );
        if (!mounted || requestId != _availabilityRequestId) return;
        final availabilityByRoom = <int, bool>{};
        final scheduleKeys = scheduleByKey.keys.toList();
        for (var index = 0; index < scheduleKeys.length; index++) {
          final key = scheduleKeys[index];
          final occupiedRoomIds = occupiedBySchedule[index];
          for (final roomId in roomIdsBySchedule[key]!) {
            availabilityByRoom[roomId] = !occupiedRoomIds.contains(roomId);
          }
        }
        setState(() {
          _roomAvailabilityById
            ..clear()
            ..addAll(availabilityByRoom);
          _availabilityLoading = false;
        });
      } catch (error) {
        if (!mounted || requestId != _availabilityRequestId) return;
        setState(() {
          _roomAvailabilityById.clear();
          _availabilityLoading = false;
          _availabilityError =
              'Could not check venue availability. Retry before selecting a venue.';
        });
      }
    }

    final selectedSchedules = _selectedRooms.values
        .map(_scheduleForRoom)
        .whereType<InstitutionalEventVenueSchedule>()
        .toList();
    if (_selectedRooms.isEmpty ||
        selectedSchedules.length != _selectedRooms.length) {
      if (!mounted || requestId != _availabilityRequestId) return;
      setState(() {
        _equipmentAvailabilityByRoom.clear();
        _equipmentAvailabilityLoading = false;
      });
      return;
    }

    try {
      final results = await Future.wait(
        selectedSchedules.map(
          (schedule) => _service.getInstitutionalEventEquipmentAvailability(
            itemIds: _items.map((item) => item.itemId).toList(),
            startTime: schedule.startTime,
            endTime: schedule.endTime,
          ),
        ),
      );
      if (!mounted || requestId != _availabilityRequestId) return;
      setState(() {
        _equipmentAvailabilityByRoom
          ..clear()
          ..addEntries(
            selectedSchedules.asMap().entries.map(
              (entry) => MapEntry(entry.value.roomId, results[entry.key]),
            ),
          );
        _equipmentAvailabilityLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _availabilityRequestId) return;
      setState(() {
        _equipmentAvailabilityByRoom.clear();
        _equipmentAvailabilityLoading = false;
        _equipmentAvailabilityError =
            'Could not check equipment availability: $error. Retry before selecting equipment.';
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final userId = AuthService.currentUser?['user_id'];
    final schedules = _buildSchedules();
    if (userId is! int) {
      _showMessage('Please sign in again.');
      return;
    }
    if (_activityController.text.trim().isEmpty) {
      _showMessage('Enter the institutional event name.');
      return;
    }
    if (schedules == null) {
      _showMessage('Select venues and complete each venue schedule.');
      return;
    }
    final earliestAllowed = DateTime.now().add(const Duration(days: 2));
    if (schedules.any(
      (schedule) => schedule.startTime.isBefore(
        DateTime(
          earliestAllowed.year,
          earliestAllowed.month,
          earliestAllowed.day + 1,
        ),
      ),
    )) {
      _showMessage('Reservations must be made at least two days ahead.');
      return;
    }
    if (_uploading) {
      _showMessage('Wait for the proof of consent upload to finish.');
      return;
    }
    final proofOfConsentUrl = _proofUrl;
    if (_proofFile == null || proofOfConsentUrl == null) {
      _showMessage('Upload proof of consent before submitting.');
      return;
    }
    if (_quantityByItem.keys.any(
      (itemId) => _venueIndexByItem[itemId] == null,
    )) {
      _showMessage('Assign each selected equipment item to a venue.');
      return;
    }
    if (_invalidEquipmentQuantityIds.isNotEmpty) {
      _showMessage('Enter a whole-number quantity greater than zero.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final conflicts = <int>{};
      for (final schedule in schedules) {
        final taken = await _service.takenRoomIds(
          startTime: schedule.startTime,
          endTime: schedule.endTime,
        );
        if (taken.contains(schedule.roomId)) conflicts.add(schedule.roomId);
      }
      if (conflicts.isNotEmpty) {
        if (mounted) {
          setState(() {
            for (final roomId in conflicts) {
              _roomAvailabilityById[roomId] = false;
            }
            _availabilityLoading = false;
            _submissionError =
                'One or more selected venues are now occupied. Availability was refreshed; review the marked venues and try again.';
          });
          await _refreshAvailability(clearSubmissionError: false);
        }
        return;
      }
      final equipment = _quantityByItem.entries
          .map(
            (entry) => InstitutionalEventEquipmentRequest(
              itemId: entry.key,
              quantity: entry.value,
              venueIndex: _venueIndexByItem[entry.key]!,
            ),
          )
          .toList();
      for (var venueIndex = 0; venueIndex < schedules.length; venueIndex++) {
        final assignedEquipment = equipment
            .where((request) => request.venueIndex == venueIndex)
            .toList();
        if (assignedEquipment.isEmpty) continue;
        final schedule = schedules[venueIndex];
        final availableByItem = await _service
            .getInstitutionalEventEquipmentAvailability(
              itemIds: assignedEquipment
                  .map((request) => request.itemId)
                  .toList(),
              startTime: schedule.startTime,
              endTime: schedule.endTime,
            );
        for (final request in assignedEquipment) {
          final available = availableByItem[request.itemId] ?? 0;
          if (request.quantity > available) {
            final item = _items.firstWhere(
              (candidate) => candidate.itemId == request.itemId,
            );
            if (mounted) {
              setState(() {
                _equipmentAvailabilityByRoom[schedule.roomId] = availableByItem;
                _submissionError =
                    'Only $available ${item.itemName} ${available == 1 ? 'unit is' : 'units are'} available for the selected time. Update the quantity or choose another venue schedule.';
              });
              await _refreshAvailability(clearSubmissionError: false);
            }
            return;
          }
        }
      }
      final reservationId = await _service.createInstitutionalEventReservation(
        activityName: _activityController.text.trim(),
        userId: userId,
        venues: schedules,
        equipment: equipment,
        hasOutsideParticipants: _outsideParticipants,
        proofOfConsentUrl: proofOfConsentUrl,
      );
      if (!mounted) return;
      final submittedAt = DateTime.now();
      ReservationActivityStore.add(
        ReservationRecord(
          id: reservationId.toString(),
          userId: userId,
          reservationTitle: _activityController.text.trim(),
          roomName: _compactSelectedVenueNames(),
          reservationType: 'Institutional Event Reservation',
          reservationStatus: 'Pending Approval',
          date: schedules.first.startTime,
          reservationTime: 'Multiple venue schedules',
          eventVenues: schedules.asMap().entries.map((entry) {
            final schedule = entry.value;
            final room = _selectedRooms[schedule.roomId]!;
            final venueEquipment = equipment
                .where((request) => request.venueIndex == entry.key)
                .map((request) {
                  final item = _items.firstWhere(
                    (candidate) => candidate.itemId == request.itemId,
                  );
                  return ReservationEquipmentDetail(
                    name: item.itemName,
                    quantity: request.quantity,
                  );
                })
                .toList();
            return ReservationVenueDetail(
              name: _venueDisplayName(room),
              startTime: schedule.startTime,
              endTime: schedule.endTime,
              equipment: venueEquipment,
            );
          }).toList(),
          reservedItems: equipment.map((item) {
            final model = _items.firstWhere(
              (candidate) => candidate.itemId == item.itemId,
            );
            return '${model.itemName} (${item.quantity})';
          }).toList(),
          timeline: [
            ReservationTimelineEntry(
              title: 'Request Submitted',
              status: 'Completed',
              date: submittedAt,
              timestamp: MaterialLocalizations.of(
                context,
              ).formatMediumDate(submittedAt),
              description: 'Institutional Event request submitted.',
            ),
            ReservationTimelineEntry(
              title: 'Approval in Progress',
              status: 'Pending',
              date: DateTime(2000),
              timestamp: 'Pending',
              description:
                  'Waiting for the required offices to review the event.',
            ),
          ],
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Institutional Event request submitted.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().toLowerCase();
      final isConflict =
          detail.contains('23p01') ||
          detail.contains('23505') ||
          detail.contains('conflict') ||
          detail.contains('overlap') ||
          detail.contains('already reserved') ||
          detail.contains('not enough available units');
      setState(() {
        _submissionError = isConflict
            ? 'A selected venue or equipment unit was just reserved for an overlapping time. Availability was refreshed; review the marked resources and try again.'
            : 'Could not submit the Institutional Event request. Please check your selections and try again.';
      });
      if (isConflict) {
        await _refreshAvailability(clearSubmissionError: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _compactSelectedVenueNames() {
    final names = _selectedRooms.values.map(_venueDisplayName).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names[0]}, ${names[1]} +${names.length - 2} more';
  }

  String _venueDisplayName(Room room) {
    final number = room.roomNumber.trim();
    final type = room.roomType.trim();
    return number.isEmpty || number.toLowerCase() == type.toLowerCase()
        ? type
        : '$type $number';
  }

  String _dateLabel(DateTime? value) => value == null
      ? 'Choose date'
      : MaterialLocalizations.of(context).formatMediumDate(value);

  String _timeLabel(TimeOfDay? value) => value == null
      ? 'Choose time'
      : MaterialLocalizations.of(context).formatTimeOfDay(value);

  @override
  Widget build(BuildContext context) {
    final isProgramChair =
        AuthService.programIdForProgramChairRole(
          AuthService.currentUser?['role']?.toString(),
        ) !=
        null;
    final isDean = AuthService.isDeanRole(
      AuthService.currentUser?['role']?.toString(),
    );
    if (!isProgramChair && !isDean) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Institutional Event requests are for Program Chairs and Deans.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        title: const Text('Institutional Event Reservation'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadResources,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [
                _pageIntro(),
                if (_submissionError != null) ...[
                  const SizedBox(height: 12),
                  _submissionErrorCard(),
                ],
                const SizedBox(height: 18),
                _section(
                  icon: Icons.event_note_rounded,
                  title: 'Event details',
                  subtitle: 'Start with a clear name for your event.',
                  child: TextField(
                    controller: _activityController,
                    decoration: const InputDecoration(
                      labelText: 'Institutional event name',
                      hintText: 'Enter the event or activity name',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.schedule_rounded,
                  title: 'Date and time',
                  subtitle:
                      'Choose a time first to check which venues are occupied.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _sharedSchedule,
                        title: const Text(
                          'Use one date and time for all venues',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Turn off to customize times after choosing venues.',
                        ),
                        activeThumbColor: _navy,
                        onChanged: (value) {
                          setState(() => _sharedSchedule = value);
                          _refreshAvailability();
                        },
                      ),
                      _scheduleControls(),
                      if (!_sharedSchedule && _selectedRooms.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Custom venue schedules',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._selectedRooms.values.map(
                          (room) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _venueLabel(room),
                                _scheduleControls(roomId: room.roomId),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.location_on_rounded,
                  title: 'Choose venues',
                  subtitle:
                      'Select every venue that is available for your schedule.',
                  child: _venuePicker(),
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.inventory_2_rounded,
                  title: 'Borrowed equipment (optional)',
                  subtitle:
                      'Each item follows the schedule of its assigned venue.',
                  child: _equipmentPicker(),
                ),
                const SizedBox(height: 12),
                _section(
                  icon: Icons.groups_rounded,
                  title: 'Participants and consent',
                  subtitle: 'Let the approval offices know who will attend.',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _outsideParticipants,
                        title: const Text(
                          'Outside participants are attending',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        activeThumbColor: _navy,
                        onChanged: (value) =>
                            setState(() => _outsideParticipants = value),
                      ),
                      const SizedBox(height: 8),
                      _proofConsentTile(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: !_loading && _loadError == null
          ? _submitBar()
          : null,
    );
  }

  Widget _pageIntro() {
    final selectedCount = _selectedRooms.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: .16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Plan your event',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reserve multiple campus venues and any equipment together in one request.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _introPill(
                Icons.location_on_outlined,
                '$selectedCount ${selectedCount == 1 ? 'venue' : 'venues'}',
              ),
              _introPill(Icons.schedule_rounded, 'Flexible schedules'),
              _introPill(Icons.inventory_2_outlined, 'Optional equipment'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _introPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _submissionErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brandRed.withValues(alpha: .25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _brandRed, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _submissionError!,
              style: const TextStyle(
                color: Color(0xFF8E3A3A),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _submissionError = null),
            icon: const Icon(Icons.close_rounded, size: 18),
            color: _brandRed,
          ),
        ],
      ),
    );
  }

  Widget _venuePicker() {
    if (_rooms.isEmpty) {
      return _emptyHint(
        'No venues are available right now.',
        Icons.info_outline,
      );
    }
    final hasSearch = _rooms.any((room) {
      return (_selectedRooms.containsKey(room.roomId)
              ? _scheduleForRoom(room)
              : _searchSchedule) !=
          null;
    });
    final visibleRooms = _rooms.where((room) {
      if (!_visibleRoomTypes.contains(room.roomType)) return false;
      if (room.roomType.toLowerCase() != 'classroom') return true;
      final tableType = _normalizeClassroomTableType(room.roomTableType);
      return tableType != null &&
          _visibleClassroomTableTypes.contains(tableType);
    }).toList();
    return Column(
      children: [
        _roomTypeFilters(),
        if (_visibleRoomTypes.contains('Classroom')) ...[
          const SizedBox(height: 8),
          _classroomTableTypeFilters(),
        ],
        if (_selectedRooms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Selected:',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ..._selectedRooms.values.map(
                  (room) => Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${room.roomType} · ${room.roomNumber}'),
                    onDeleted: () => _toggleRoom(room),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!hasSearch)
          _emptyHint(
            'Choose a date, start time, and end time above to check venue availability.',
            Icons.event_available_rounded,
          )
        else if (_availabilityError != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: _brandRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _availabilityError!,
                    style: const TextStyle(
                      color: Color(0xFF8E3A3A),
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _refreshAvailability,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_availabilityLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _navy,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Checking availability for this time…',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF24845B),
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    "Availability checked against each venue's selected date and time.",
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (visibleRooms.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _emptyHint(
              _visibleRoomTypes.isEmpty
                  ? 'Select one or more venue types to see rooms.'
                  : 'There are no venues in the selected categories.',
              Icons.filter_list_rounded,
            ),
          ),
        ...visibleRooms.map((room) {
          final selected = _selectedRooms.containsKey(room.roomId);
          final roomSchedule = selected
              ? _scheduleForRoom(room)
              : _searchSchedule;
          final occupied =
              roomSchedule != null &&
              _roomAvailabilityById[room.roomId] == false;
          final available = _roomAvailabilityById[room.roomId] == true;
          final canSelect =
              selected ||
              (roomSchedule != null &&
                  !_availabilityLoading &&
                  _availabilityError == null &&
                  available);
          final capacity = room.roomCapacity == null
              ? null
              : 'Capacity ${room.roomCapacity}';
          final availabilityText = occupied
              ? 'Occupied'
              : selected
              ? 'Selected'
              : roomSchedule == null
              ? 'Choose date and time'
              : _availabilityLoading
              ? 'Checking availability…'
              : _availabilityError != null
              ? 'Availability not confirmed'
              : available
              ? 'Available'
              : 'Unavailable';
          final availabilityColor = occupied
              ? _brandRed
              : selected
              ? _navy
              : const Color(0xFF24845B);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected
                  ? const Color(0xFFF0F3FF)
                  : occupied
                  ? const Color(0xFFFFF2F0)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: canSelect ? () => _toggleRoom(room) : null,
                child: Opacity(
                  opacity: canSelect ? 1 : .65,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: occupied
                            ? _brandRed.withValues(alpha: .25)
                            : selected
                            ? _navy.withValues(alpha: .45)
                            : _line,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: occupied
                                ? const Color(0xFFFFE7E5)
                                : selected
                                ? _navy.withValues(alpha: .1)
                                : const Color(0xFFF1F4F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconForRoom(room.roomType),
                            color: occupied
                                ? _brandRed
                                : selected
                                ? _navy
                                : _muted,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${room.roomType} · ${room.roomNumber}',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 3,
                                children: [
                                  if (capacity != null)
                                    Text(
                                      capacity,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (roomSchedule != null)
                                    Text(
                                      '${_dateLabel(roomSchedule.startTime)} · ${_timeLabel(TimeOfDay.fromDateTime(roomSchedule.startTime))}–${_timeLabel(TimeOfDay.fromDateTime(roomSchedule.endTime))}',
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    availabilityText,
                                    style: TextStyle(
                                      color: availabilityColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          occupied
                              ? Icons.block_rounded
                              : selected
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          color: occupied
                              ? _brandRed
                              : selected
                              ? _navy
                              : _muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _roomTypeFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter by venue type',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_visibleRoomTypes.length == _roomTypes.length) {
                        _visibleRoomTypes.clear();
                      } else {
                        _visibleRoomTypes
                          ..clear()
                          ..addAll(_roomTypes);
                      }
                    });
                  },
                  child: Text(
                    _visibleRoomTypes.length == _roomTypes.length
                        ? 'Clear'
                        : 'Select all',
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _roomTypes.map((type) {
                final checked = _visibleRoomTypes.contains(type);
                return SizedBox(
                  width: width,
                  child: CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _navy,
                    value: checked,
                    title: Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _visibleRoomTypes.add(type);
                        } else {
                          _visibleRoomTypes.remove(type);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  String? _normalizeClassroomTableType(String? value) {
    final normalized = (value ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    if (normalized == 'armchair' || normalized == 'armchairs') {
      return 'Arm Chairs';
    }
    if (normalized == 'trapezoidal' || normalized == 'trapezoidals') {
      return 'Trapezoidals';
    }
    if (normalized == 'accountingtable' || normalized == 'accountingtables') {
      return 'Accounting Table';
    }
    return null;
  }

  Widget _classroomTableTypeFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Classroom table type',
              style: TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ..._classroomTableTypes.map((type) {
            final checked = _visibleClassroomTableTypes.contains(type);
            return CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _navy,
              value: checked,
              title: Text(type, style: const TextStyle(fontSize: 12)),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _visibleClassroomTableTypes.add(type);
                  } else {
                    _visibleClassroomTableTypes.remove(type);
                  }
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _toggleRoom(Room room) async {
    setState(() {
      final oldRooms = _selectedRooms.values.toList();
      if (_selectedRooms.containsKey(room.roomId)) {
        _selectedRooms.remove(room.roomId);
        _venueDates.remove(room.roomId);
        _startTimeByRoom.remove(room.roomId);
        _endTimeByRoom.remove(room.roomId);
      } else {
        _selectedRooms[room.roomId] = room;
      }
      final newRooms = _selectedRooms.values.toList();
      for (final itemId in _venueIndexByItem.keys.toList()) {
        final oldIndex = _venueIndexByItem[itemId]!;
        if (oldIndex >= oldRooms.length) {
          _venueIndexByItem.remove(itemId);
          continue;
        }
        final assignedRoomId = oldRooms[oldIndex].roomId;
        final newIndex = newRooms.indexWhere(
          (selectedRoom) => selectedRoom.roomId == assignedRoomId,
        );
        if (newIndex == -1) {
          _venueIndexByItem.remove(itemId);
        } else {
          _venueIndexByItem[itemId] = newIndex;
        }
      }
    });
    await _refreshAvailability();
  }

  IconData _iconForRoom(String roomType) {
    switch (roomType.toLowerCase()) {
      case 'gym':
        return Icons.sports_basketball_rounded;
      case 'avr':
        return Icons.present_to_all_rounded;
      case 'lobby':
        return Icons.meeting_room_rounded;
      case 'student lounge':
        return Icons.weekend_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  Widget _venueLabel(Room room) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(_iconForRoom(room.roomType), color: _navy, size: 18),
          const SizedBox(width: 8),
          Text(
            '${room.roomType} · ${room.roomNumber}',
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  int? _equipmentAvailableForItem(int itemId, int? venueIndex) {
    if (venueIndex != null && venueIndex < _selectedRooms.length) {
      final room = _selectedRooms.values.elementAt(venueIndex);
      return _equipmentAvailabilityByRoom[room.roomId]?[itemId];
    }
    final availableCounts = _selectedRooms.values
        .map((room) => _equipmentAvailabilityByRoom[room.roomId]?[itemId])
        .whereType<int>()
        .toList();
    if (availableCounts.isEmpty) return null;
    return availableCounts.reduce((minimum, count) {
      return count < minimum ? count : minimum;
    });
  }

  Widget _equipmentPicker() {
    if (_items.isEmpty) {
      return _emptyHint(
        'No equipment is listed. You can continue without borrowing equipment.',
        Icons.inventory_2_outlined,
      );
    }
    final schedulesReady =
        _selectedRooms.isNotEmpty &&
        _selectedRooms.values.every((room) => _scheduleForRoom(room) != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_equipmentAvailabilityError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _brandRed.withValues(alpha: .2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: _brandRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _equipmentAvailabilityError!,
                    style: const TextStyle(
                      color: Color(0xFF8E3A3A),
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _refreshAvailability(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_equipmentAvailabilityLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _navy,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Checking equipment for the selected schedules…',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          )
        else if (!schedulesReady)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Select venues and complete their schedules to see equipment availability.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ),
        ..._items.map((item) {
          final selected = _quantityByItem.containsKey(item.itemId);
          final index = _venueIndexByItem[item.itemId];
          final available = _equipmentAvailableForItem(item.itemId, index);
          final availableKnown = available != null && schedulesReady;
          final unavailable =
              !item.availabilityStatus ||
              item.maintenanceStatus ||
              (availableKnown && available == 0);
          final canSelect =
              schedulesReady &&
              !_equipmentAvailabilityLoading &&
              _equipmentAvailabilityError == null &&
              available != null &&
              available > 0 &&
              item.availabilityStatus &&
              !item.maintenanceStatus;
          final quantity = _quantityByItem[item.itemId] ?? 1;
          final quantityIsInvalid =
              selected &&
              (_invalidEquipmentQuantityIds.contains(item.itemId) ||
                  quantity <= 0);
          final quantityError =
              quantityIsInvalid ||
              (selected && availableKnown && quantity > available);
          final availabilityLabel = !item.availabilityStatus
              ? 'Unavailable'
              : item.maintenanceStatus
              ? 'Under maintenance'
              : !schedulesReady
              ? 'Choose venue and time'
              : _equipmentAvailabilityLoading
              ? 'Checking availability…'
              : _equipmentAvailabilityError != null
              ? 'Availability not confirmed'
              : available == null
              ? 'Unavailable'
              : available == 0
              ? 'In use · Unavailable for this time'
              : '$available available for this time';
          final availabilityColor = unavailable
              ? _brandRed
              : canSelect
              ? const Color(0xFF24845B)
              : _muted;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFF0F3FF)
                  : unavailable
                  ? const Color(0xFFFFF2F0)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: unavailable
                    ? _brandRed.withValues(alpha: .22)
                    : selected
                    ? _navy.withValues(alpha: .35)
                    : _line,
              ),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: _navy,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected,
                  title: Text(
                    item.itemName,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    availabilityLabel,
                    style: TextStyle(
                      color: availabilityColor,
                      fontSize: 12,
                      fontWeight: unavailable || !canSelect
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  onChanged: selected || canSelect
                      ? (checked) => setState(() {
                          if (checked == true) {
                            _invalidEquipmentQuantityIds.remove(item.itemId);
                            _quantityByItem[item.itemId] = 1;
                            _quantityControllers[item.itemId] =
                                TextEditingController(text: '1');
                            _venueIndexByItem[item.itemId] = index ?? 0;
                          } else {
                            _quantityByItem.remove(item.itemId);
                            _invalidEquipmentQuantityIds.remove(item.itemId);
                            _venueIndexByItem.remove(item.itemId);
                            _quantityControllers.remove(item.itemId)?.dispose();
                          }
                        })
                      : null,
                ),
                if (selected) ...[
                  const Divider(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 108,
                        child: TextField(
                          controller: _quantityControllers[item.itemId],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon: const Icon(
                              Icons.numbers_rounded,
                              size: 18,
                            ),
                            errorText: quantityIsInvalid
                                ? 'Enter a positive quantity'
                                : quantityError
                                ? 'Only $available available'
                                : null,
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            setState(() {
                              _submissionError = null;
                              if (parsed != null && parsed > 0) {
                                _invalidEquipmentQuantityIds.remove(
                                  item.itemId,
                                );
                                _quantityByItem[item.itemId] = parsed;
                              } else {
                                _invalidEquipmentQuantityIds.add(item.itemId);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: index,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Assigned venue',
                            prefixIcon: Icon(Icons.place_outlined, size: 18),
                          ),
                          items: _selectedRooms.values
                              .toList()
                              .asMap()
                              .entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    '${entry.value.roomType} · ${entry.value.roomNumber}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _selectedRooms.isEmpty
                              ? null
                              : (value) => setState(() {
                                  if (value != null) {
                                    _venueIndexByItem[item.itemId] = value;
                                    _submissionError = null;
                                  }
                                }),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _proofConsentTile() {
    final isUploaded = _proofUrl != null;
    return Material(
      color: isUploaded ? const Color(0xFFEEF8F2) : const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _uploading ? null : _pickProof,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isUploaded ? const Color(0xFFD9F0E3) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUploaded ? Icons.check_rounded : Icons.upload_file_rounded,
                  color: isUploaded ? const Color(0xFF24845B) : _navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proof of consent',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _uploading
                          ? 'Uploading your file…'
                          : isUploaded
                          ? 'Uploaded successfully'
                          : 'Required · Tap to upload an image',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_uploading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _navy,
                  ),
                )
              else
                Icon(
                  isUploaded ? Icons.check_circle : Icons.arrow_forward_ios,
                  size: isUploaded ? 20 : 16,
                  color: isUploaded ? const Color(0xFF24845B) : _muted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyHint(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _muted, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _line)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: .05),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: _submitting || _uploading ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _submitting ? 'Submitting request…' : 'Submit event reservation',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _scheduleControls({int? roomId}) {
    final date = roomId == null ? _sharedDate : _venueDates[roomId];
    final start = roomId == null ? _sharedStartTime : _startTimeByRoom[roomId];
    final end = roomId == null ? _sharedEndTime : _endTimeByRoom[roomId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(roomId: roomId),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(_dateLabel(date)),
              style: _scheduleButtonStyle,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(start: true, roomId: roomId),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    _timeLabel(start),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: _scheduleButtonStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(start: false, roomId: roomId),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: Text(_timeLabel(end), overflow: TextOverflow.ellipsis),
                  style: _scheduleButtonStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle get _scheduleButtonStyle => OutlinedButton.styleFrom(
    alignment: Alignment.centerLeft,
    foregroundColor: _navy,
    side: const BorderSide(color: _line),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _section({
    required String title,
    IconData? icon,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: .025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3FF),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: _navy, size: 19),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          height: 1.35,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
