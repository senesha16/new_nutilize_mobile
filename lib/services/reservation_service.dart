import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/services/supabase_service.dart';

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


      
      // Normalize for comparison: remove spaces and convert to lowercase
      final normalizedTableType = tableType.replaceAll(' ', '').toLowerCase();
      
      // Filter results by table type (case-insensitive, space-insensitive)
      final filteredRooms = (response as List)
          .where((room) {
            final roomTableType = room['room_table_type'] as String?;
            final normalizedRoomType = roomTableType?.replaceAll(' ', '').toLowerCase() ?? '';
            final matches = normalizedRoomType == normalizedTableType;

            return matches;
          })
          .toList();



      return filteredRooms
          .map((room) => Room.fromJson(room as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching classrooms: $e');
      return [];
    }
  }

  /// Check if a specific room has time conflicts
  /// Excludes: Cancelled, Rejected, Denied, Returned statuses
  /// Includes: Pending, Approved, Completed (blocks availability)
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

      // Only check reservations with blocking statuses: Pending, Approved, Completed
      final response = await _client
          .from('reservations')
          .select('reservation_id, Date_of_Activity, Start_of_activity, End_of_Activity, overall_status')
          .gte('Date_of_Activity', dayStart.toIso8601String())
          .lt('Date_of_Activity', dayEnd.toIso8601String())
          .in_('overall_status', ['Pending Approval', 'Approved', 'Completed']);



      if (response.isEmpty) {

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

              return true;
            }
          }
        }
      }


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

  Future<List<Map<String, dynamic>>> _getAvailableItemUnits(int itemId, int quantity) async {
    try {
      final response = await _client
          .from('item_units')
          .select('unit_id, unit_code')
          .eq('item_id', itemId)
          .eq('status', 'available')
          .order('unit_id', ascending: true)
          .limit(quantity);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching available item units: $e');
      return [];
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

      // Process each reservation concurrently to reduce total network latency.
      final resList = reservationsResponse as List;
      final futures = resList.map((res) async {
        try {
          final reservationId = res['reservation_id'] as int;
          final date = DateTime.parse(res['Date_of_Activity'] as String);
          final startTime = DateTime.parse(res['Start_of_activity'] as String);
          final endTime = DateTime.parse(res['End_of_Activity'] as String);
          final reservationTime = '${_formatDateTime(startTime)} - ${_formatDateTime(endTime)}';

          // Kick off independent async work in parallel
          final roomNameFuture = _fetchReservationRoomName(reservationId);
          final timelineFuture = _buildApprovalTimeline(reservationId, date);
          final reservedItemsFuture = _fetchReservationItemNames(reservationId);
          final detailCheckFuture = _client
              .from('reservation_details')
              .select('reservation_items_id')
              .eq('reservation_id', reservationId)
              .limit(1)
              .maybeSingle();

          final results = await Future.wait([
            roomNameFuture,
            timelineFuture,
            reservedItemsFuture,
            detailCheckFuture,
          ]);

          final roomName = results[0] as String? ?? 'Reserved Room';
          final timeline = results[1] as List<ReservationTimelineEntry>? ?? [];
          final reservedItems = results[2] as List<String>? ?? [];
          final detailCheck = results[3] as Map<String, dynamic>?;

          var reservationType = 'Venue Reservation';
          if (detailCheck != null && detailCheck['reservation_items_id'] != null) {
            reservationType = 'Item Reservation';
          }

          return ReservationRecord(
            id: reservationId.toString(),
            userId: userId,
            reservationTitle: res['activity_name'] as String? ?? 'Reservation Request',
            roomName: roomName,
            reservationType: reservationType,
            reservationStatus: res['overall_status'] as String? ?? 'Pending Approval',
            date: date,
            reservationTime: reservationTime,
            timeline: timeline,
            reservedItems: reservedItems,
          );
        } catch (e) {
          // If one reservation fails to parse, skip it but don't fail the whole fetch.
          print('Error processing reservation entry: $e');
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      final records = results.whereType<ReservationRecord>().toList();
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
        // Might be an item reservation — check for reservation_items_id
        final itemDetail = await _client
            .from('reservation_details')
            .select('reservation_items_id')
            .eq('reservation_id', reservationId)
            .limit(1)
            .maybeSingle();
        if (itemDetail != null && itemDetail['reservation_items_id'] != null) {
          return 'Item Reservation';
        }
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

  /// Fetch item names reserved under a reservation (if any)
  Future<List<String>> _fetchReservationItemNames(int reservationId) async {
    final names = <String>[];
    try {
      final details = await _client
          .from('reservation_details')
          .select('reservation_items_id')
          .eq('reservation_id', reservationId);
      if (details == null) return names;
      for (final det in details as List) {
        final reservationItemsId = det['reservation_items_id'] as int?;
        if (reservationItemsId == null) continue;

        final itemLink = await _client
            .from('reservation_items')
            .select('item_id')
            .eq('reservation_items_id', reservationItemsId)
            .maybeSingle();
        final itemId = itemLink?['item_id'] as int?;
        if (itemId == null) continue;

        final itemRow = await _client
            .from('items')
            .select('item_name')
            .eq('item_id', itemId)
            .maybeSingle();
        final itemName = itemRow?['item_name'] as String?;
        if (itemName != null && itemName.isNotEmpty) {
          names.add(itemName);
        }
      }
    } catch (e) {
      print('Error fetching reservation item names: $e');
    }
    return names;
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<List<String>> _getReservationItemOwnerNames(int reservationId) async {
    final itemOwners = <String>{};
    try {
      final details = await _client
          .from('reservation_details')
          .select('reservation_items_id')
          .eq('reservation_id', reservationId);
      if (details == null) return [];

      for (final det in details as List) {
        final reservationItemsId = det['reservation_items_id'] as int?;
        if (reservationItemsId == null) continue;

        final itemLink = await _client
            .from('reservation_items')
            .select('item_id')
            .eq('reservation_items_id', reservationItemsId)
            .maybeSingle();
        final itemId = itemLink?['item_id'] as int?;
        if (itemId == null) continue;

        final item = await getItemDetails(itemId);
        if (item != null && item.ownerId != null) {
          final owner = await getItemOwner(item.ownerId!);
          if (owner != null) {
            final affiliation = (owner['department_affiliation'] as String?)?.trim().toUpperCase();
            final ownerName = owner['owner_name'] as String?;
            if (affiliation != 'PFO' && ownerName != null) {
              itemOwners.add(ownerName);
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching reservation item owner names: $e');
    }
    return itemOwners.toList();
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
      return 1;
    }
    if (officeName.contains('item owner')) {
      return 2;
    }
    if (officeName.contains('program chair')) {
      return 3;
    }
    if (officeName.contains('sdao')) {
      return 4;
    }
    if (officeName.contains('do')) {
      return 5;
    }
    if (officeName.contains('security')) {
      return 6;
    }
    if (officeName.contains('physical facilities')) {
      return 7;
    }
    if (officeName.isNotEmpty) {
      // Any dynamic owner name should be treated as an item owner approval step.
      return 2;
    }
    return 8;
  }

  // MARK: - Approval Workflow

  /// Calculate the approval chain based on room type and items reserved
  Future<ApprovalChain> calculateApprovalChain({
    required String roomType,
    required List<int>? itemIds,
  }) async {
    try {
      final officeTitles = <String>[];
      final officeIds = <int>[];
      final itemOwners = <String>{};

      if (itemIds != null && itemIds.isNotEmpty) {
        for (int itemId in itemIds) {
          final item = await getItemDetails(itemId);
          if (item != null && item.ownerId != null) {
            final owner = await getItemOwner(item.ownerId!);
            if (owner != null) {
              final affiliation =
                  (owner['department_affiliation'] as String?)?.trim().toUpperCase();
              final ownerName = owner['owner_name'] as String?;
              if (ownerName != null && affiliation != 'PFO') {
                itemOwners.add(ownerName);
              }
            }
          }
        }
      }

      final standardOffices = [
        'Program Chair',
        'SDAO',
        'DO',
        'Security',
        'Physical Facilities',
      ];
      final itemOwnerOfficeId = await _getOfficeIdByName('Item Owner');
      final hasItems = itemIds != null && itemIds.isNotEmpty;

      if (roomType == 'Gym') {
        officeTitles.add('General Education');
        final generalEducationId = await _getOfficeIdByName('General Education');
        if (generalEducationId != null) {
          officeIds.add(generalEducationId);
        }
        if (itemOwners.isNotEmpty) {
          for (final ownerName in itemOwners) {
            officeTitles.add(ownerName);
            if (itemOwnerOfficeId != null) {
              officeIds.add(itemOwnerOfficeId);
            }
          }
        }
        for (final office in standardOffices) {
          officeTitles.add(office);
          final officeId = await _getOfficeIdByName(office);
          if (officeId != null) {
            officeIds.add(officeId);
          }
        }
      } else if (roomType == 'Classroom') {
        if (itemOwners.isNotEmpty) {
          for (final ownerName in itemOwners) {
            officeTitles.add(ownerName);
            if (itemOwnerOfficeId != null) {
              officeIds.add(itemOwnerOfficeId);
            }
          }
        }
        for (final office in standardOffices) {
          officeTitles.add(office);
          final officeId = await _getOfficeIdByName(office);
          if (officeId != null) {
            officeIds.add(officeId);
          }
        }
      } else if (roomType == 'AVR' || roomType == 'Lobby' || roomType == 'Student Lounge') {
        if (itemOwners.isNotEmpty) {
          for (final ownerName in itemOwners) {
            officeTitles.add(ownerName);
            if (itemOwnerOfficeId != null) {
              officeIds.add(itemOwnerOfficeId);
            }
          }
        }
        for (final office in standardOffices) {
          officeTitles.add(office);
          final officeId = await _getOfficeIdByName(office);
          if (officeId != null) {
            officeIds.add(officeId);
          }
        }
      } else if (hasItems) {
        if (itemOwners.isNotEmpty) {
          for (final ownerName in itemOwners) {
            officeTitles.add(ownerName);
            if (itemOwnerOfficeId != null) {
              officeIds.add(itemOwnerOfficeId);
            }
          }
        }
        for (final office in standardOffices) {
          officeTitles.add(office);
          final officeId = await _getOfficeIdByName(office);
          if (officeId != null) {
            officeIds.add(officeId);
          }
        }
      } else {
        for (final office in standardOffices) {
          officeTitles.add(office);
          final officeId = await _getOfficeIdByName(office);
          if (officeId != null) {
            officeIds.add(officeId);
          }
        }
      }

      return ApprovalChain(offices: officeTitles, officeIds: officeIds);
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

  Future<int?> _getOfficeIdByName(String departmentName) async {
    final office = await _getOfficeByName(departmentName);
    return office == null ? null : office['office_id'] as int?;
  }

  /// Get item owner record
  Future<Map<String, dynamic>?> getItemOwner(int ownerId) async {
    try {
      final response = await _client
          .from('item_owners')
          .select('owner_name, department_affiliation')
          .eq('owner_id', ownerId)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching item owner: $e');
      return null;
    }
  }

  /// Get only the item owner name
  Future<String?> getItemOwnerName(int ownerId) async {
    final owner = await getItemOwner(ownerId);
    return owner?['owner_name'] as String?;
  }

  Future<bool> submitIssueReport({
    required int reservationId,
    required String description,
    String? imageName,
    String? imageBase64,
  }) async {
    try {
      final userId = AuthService.currentUser?['user_id'] as int?;
      final userEmail = AuthService.currentUser?['email'] as String?;

      final payload = <String, dynamic>{
        'reservation_id': reservationId,
        'user_id': userId,
        'reported_by': userEmail ?? 'unknown',
        'description': description,
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (imageName != null && imageName.isNotEmpty) {
        payload['image_name'] = imageName;
      }
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        payload['image_base64'] = imageBase64;
      }

      final response = await _client.from('reservation_issues').insert(payload).select().maybeSingle();
      return response != null;
    } catch (e) {
      print('Error submitting issue report: $e');
      return false;
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
      final itemOwnerNames = await _getReservationItemOwnerNames(reservationId);
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

        String officeName = officeId == null
            ? 'Approval Step'
            : (await _getOfficeById(officeId))?['department_name'] as String? ??
                'Approval Step';
        if (officeName.toLowerCase() == 'item owner' && itemOwnerNames.isNotEmpty) {
          officeName = itemOwnerNames.join(', ');
        }

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
    String? proofOfConsentUrl,
  }) async {
    try {
      // Prevent overlapping reservations for the same room/time
      final conflict = await _hasRoomTimeConflict(
        roomId,
        dateOfActivity,
        startTime,
        endTime,
      );
      if (conflict) {
        print('Cannot create reservation: time conflict for room $roomId on $dateOfActivity');
        return null;
      }

      final reservationData = {
        'user_id': userId,
        'activity_name': activityName,
        'overall_status': 'Pending Approval',
        'Date_of_Activity': dateOfActivity.toIso8601String(),
        'Start_of_activity': startTime.toIso8601String(),
        'End_of_Activity': endTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add proof of consent URL if provided (for students)
      if (proofOfConsentUrl != null) {
        reservationData['proof_of_consent_url'] = proofOfConsentUrl;
      }

      final resResponse = await _client.from('reservations').insert(reservationData).select();

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

          final availableUnits = await _getAvailableItemUnits(itemId, 1);
          for (final unit in availableUnits) {
            await _client.from('reservation_item_units').insert({
              'reservation_items_id': reservationItemsId,
              'unit_id': unit['unit_id'],
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            await _client.from('item_units').update({
              'status': 'reserved',
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('unit_id', unit['unit_id']);
          }

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

  /// Check whether the given room has any reservation on the same date that
  /// overlaps the requested time range. Returns true if a conflict exists.
  Future<bool> _hasRoomTimeConflict(
    int roomId,
    DateTime dateOfActivity,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      // Find reservation_rooms entries for this room
      final roomResp = await _client
          .from('reservation_rooms')
          .select('reservation_rooms_id')
          .eq('room_id', roomId);

      if (roomResp == null) return false;

      final roomIds = <int>[];
      for (final r in roomResp as List) {
        final id = r['reservation_rooms_id'] as int?;
        if (id != null) roomIds.add(id);
      }

      if (roomIds.isEmpty) return false;

      // Find reservation_details that reference those reservation_rooms_ids
      final detailsResp = await _client
          .from('reservation_details')
          .select('reservation_id')
          .in_('reservation_rooms_id', roomIds);

      if (detailsResp == null) return false;

      final reservationIds = <int>{};
      for (final d in detailsResp as List) {
        final rid = d['reservation_id'] as int?;
        if (rid != null) reservationIds.add(rid);
      }

      if (reservationIds.isEmpty) return false;

      // Fetch reservations by id and check date/time overlap
        final reservationsResp = await _client
          .from('reservations')
          .select('reservation_id, Date_of_Activity, Start_of_activity, End_of_Activity, overall_status')
          .in_('reservation_id', reservationIds.toList())
          .neq('overall_status', 'Cancelled');

      if (reservationsResp == null) return false;

      for (final res in reservationsResp as List) {
        final dateStr = res['Date_of_Activity'] as String?;
        final startStr = res['Start_of_activity'] as String?;
        final endStr = res['End_of_Activity'] as String?;
        if (dateStr == null || startStr == null || endStr == null) continue;

        final existingDate = DateTime.parse(dateStr);
        if (existingDate.year == dateOfActivity.year &&
            existingDate.month == dateOfActivity.month &&
            existingDate.day == dateOfActivity.day) {
          final existingStart = DateTime.parse(startStr);
          final existingEnd = DateTime.parse(endStr);

          if (startTime.isBefore(existingEnd) && endTime.isAfter(existingStart)) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('Error checking room time conflicts: $e');
      // Fail-safe: assume no conflict so we don't block valid reservations
      return false;
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

  // MARK: - File Operations

  /// Upload proof of consent file to Supabase Storage
  Future<void> uploadProofOfConsent(File file, String filePath) async {
    try {
      await _client.storage.from('proof_of_consent').upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      print('Successfully uploaded proof of consent to: $filePath');
    } catch (e) {
      print('Error uploading proof of consent: $e');
      try {
        final serviceRoleKey = SupabaseService.serviceRoleKey;
        if (serviceRoleKey.isEmpty) {
          rethrow;
        }

        final storageClient = SupabaseClient(
          _client.supabaseUrl,
          serviceRoleKey,
        );

        await storageClient.storage.from('proof_of_consent').upload(
          filePath,
          file,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );
        print('Successfully uploaded proof of consent via service-role fallback: $filePath');
      } catch (fallbackError) {
        print('Service-role upload fallback failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Get public URL for uploaded proof of consent file
  String getProofOfConsentUrl(String filePath) {
    try {
      final url = _client.storage.from('proof_of_consent').getPublicUrl(filePath);
      return url;
    } catch (e) {
      print('Error getting proof of consent URL: $e');
      rethrow;
    }
  }

  // MARK: - Item Reservation

  /// Create a new item reservation
  Future<int?> createItemReservation({
    required String activityName,
    required int userId,
    required DateTime dateOfActivity,
    required DateTime startTime,
    required DateTime endTime,
    required Map<int, int> itemQuantities, // item_id -> quantity
    String? proofOfConsentUrl,
  }) async {
    try {
      final reservationData = {
        'user_id': userId,
        'activity_name': activityName,
        'overall_status': 'Pending Approval',
        'Date_of_Activity': dateOfActivity.toIso8601String(),
        'Start_of_activity': startTime.toIso8601String(),
        'End_of_Activity': endTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (proofOfConsentUrl != null) {
        reservationData['proof_of_consent_url'] = proofOfConsentUrl;
      }

      final resResponse = await _client.from('reservations').insert(reservationData).select();

      if (resResponse.isEmpty) {
        return null;
      }

      final reservationId = resResponse[0]['reservation_id'] as int;

      // Add each item to reservation_details
      for (final itemId in itemQuantities.keys) {
        final quantity = itemQuantities[itemId]!;

        // Create a reservation_items entry and link via reservation_items_id
        final itemResponse = await _client.from('reservation_items').insert({
          'item_id': itemId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select();

        final reservationItemsId = itemResponse[0]['reservation_items_id'] as int;

        await _client.from('reservation_details').insert({
          'reservation_id': reservationId,
          'reservation_items_id': reservationItemsId,
          'quantity': quantity,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        final availableUnits = await _getAvailableItemUnits(itemId, quantity);
        for (final unit in availableUnits) {
          await _client.from('reservation_item_units').insert({
            'reservation_items_id': reservationItemsId,
            'unit_id': unit['unit_id'],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          await _client.from('item_units').update({
            'status': 'reserved',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('unit_id', unit['unit_id']);
        }

        // Update the item's in-use quantity
        final currentItem = await getItemDetails(itemId);
        if (currentItem != null) {
          await _client.from('items').update({
            'quantity_in_use': currentItem.quantityInUse + quantity,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('item_id', itemId);
        }
      }

      print('Item reservation created: $reservationId');

      // Build and insert the approval chain for this item reservation
      final approvalChain = await calculateApprovalChain(roomType: '', itemIds: itemQuantities.keys.toList());
      final approvalBaseTime = DateTime.now().toUtc();
      for (var index = 0; index < approvalChain.officeIds.length; index++) {
        final officeId = approvalChain.officeIds[index];
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

      // Add a local ReservationRecord for immediate UI feedback
      try {
        final timeline = <ReservationTimelineEntry>[];
        timeline.add(ReservationTimelineEntry(
          title: 'Request Submitted',
          status: 'Completed',
          date: dateOfActivity,
          timestamp: _formatTimestamp(dateOfActivity),
          description: 'Your reservation request was submitted successfully.',
        ));

        for (final office in approvalChain.offices) {
          timeline.add(ReservationTimelineEntry(
            title: office,
            status: 'Pending',
            date: dateOfActivity,
            timestamp: 'Pending',
            description: 'Waiting for approval from $office.',
          ));
        }

        final reservedItemNames = <String>[];
        for (final itemId in itemQuantities.keys) {
          final item = await getItemDetails(itemId);
          if (item != null) reservedItemNames.add(item.itemName);
        }

        final newRecord = ReservationRecord(
          id: reservationId.toString(),
          userId: userId,
          reservationTitle: activityName.isEmpty ? 'Item Reservation' : activityName,
          roomName: 'Item Reservation',
          reservationType: 'Item Reservation',
          reservationStatus: 'Pending Approval',
          date: dateOfActivity,
          reservationTime: '${_formatDateTime(startTime)} - ${_formatDateTime(endTime)}',
          timeline: timeline,
          reservedItems: reservedItemNames,
        );

        ReservationActivityStore.add(newRecord);
      } catch (_) {
        // Non-fatal; UI will refresh from backend later
      }

      return reservationId;
    } catch (e) {
      print('Error creating item reservation: $e');
      return null;
    }
  }

  /// Cancel an existing reservation request.
  Future<bool> cancelReservation(int reservationId) async {
    try {
      final updateResult = await _client
          .from('reservations')
          .update({
            'overall_status': 'Cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('reservation_id', reservationId)
          .select();

      if (updateResult == null || (updateResult as List).isEmpty) {
        return false;
      }

      await _client
          .from('reservation_approvals')
          .update({
            'status': 'Cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('reservation_id', reservationId);

      final reservationDetails = await _client
          .from('reservation_details')
          .select('reservation_items_id, quantity')
          .eq('reservation_id', reservationId);

      if (reservationDetails != null) {
        for (final detail in reservationDetails as List) {
          final reservationItemsId = detail['reservation_items_id'] as int?;
          final quantity = detail['quantity'] as int? ?? 0;
          if (reservationItemsId == null || quantity <= 0) {
            continue;
          }

          final itemLink = await _client
              .from('reservation_items')
              .select('item_id')
              .eq('reservation_items_id', reservationItemsId)
              .maybeSingle();
          final itemId = itemLink?['item_id'] as int?;
          if (itemId == null) {
            continue;
          }

          final reservationUnits = await _client
              .from('reservation_item_units')
              .select('unit_id')
              .eq('reservation_items_id', reservationItemsId);

          if (reservationUnits != null) {
            for (final unit in reservationUnits as List) {
              final unitId = unit['unit_id'] as int?;
              if (unitId != null) {
                await _client.from('item_units').update({
                  'status': 'available',
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('unit_id', unitId);
              }
            }
          }

          final currentItem = await getItemDetails(itemId);
          if (currentItem != null) {
            final safeQuantity = (currentItem.quantityInUse - quantity).clamp(0, currentItem.quantityInUse) as int;
            await _client.from('items').update({
              'quantity_in_use': safeQuantity,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('item_id', itemId);
          }
        }
      }

      return true;
    } catch (e) {
      print('Error cancelling reservation: $e');
      return false;
    }
  }
}
