import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';

// MARK: - Models

class Room {
  final int roomId;
  final String roomNumber;
  final String roomType; // Classroom, Gym, AVR, Lobby, Student Lounge
  final String? roomTableType; // For classrooms: arm chair, trapezoidal, accounting table
  final int? roomCapacity;
  final int? roomChairQuantity;
  final int? roomTableCount;
  final bool maintenanceStatus;
  final bool availabilityStatus;

  Room({
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    this.roomTableType,
    this.roomCapacity,
    this.roomChairQuantity,
    this.roomTableCount,
    required this.maintenanceStatus,
    required this.availabilityStatus,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['room_id'] as int,
      roomNumber: json['room_number'] as String,
      roomType: json['room_type'] as String,
      roomTableType: json['room_table_type'] as String?,
      roomCapacity: json['room_capacity'] as int?,
      roomChairQuantity: json['room_chair_quantity'] as int?,
      roomTableCount: json['room_table_count'] as int?,
      maintenanceStatus: json['maintenance_status'] as bool? ?? false,
      availabilityStatus: json['availability_status'] as bool? ?? true,
    );
  }
}

class ItemModel {
  final int itemId;
  final String itemName;
  final int quantityTotal;
  final int quantityInUse;
  final int? ownerId;
  final String? ownerName;
  final bool maintenanceStatus;
  final bool availabilityStatus;

  int get availableQuantity => quantityTotal - quantityInUse;

  ItemModel({
    required this.itemId,
    required this.itemName,
    required this.quantityTotal,
    required this.quantityInUse,
    this.ownerId,
    this.ownerName,
    required this.maintenanceStatus,
    required this.availabilityStatus,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String,
      quantityTotal: json['quantity_total'] as int? ?? 0,
      quantityInUse: json['quantity_in_use'] as int? ?? 0,
      ownerId: json['owner_id'] as int?,
      ownerName: json['item_owners']?['owner_name'] as String?,
      maintenanceStatus: json['maintenance_status'] as bool? ?? false,
      availabilityStatus: json['availability_status'] as bool? ?? true,
    );
  }
}

class ReservationSlot {
  final DateTime startTime;
  final DateTime endTime;
  final int roomId;
  final int reservationId;
  final String status;

  ReservationSlot({
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.reservationId,
    required this.status,
  });
}

class ApprovalChain {
  final List<String> offices; // List of office names in approval order
  final List<int> officeIds;

  ApprovalChain({required this.offices, required this.officeIds});
}

// MARK: - ReservationService

class ReservationService {
  static final ReservationService _instance = ReservationService._internal();

  factory ReservationService() {
    return _instance;
  }

  ReservationService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // MARK: - Room Operations

  /// Fetch all rooms of a specific type
  Future<List<Room>> getRoomsByType(String roomType) async {
    try {
      final response = await _client
          .from('rooms')
          .select()
          .eq('room_type', roomType)
          .eq('maintenance_status', false)
          .eq('availability_status', true);

      return (response as List)
          .map((room) => Room.fromJson(room as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching rooms: $e');
      return [];
    }
  }

  /// Get rooms filtered by type and table type (for classrooms)
  Future<List<Room>> getClassroomsByTableType(String tableType) async {
    try {
      // Fetch all classrooms and filter by table type (case-insensitive in memory)
      final response = await _client
          .from('rooms')
          .select()
          .eq('room_type', 'Classroom')
          .eq('maintenance_status', false)
          .eq('availability_status', true);

      print('DEBUG: Total classrooms fetched: ${response.length}');
      print('DEBUG: Looking for table type: "$tableType"');
      
      // Normalize for comparison: remove spaces and convert to lowercase
      final normalizedTableType = tableType.replaceAll(' ', '').toLowerCase();
      
      // Filter results by table type (case-insensitive, space-insensitive)
      final filteredRooms = (response as List)
          .where((room) {
            final roomTableType = room['room_table_type'] as String?;
            final normalizedRoomType = roomTableType?.replaceAll(' ', '').toLowerCase() ?? '';
            final matches = normalizedRoomType == normalizedTableType;
            print('DEBUG: Room ${room['room_id']} - ${room['room_number']} - table_type: "$roomTableType" (normalized: "$normalizedRoomType" vs "$normalizedTableType") (matches: $matches)');
            return matches;
          })
          .toList();

      print('DEBUG: Filtered rooms for "$tableType": ${filteredRooms.length}');

      return filteredRooms
          .map((room) => Room.fromJson(room as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching classrooms: $e');
      return [];
    }
  }

  /// Check if a specific room has time conflicts
  Future<bool> hasTimeConflict({
    required int roomId,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime reservationDate,
  }) async {
    try {
      final dayStart = DateTime(
        reservationDate.year,
        reservationDate.month,
        reservationDate.day,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));

      final response = await _client
          .from('reservations')
          .select('reservation_id, Date_of_Activity, Start_of_activity, End_of_Activity')
          .gte('Date_of_Activity', dayStart.toIso8601String())
          .lt('Date_of_Activity', dayEnd.toIso8601String())
          .neq('overall_status', 'Cancelled');

      print('DEBUG hasTimeConflict: Room $roomId - Found ${response.length} reservations on date ${reservationDate.toIso8601String()}');

      if (response.isEmpty) {
        print('DEBUG hasTimeConflict: Room $roomId - No conflicts (no reservations)');
        return false;
      }

      for (final res in response as List) {
        final resDate = DateTime.parse(res['Date_of_Activity'] as String);
        if (resDate.year != reservationDate.year ||
            resDate.month != reservationDate.month ||
            resDate.day != reservationDate.day) {
          continue;
        }

        final resStart = DateTime.parse(res['Start_of_activity'] as String);
        final resEnd = DateTime.parse(res['End_of_Activity'] as String);

        if (startTime.isBefore(resEnd) && endTime.isAfter(resStart)) {
          final detailResponse = await _client
              .from('reservation_details')
              .select('reservation_rooms_id')
              .eq('reservation_id', res['reservation_id']);

          for (final detail in detailResponse as List) {
            final roomReservationId = detail['reservation_rooms_id'] as int?;
            if (roomReservationId == null) {
              continue;
            }

            final roomSelection = await _client
                .from('reservation_rooms')
                .select('room_id')
                .eq('reservation_rooms_id', roomReservationId)
                .maybeSingle();

            if (roomSelection != null && roomSelection['room_id'] == roomId) {
              print('DEBUG hasTimeConflict: Room $roomId - HAS CONFLICT');
              return true;
            }
          }
        }
      }

      print('DEBUG hasTimeConflict: Room $roomId - No conflicts');
      return false;
    } catch (e) {
      print('Error checking time conflict: $e');
      return false;
    }
  }

  /// Get all reservations for a specific room on a specific date
  Future<List<ReservationSlot>> getRoomReservationsForDate(
    int roomId,
    DateTime date,
  ) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final response = await _client
          .from('reservations')
          .select('reservation_id, Date_of_Activity, Start_of_activity, End_of_Activity, overall_status')
          .gte('Date_of_Activity', dayStart.toIso8601String())
          .lt('Date_of_Activity', dayEnd.toIso8601String())
          .neq('overall_status', 'Cancelled');

      final reservations = <ReservationSlot>[];

      for (final res in response as List) {
        final detailResponse = await _client
            .from('reservation_details')
            .select('reservation_rooms_id')
            .eq('reservation_id', res['reservation_id']);

        for (final detail in detailResponse as List) {
          final roomReservationId = detail['reservation_rooms_id'] as int?;
          if (roomReservationId == null) {
            continue;
          }

          final roomSelection = await _client
              .from('reservation_rooms')
              .select('room_id')
              .eq('reservation_rooms_id', roomReservationId)
              .maybeSingle();

          if (roomSelection != null && roomSelection['room_id'] == roomId) {
            reservations.add(
              ReservationSlot(
                startTime: DateTime.parse(res['Start_of_activity'] as String),
                endTime: DateTime.parse(res['End_of_Activity'] as String),
                roomId: roomId,
                reservationId: res['reservation_id'] as int,
                status: res['overall_status'] as String? ?? 'Pending',
              ),
            );
            break;
          }
        }
      }

      return reservations;
    } catch (e) {
      print('Error fetching room reservations: $e');
      return [];
    }
  }

  // MARK: - Item Operations

  /// Fetch all available items from the database
  Future<List<ItemModel>> getAllItems() async {
    try {
      final response = await _client
          .from('items')
          .select('*, item_owners(owner_name)')
          .eq('maintenance_status', false)
          .eq('availability_status', true);

      return (response as List)
          .map((item) => ItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching items: $e');
      return [];
    }
  }

  /// Get item details including current usage
  Future<ItemModel?> getItemDetails(int itemId) async {
    try {
      final response = await _client
          .from('items')
          .select('*, item_owners(owner_name)')
          .eq('item_id', itemId)
          .single();

      return ItemModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching item details: $e');
      return null;
    }
  }

  /// Fetch reservations created by a specific user.
  Future<List<ReservationRecord>> getReservationRecordsForUser(int userId) async {
    try {
      final reservationsResponse = await _client
          .from('reservations')
          .select('reservation_id, activity_name, overall_status, Date_of_Activity, Start_of_activity, End_of_Activity')
          .eq('user_id', userId)
          .order('Date_of_Activity', ascending: false);

      if (reservationsResponse == null) {
        return [];
      }

      final List<ReservationRecord> records = [];
      for (final res in reservationsResponse as List) {
        final reservationId = res['reservation_id'] as int;
        final roomName = await _fetchReservationRoomName(reservationId) ?? 'Reserved Room';
        final date = DateTime.parse(res['Date_of_Activity'] as String);
        final startTime = DateTime.parse(res['Start_of_activity'] as String);
        final endTime = DateTime.parse(res['End_of_Activity'] as String);
        final reservationTime = '${_formatDateTime(startTime)} - ${_formatDateTime(endTime)}';
      final timeline = await _buildApprovalTimeline(reservationId, date);

        records.add(ReservationRecord(
          id: reservationId.toString(),
          userId: userId,
          reservationTitle: res['activity_name'] as String? ?? 'Reservation Request',
          roomName: roomName,
          reservationType: 'Venue Reservation',
          reservationStatus: res['overall_status'] as String? ?? 'Pending Approval',
          date: date,
          reservationTime: reservationTime,
          timeline: timeline,
        ));
      }

      return records;
    } catch (e) {
      print('Error fetching user reservations: $e');
      return [];
    }
  }

  Future<String?> _fetchReservationRoomName(int reservationId) async {
    try {
      final detailResponse = await _client
          .from('reservation_details')
          .select('reservation_rooms_id')
          .eq('reservation_id', reservationId)
          .limit(1)
          .maybeSingle();

      final roomReservationId = detailResponse?['reservation_rooms_id'] as int?;
      if (roomReservationId == null) {
        return 'Room Reservation';
      }

      final roomReservationResponse = await _client
          .from('reservation_rooms')
          .select('room_id')
          .eq('reservation_rooms_id', roomReservationId)
          .limit(1)
          .maybeSingle();
      final roomId = roomReservationResponse?['room_id'] as int?;
      if (roomId == null) {
        return 'Room Reservation';
      }

      final roomResponse = await _client
          .from('rooms')
          .select('room_number, room_type')
          .eq('room_id', roomId)
          .limit(1)
          .maybeSingle();
      if (roomResponse == null) {
        return 'Room Reservation';
      }

      final roomNumber = roomResponse['room_number'] as String?;
      final roomType = roomResponse['room_type'] as String?;
      if (roomNumber != null && roomNumber.isNotEmpty) {
        return roomNumber;
      }
      if (roomType != null && roomType.isNotEmpty) {
        return roomType;
      }
      return 'Room Reservation';
    } catch (_) {
      return 'Room Reservation';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatTimestamp(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} $hour:$minute $period';
  }

  DateTime buildApprovalTimestampForStep(int step, {DateTime? baseTime}) {
    final base = (baseTime ?? DateTime.now()).toUtc();
    return base.add(Duration(milliseconds: step));
  }

  static List<Map<String, dynamic>> sortApprovalEntriesForTimeline(
    List<Map<String, dynamic>> approvals,
  ) {
    final ordered = List<Map<String, dynamic>>.from(approvals);
    ordered.sort((a, b) {
      final aName = (a['office_name'] as String? ?? '').trim().toLowerCase();
      final bName = (b['office_name'] as String? ?? '').trim().toLowerCase();
      final aRank = _approvalWorkflowRank(aName);
      final bRank = _approvalWorkflowRank(bName);

      if (aRank != bRank) {
        return aRank.compareTo(bRank);
      }

      final aTime = (a['created_at'] as String? ?? '').toLowerCase();
      final bTime = (b['created_at'] as String? ?? '').toLowerCase();
      return aTime.compareTo(bTime);
    });
    return ordered;
  }

  static int _approvalWorkflowRank(String officeName) {
    if (officeName.contains('general education')) {
      return 0;
    }
    if (officeName.contains('program chair')) {
      return 1;
    }
    if (officeName.contains('item owner')) {
      return 2;
    }
    if (officeName.contains('sdao')) {
      return 3;
    }
    if (officeName.contains('do')) {
      return 4;
    }
    if (officeName.contains('security')) {
      return 5;
    }
    if (officeName.contains('physical facilities')) {
      return 6;
    }
    return 1;
  }

  // MARK: - Approval Workflow

  /// Calculate the approval chain based on room type and items reserved
  Future<ApprovalChain> calculateApprovalChain({
    required String roomType,
    required List<int>? itemIds,
  }) async {
    try {
      final offices = <String>[];
      final itemOwners = <String>[];
      bool hasPhysicalFacilitiesOwner = false;

      if (itemIds != null && itemIds.isNotEmpty) {
        for (int itemId in itemIds) {
          final item = await getItemDetails(itemId);
          if (item != null && item.ownerId != null) {
            final owner = await getItemOwnerName(item.ownerId!);
            if (owner != null) {
              if (owner == 'Physical Facilities') {
                hasPhysicalFacilitiesOwner = true;
              } else if (!itemOwners.contains(owner)) {
                itemOwners.add(owner);
              }
            }
          }
        }
      }

      if (roomType == 'Classroom') {
        if (itemOwners.isNotEmpty) {
          offices.addAll(itemOwners);
        }
        offices.addAll([
          'Program Chair',
          'SDAO',
          'DO',
          'Security',
          'Physical Facilities',
        ]);
      } else if (roomType == 'Gym' ||
          roomType == 'AVR' ||
          roomType == 'Lobby' ||
          roomType == 'Student Lounge') {
        offices.add('General Education');
        if (itemOwners.isNotEmpty) {
          offices.addAll(itemOwners);
        }
        offices.addAll([
          'Program Chair',
          'SDAO',
          'DO',
          'Security',
          'Physical Facilities',
        ]);
      } else {
        offices.addAll([
          'Program Chair',
          'SDAO',
          'DO',
          'Security',
          'Physical Facilities',
        ]);
      }

      final officeIds = <int>[];
      for (String office in offices) {
        final officeData = await _getOfficeByName(office);
        if (officeData != null) {
          officeIds.add(officeData['office_id'] as int);
        }
      }

      return ApprovalChain(offices: offices, officeIds: officeIds);
    } catch (e) {
      print('Error calculating approval chain: $e');
      return ApprovalChain(offices: [], officeIds: []);
    }
  }

  /// Get office ID by name
  Future<Map<String, dynamic>?> _getOfficeByName(String departmentName) async {
    try {
      final response = await _client
          .from('offices')
          .select()
          .ilike('department_name', departmentName)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching office: $e');
      return null;
    }
  }

  /// Get item owner name
  Future<String?> getItemOwnerName(int ownerId) async {
    try {
      final response = await _client
          .from('item_owners')
          .select('owner_name')
          .eq('owner_id', ownerId)
          .maybeSingle();

      if (response != null) {
        return response['owner_name'] as String;
      }
      return null;
    } catch (e) {
      print('Error fetching item owner: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getOfficeById(int officeId) async {
    try {
      final response = await _client
          .from('offices')
          .select('department_name')
          .eq('office_id', officeId)
          .maybeSingle();
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching office by id: $e');
      return null;
    }
  }

  Future<List<ReservationTimelineEntry>> _buildApprovalTimeline(
      int reservationId, DateTime date) async {
    try {
      final approvalsResponse = await _client
          .from('reservation_approvals')
          .select('office_id, status, created_at, updated_at')
          .eq('reservation_id', reservationId)
          .order('created_at', ascending: true);

      if (approvalsResponse == null || (approvalsResponse as List).isEmpty) {
        return [
          ReservationTimelineEntry(
            title: 'Request Submitted',
            status: 'Completed',
            date: date,
            timestamp: _formatTimestamp(date),
            description: 'Your reservation request was submitted successfully.',
          ),
          ReservationTimelineEntry(
            title: 'Request Pending',
            status: 'Pending',
            date: date,
            timestamp: 'Pending',
            description: 'Waiting for your reservation to be reviewed.',
          ),
        ];
      }

      final entries = <ReservationTimelineEntry>[];
      entries.add(ReservationTimelineEntry(
        title: 'Request Submitted',
        status: 'Completed',
        date: date,
        timestamp: _formatTimestamp(date),
        description: 'Your reservation request was submitted successfully.',
      ));

      final approvalEntries = <Map<String, dynamic>>[];
      for (final approval in approvalsResponse as List) {
        final officeId = approval['office_id'] as int?;
        final status = (approval['status'] as String?)?.trim() ?? 'Pending';
        final createdAt = approval['created_at'] as String?;
        final updatedAt = approval['updated_at'] as String?;
        final timestamp = status.toLowerCase() == 'pending'
            ? 'Pending'
            : _formatTimestamp(DateTime.parse(updatedAt ?? createdAt ?? DateTime.now().toIso8601String()));

        final officeName = officeId == null
            ? 'Approval Step'
            : (await _getOfficeById(officeId))?['department_name'] as String? ??
                'Approval Step';

        final normalizedStatus = status.toLowerCase();
        final entryStatus = normalizedStatus == 'approved' ||
                normalizedStatus == 'completed' ||
                normalizedStatus == 'accepted'
            ? 'Approved'
            : normalizedStatus == 'rejected' || normalizedStatus == 'denied'
                ? 'Rejected'
                : 'Pending';

        final description = entryStatus == 'Approved'
            ? 'Your reservation has been approved by $officeName.'
            : entryStatus == 'Rejected'
                ? 'Your reservation was rejected by $officeName.'
                : 'Waiting for approval from $officeName.';

        approvalEntries.add({
          'office_name': officeName,
          'status': entryStatus,
          'timestamp': timestamp,
          'description': description,
          'created_at': createdAt ?? updatedAt ?? DateTime.now().toIso8601String(),
        });
      }

      final sortedApprovals = sortApprovalEntriesForTimeline(approvalEntries);
      for (final approvalEntry in sortedApprovals) {
        final officeName = approvalEntry['office_name'] as String;
        final entryStatus = approvalEntry['status'] as String;
        final timestamp = approvalEntry['timestamp'] as String;
        final description = approvalEntry['description'] as String;

        entries.add(ReservationTimelineEntry(
          title: officeName,
          status: entryStatus,
          date: date,
          timestamp: timestamp,
          description: description,
        ));
      }

      return entries;
    } catch (e) {
      print('Error building approval timeline: $e');
      return [
        ReservationTimelineEntry(
          title: 'Request Submitted',
          status: 'Completed',
          date: date,
          timestamp: _formatTimestamp(date),
          description: 'Your reservation request was submitted successfully.',
        ),
        ReservationTimelineEntry(
          title: 'Request Pending',
          status: 'Pending',
          date: date,
          timestamp: 'Pending',
          description: 'Waiting for your reservation to be reviewed.',
        ),
      ];
    }
  }

  // MARK: - Reservation Creation

  /// Create a new reservation with approval chain
  Future<int?> createReservation({
    required String activityName,
    required int userId,
    required int roomId,
    required DateTime dateOfActivity,
    required DateTime startTime,
    required DateTime endTime,
    required List<int>? chairsQuantity,
    required List<int>? itemIds,
    required List<int> approvalChain,
  }) async {
    try {
      final resResponse = await _client.from('reservations').insert({
        'user_id': userId,
        'activity_name': activityName,
        'overall_status': 'Pending Approval',
        'Date_of_Activity': dateOfActivity.toIso8601String(),
        'Start_of_activity': startTime.toIso8601String(),
        'End_of_Activity': endTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select();

      if (resResponse.isEmpty) {
        return null;
      }

      final reservationId = resResponse[0]['reservation_id'] as int;

      final roomReservationResponse = await _client.from('reservation_rooms').insert({
        'room_id': roomId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select();

      final reservationRoomsId = roomReservationResponse[0]['reservation_rooms_id'] as int;

      await _client.from('reservation_details').insert({
        'reservation_id': reservationId,
        'reservation_rooms_id': reservationRoomsId,
        'quantity': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (chairsQuantity != null && chairsQuantity.isNotEmpty && chairsQuantity[0] > 0) {
        await _client.from('reservation_details').insert({
          'reservation_id': reservationId,
          'quantity': chairsQuantity[0],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (itemIds != null && itemIds.isNotEmpty) {
        for (int itemId in itemIds) {
          final itemResponse = await _client.from('reservation_items').insert({
            'item_id': itemId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).select();

          final reservationItemsId = itemResponse[0]['reservation_items_id'] as int;

          await _client.from('reservation_details').insert({
            'reservation_id': reservationId,
            'reservation_items_id': reservationItemsId,
            'quantity': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          final currentItem = await getItemDetails(itemId);
          if (currentItem != null) {
            await _client.from('items').update({
              'quantity_in_use': currentItem.quantityInUse + 1,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('item_id', itemId);
          }
        }
      }

      final approvalBaseTime = DateTime.now().toUtc();
      for (var index = 0; index < approvalChain.length; index++) {
        final officeId = approvalChain[index];
        final approvalTimestamp = buildApprovalTimestampForStep(
          index,
          baseTime: approvalBaseTime,
        );
        await _client.from('reservation_approvals').insert({
          'reservation_id': reservationId,
          'office_id': officeId,
          'status': 'Pending',
          'created_at': approvalTimestamp.toIso8601String(),
          'updated_at': approvalTimestamp.toIso8601String(),
        });
      }

      return reservationId;
    } catch (e) {
      print('Error creating reservation: $e');
      return null;
    }
  }

  /// Get dates with conflicts for a specific room
  Future<Set<DateTime>> getConflictedDatesForRoom(int roomId) async {
    try {
      final response = await _client
          .from('reservations')
          .select('Date_of_Activity')
          .eq('room_id', roomId)
          .neq('overall_status', 'Cancelled');

      final conflictedDates = <DateTime>{};

      for (var res in response as List) {
        final dateStr = res['Date_of_Activity'] as String;
        final date = DateTime.parse(dateStr);
        conflictedDates.add(DateTime(date.year, date.month, date.day));
      }

      return conflictedDates;
    } catch (e) {
      print('Error fetching conflicted dates: $e');
      return {};
    }
  }
}
