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

  int get availableQuantity => (quantityTotal - quantityInUse).clamp(0, quantityTotal);

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

bool _isUnitAvailableStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  return normalized == 'available' || normalized == 'free' || normalized == 'ready' || normalized == 'active' || normalized == 'new' || normalized == 'in_stock' || normalized == 'instock';
}

bool _isCancelledReservationStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  return normalized == 'cancelled' || normalized == 'canceled' || normalized == 'rejected' || normalized == 'denied' || normalized == 'returned' || normalized == 'void' || normalized == 'completed' || normalized == 'complete';
}

bool _reservationOverlapsWindow({
  required DateTime reservationStart,
  required DateTime reservationEnd,
  required DateTime requestStart,
  required DateTime requestEnd,
}) {
  return reservationStart.isBefore(requestEnd) && reservationEnd.isAfter(requestStart);
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

  Future<Map<int, Set<int>>> _getUnavailableUnitIdsForItems(
    List<int> itemIds, {
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    final unavailableByItem = <int, Set<int>>{};
    if (itemIds.isEmpty) return unavailableByItem;

    final targetStart = requestStart ?? DateTime.now();
    final targetEnd = requestEnd ?? targetStart.add(const Duration(hours: 1));

    try {
      final reservationItemsResponse = await _client
          .from('reservation_items')
          .select('reservation_items_id, item_id')
          .in_('item_id', itemIds);

      if (reservationItemsResponse == null) return unavailableByItem;

      final reservationItems = (reservationItemsResponse as List).cast<Map<String, dynamic>>();
      if (reservationItems.isEmpty) return unavailableByItem;

      final reservationItemsIdToItemId = <int, int>{};
      final reservationItemsIds = <int>[];
      for (final row in reservationItems) {
        final reservationItemsId = row['reservation_items_id'] as int?;
        final itemId = row['item_id'] as int?;
        if (reservationItemsId == null || itemId == null) continue;
        reservationItemsIdToItemId[reservationItemsId] = itemId;
        reservationItemsIds.add(reservationItemsId);
      }

      if (reservationItemsIds.isEmpty) return unavailableByItem;

      final reservationDetailsResponse = await _client
          .from('reservation_details')
          .select('reservation_id, reservation_items_id')
          .in_('reservation_items_id', reservationItemsIds);

      if (reservationDetailsResponse == null) return unavailableByItem;

      final reservationDetails = (reservationDetailsResponse as List).cast<Map<String, dynamic>>();
      final reservationIds = <int>[];
      final reservationIdToReservationItemsIds = <int, List<int>>{};

      for (final row in reservationDetails) {
        final reservationId = row['reservation_id'] as int?;
        final reservationItemsId = row['reservation_items_id'] as int?;
        if (reservationId == null || reservationItemsId == null) continue;
        reservationIdToReservationItemsIds.putIfAbsent(reservationId, () => <int>[]).add(reservationItemsId);
        reservationIds.add(reservationId);
      }

      if (reservationIds.isEmpty) return unavailableByItem;

      final reservationsResponse = await _client
          .from('reservations')
          .select('reservation_id, overall_status, Date_of_Activity, Start_of_activity, End_of_Activity')
          .in_('reservation_id', reservationIds);

      if (reservationsResponse == null) return unavailableByItem;

      final reservations = (reservationsResponse as List).cast<Map<String, dynamic>>();
      final activeReservationItemIds = <int>{};
      for (final row in reservations) {
        final reservationId = row['reservation_id'] as int?;
        final status = row['overall_status'] as String?;
        if (reservationId == null || _isCancelledReservationStatus(status)) continue;

        final reservationStartRaw = row['Start_of_activity'] as String?;
        final reservationEndRaw = row['End_of_Activity'] as String?;
        if (reservationStartRaw == null || reservationEndRaw == null) continue;

        try {
          final reservationStart = DateTime.parse(reservationStartRaw);
          final reservationEnd = DateTime.parse(reservationEndRaw);
          if (!_reservationOverlapsWindow(
            reservationStart: reservationStart,
            reservationEnd: reservationEnd,
            requestStart: targetStart,
            requestEnd: targetEnd,
          )) {
            continue;
          }
        } catch (_) {
          continue;
        }

        for (final reservationItemsId in reservationIdToReservationItemsIds[reservationId] ?? const <int>[]) {
          activeReservationItemIds.add(reservationItemsId);
        }
      }

      if (activeReservationItemIds.isEmpty) return unavailableByItem;

      final reservationUnitsResponse = await _client
          .from('reservation_item_units')
          .select('reservation_items_id, unit_id')
          .in_('reservation_items_id', activeReservationItemIds.toList());

      if (reservationUnitsResponse == null) return unavailableByItem;

      for (final row in (reservationUnitsResponse as List).cast<Map<String, dynamic>>()) {
        final reservationItemsId = row['reservation_items_id'] as int?;
        final unitId = row['unit_id'] as int?;
        final itemId = reservationItemsIdToItemId[reservationItemsId];
        if (unitId == null || itemId == null) continue;
        unavailableByItem.putIfAbsent(itemId, () => <int>{}).add(unitId);
      }
    } catch (e) {
      print('Error resolving unavailable item units: $e');
    }

    return unavailableByItem;
  }

  /// Fetch all available items from the database
  Future<List<ItemModel>> getAllItems({
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    try {
      final response = await _client
          .from('items')
          .select('*, item_owners(owner_name)');

      if (response == null) return [];

      final itemsList = (response as List).cast<Map<String, dynamic>>();

      // Collect item ids then fetch units in bulk to compute totals and available counts.
      final itemIds = itemsList.map((m) => m['item_id'] as int).toList();
      final unitsResp = await _client
          .from('item_units')
          .select('unit_id, item_id, status')
          .in_('item_id', itemIds);

      final units = (unitsResp as List?)?.cast<Map<String, dynamic>>() ?? [];
      final unavailableByItem = await _getUnavailableUnitIdsForItems(
        itemIds,
        requestStart: requestStart,
        requestEnd: requestEnd,
      );

      final unitsByItem = <int, List<Map<String, dynamic>>>{};
      for (final u in units) {
        final iid = u['item_id'] as int?;
        if (iid == null) continue;
        unitsByItem.putIfAbsent(iid, () => <Map<String, dynamic>>[]).add(u);
      }

      return itemsList.map((item) {
        final id = item['item_id'] as int;
        final itemUnits = unitsByItem[id] ?? const <Map<String, dynamic>>[];
        final total = itemUnits.isNotEmpty ? itemUnits.length : (item['quantity_total'] as int? ?? 0);
        final unavailableUnitIds = unavailableByItem[id] ?? const <int>{};
        final available = itemUnits.where((u) {
          final unitId = u['unit_id'] as int?;
          if (unitId != null && unavailableUnitIds.contains(unitId)) {
            return false;
          }
          return _isUnitAvailableStatus(u['status'] as String?);
        }).length;
        final clampedAvailable = available.clamp(0, total);
        final inUse = (total - clampedAvailable).clamp(0, total);

        return ItemModel(
          itemId: id,
          itemName: item['item_name'] as String? ?? 'Unknown',
          quantityTotal: total,
          quantityInUse: inUse,
          ownerId: item['owner_id'] as int?,
          ownerName: item['item_owners']?['owner_name'] as String?,
          maintenanceStatus: item['maintenance_status'] as bool? ?? false,
          availabilityStatus: item['availability_status'] as bool? ?? true,
        );
      }).toList();
    } catch (e) {
      print('Error fetching items: $e');
      return [];
    }
  }

  /// Get item details including current usage
  Future<ItemModel?> getItemDetails(
    int itemId, {
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    try {
      final response = await _client
          .from('items')
          .select('*, item_owners(owner_name)')
          .eq('item_id', itemId)
          .single();

      if (response == null) return null;

      final item = Map<String, dynamic>.from(response as Map);

      final unitsResp = await _client
          .from('item_units')
          .select('unit_id, status')
          .eq('item_id', itemId);

      final units = (unitsResp as List?)?.cast<Map<String, dynamic>>() ?? [];
      final unavailableUnitIds = await _getUnavailableUnitIdsForItems(
        [itemId],
        requestStart: requestStart,
        requestEnd: requestEnd,
      );
      final total = units.length;
      final available = units.where((u) {
        final unitId = u['unit_id'] as int?;
        if (unitId != null && (unavailableUnitIds[itemId] ?? const <int>{}).contains(unitId)) {
          return false;
        }
        return _isUnitAvailableStatus(u['status'] as String?);
      }).length;
      final clampedAvailable = available.clamp(0, total);
      final inUse = (total - clampedAvailable).clamp(0, total);

      // Debug: if availability is unexpectedly zero, print unit details to help diagnose
      if (available == 0) {
        try {
          print('Debug getItemDetails - item_id=$itemId total=$total available=$available units=');
          for (final u in units) {
            print('  unit: unit_id=${u['unit_id']}, unit_code=${u['unit_code'] ?? 'N/A'}, status=${u['status'] ?? 'N/A'}');
          }
        } catch (_) {}
      }

      return ItemModel(
        itemId: item['item_id'] as int,
        itemName: item['item_name'] as String? ?? 'Unknown',
        quantityTotal: total,
        quantityInUse: inUse,
        ownerId: item['owner_id'] as int?,
        ownerName: item['item_owners']?['owner_name'] as String?,
        maintenanceStatus: item['maintenance_status'] as bool? ?? false,
        availabilityStatus: item['availability_status'] as bool? ?? true,
      );
    } catch (e) {
      print('Error fetching item details: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableItemUnits(
    int itemId,
    int quantity, {
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    try {
      final response = await _client
          .from('item_units')
          .select('unit_id, unit_code, status')
          .eq('item_id', itemId)
          .order('unit_id', ascending: true);

      if (response == null) return [];

      final units = (response as List).cast<Map<String, dynamic>>();
      final unavailableUnitIds = await _getUnavailableUnitIdsForItems(
        [itemId],
        requestStart: requestStart,
        requestEnd: requestEnd,
      );

      return units.where((unit) {
        final unitId = unit['unit_id'] as int?;
        if (unitId != null && (unavailableUnitIds[itemId] ?? const <int>{}).contains(unitId)) {
          return false;
        }
        return _isUnitAvailableStatus(unit['status'] as String?);
      }).take(quantity).toList();
    } catch (e) {
      print('Error fetching available item units: $e');
      return [];
    }
  }

  Future<void> _reserveItemUnitsForReservation({
    required int reservationItemsId,
    required int itemId,
    required int quantity,
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    final availableUnits = await _getAvailableItemUnits(
      itemId,
      quantity,
      requestStart: requestStart,
      requestEnd: requestEnd,
    );
    if (availableUnits.length < quantity) {
      throw Exception('Not enough available units for item $itemId: requested $quantity, available ${availableUnits.length}');
    }

    final now = DateTime.now().toIso8601String();

    for (final unit in availableUnits) {
      final unitId = unit['unit_id'] as int?;
      if (unitId == null) continue;

      final reservationLinkPayload = {
        'reservation_items_id': reservationItemsId,
        'unit_id': unitId,
        'created_at': now,
        'updated_at': now,
      };

      try {
        final insertResponse = await _client.from('reservation_item_units').insert(reservationLinkPayload).select();
        if (insertResponse == null || (insertResponse as List).isEmpty) {
          throw Exception('Failed to link unit $unitId to reservation item $reservationItemsId');
        }
      } catch (e) {
        print('Primary reservation_item_units insert failed: $e');
        final serviceRoleKey = SupabaseService.serviceRoleKey;
        if (serviceRoleKey.isEmpty) {
          rethrow;
        }

        final serviceClient = SupabaseClient(_client.supabaseUrl, serviceRoleKey);
        final insertResponse = await serviceClient.from('reservation_item_units').insert(reservationLinkPayload).select();
        if (insertResponse == null || (insertResponse as List).isEmpty) {
          throw Exception('Failed to link unit $unitId to reservation item $reservationItemsId');
        }
      }

      try {
        final updateResponse = await _client.from('item_units').update({
          'status': 'in_use',
          'updated_at': now,
        }).eq('unit_id', unitId).select();

        if (updateResponse == null || (updateResponse as List).isEmpty) {
          throw Exception('Failed to reserve item unit $unitId');
        }
      } catch (e) {
        print('Primary item_units update failed: $e');
        final serviceRoleKey = SupabaseService.serviceRoleKey;
        if (serviceRoleKey.isEmpty) {
          rethrow;
        }

        final serviceClient = SupabaseClient(_client.supabaseUrl, serviceRoleKey);
        final updateResponse = await serviceClient.from('item_units').update({
          'status': 'in_use',
          'updated_at': now,
        }).eq('unit_id', unitId).select();

        if (updateResponse == null || (updateResponse as List).isEmpty) {
          throw Exception('Failed to reserve item unit $unitId');
        }
      }
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
    List<Map<String, dynamic>> approvals, {
    int? itemOwnerOfficeId,
  }) {
    return approvals
        .asMap()
        .entries
        .map((entry) {
          final approval = Map<String, dynamic>.from(entry.value);
          final officeId = approval['office_id'] as int?;
          final officeName = (approval['office_name'] as String?)?.toLowerCase() ?? '';

          // Parse created_at if available; this reflects insertion order when
          // approvals were created and should be the primary ordering key.
          try {
            final createdRaw = approval['created_at'] as String?;
            if (createdRaw != null && createdRaw.isNotEmpty) {
              final createdAt = DateTime.parse(createdRaw).toUtc();
              approval['__created_at_ts'] = createdAt.millisecondsSinceEpoch;
            } else {
              approval['__created_at_ts'] = null;
            }
          } catch (_) {
            approval['__created_at_ts'] = null;
          }

          int rank;
          if (officeName.contains('general education')) {
            rank = -1;
          } else if (officeId != null && itemOwnerOfficeId != null && officeId == itemOwnerOfficeId) {
            rank = 0;
          } else if (officeName.contains('item owner')) {
            rank = 0;
          } else if (officeName.contains('program chair')) {
            rank = 1;
          } else if (officeName.contains('sdao')) {
            rank = 2;
          } else if (officeName.contains('do')) {
            rank = 3;
          } else if (officeName.contains('security')) {
            rank = 4;
          } else if (officeName.contains('physical facilities')) {
            rank = 5;
          } else {
            rank = 999;
          }

          approval['__timeline_rank'] = rank;
          approval['__original_index'] = entry.key;
          return approval;
        })
        .toList()
      ..sort((a, b) {
        final aTs = a['__created_at_ts'] as int?;
        final bTs = b['__created_at_ts'] as int?;
        if (aTs != null && bTs != null) {
          final cmp = aTs.compareTo(bTs);
          if (cmp != 0) return cmp;
        } else if (aTs != null) {
          return -1;
        } else if (bTs != null) {
          return 1;
        }

        final rankA = a['__timeline_rank'] as int;
        final rankB = b['__timeline_rank'] as int;
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }
        final indexA = a['__original_index'] as int;
        final indexB = b['__original_index'] as int;
        return indexA.compareTo(indexB);
      });
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
      final itemOwners = <String>[];

      if (itemIds != null && itemIds.isNotEmpty) {
        for (int itemId in itemIds) {
          final item = await getItemDetails(itemId);
          if (item != null && item.ownerId != null) {
            final owner = await getItemOwner(item.ownerId!);
            if (owner != null) {
              final affiliation =
                  (owner['department_affiliation'] as String?)?.trim().toUpperCase();
              final ownerName = owner['owner_name'] as String?;
              if (ownerName != null && affiliation != 'PFO' && affiliation != 'PHYSICAL FACILITIES') {
                if (!itemOwners.contains(ownerName)) {
                  itemOwners.add(ownerName);
                }
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

      /// Helper to safely add an office with its ID to both lists
      Future<void> addOfficeToChain(String officeName) async {
        final officeId = await _getOfficeIdByName(officeName);
        if (officeId != null) {
          officeTitles.add(officeName);
          officeIds.add(officeId);
        } else {
          // If office not found, log and skip to keep lists in sync
          print('Warning: office not found: $officeName');
        }
      }

      /// Helper to add item owner to the chain
      Future<void> addItemOwnersToChain() async {
        if (itemOwners.isNotEmpty && itemOwnerOfficeId != null) {
          for (final ownerName in itemOwners) {
            officeTitles.add(ownerName);
            officeIds.add(itemOwnerOfficeId);
          }
        }
      }

      if (roomType == 'Gym') {
        // Gym: General Education → Program Chair → SDAO → DO → Security → Physical Facilities
        await addOfficeToChain('General Education');
        if (itemOwners.isNotEmpty) {
          await addItemOwnersToChain();
        }
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else if (roomType == 'Classroom') {
        // Classroom: Item Owner? → Program Chair → SDAO → DO → Security → Physical Facilities
        if (itemOwners.isNotEmpty) {
          await addItemOwnersToChain();
        }
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else if (roomType == 'AVR' || roomType == 'Lobby' || roomType == 'Student Lounge') {
        // AVR/Lobby/Student Lounge: Item Owner? → Program Chair → SDAO → DO → Security → Physical Facilities
        if (itemOwners.isNotEmpty) {
          await addItemOwnersToChain();
        }
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else if (hasItems) {
        // Item only: Item Owner → Program Chair → SDAO → DO → Security → Physical Facilities
        await addItemOwnersToChain();
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else {
        // No items, default room: Program Chair → SDAO → DO → Security → Physical Facilities
        for (final office in standardOffices) {
          await addOfficeToChain(office);
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
    List<String>? reportedItems,
  }) async {
    late final Map<String, dynamic> payload;
    try {
      // Prefer the active Supabase authenticated session values where possible.
      final session = _client.auth.currentSession;
      final authEmail = session?.user.email?.trim() ??
          AuthService.currentUser?['email']?.toString().trim();

      final userId = AuthService.currentUser?['user_id'] as int?;
      final authUserId = session?.user.id?.trim() ??
          AuthService.currentUser?['auth_user_id']?.toString().trim();
      final hasImageUrlColumn = await _tableHasColumn('reservation_issues', 'image_url');
      final hasAuthUserIdColumn = await _tableHasColumn('reservation_issues', 'auth_user_id');
      final hasReportedByColumn = await _tableHasColumn('reservation_issues', 'reported_by');

      payload = <String, dynamic>{
        'reservation_id': reservationId,
        'description': description,
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Attach auth identifiers to satisfy RLS policies.
      if (hasReportedByColumn && authEmail != null && authEmail.isNotEmpty) {
        payload['reported_by'] = authEmail;
      }
      if (hasAuthUserIdColumn && authUserId != null && authUserId.isNotEmpty) {
        payload['auth_user_id'] = authUserId;
      }
      // Preserve numeric user_id if we have it (legacy users table).
      if (userId != null) {
        payload['user_id'] = userId;
      }

      String? imageUrl;
      if (imageName != null && imageName.isNotEmpty) {
        payload['image_name'] = imageName;
      }

      if (imageBase64 != null && imageBase64.isNotEmpty && imageName != null && imageName.isNotEmpty) {
        final filePath = _buildReportFilePath(reservationId, imageName);
        imageUrl = await _uploadReportImageFromBase64(imageBase64, filePath);
        if (imageUrl != null && hasImageUrlColumn) {
          payload['image_url'] = imageUrl;
        } else {
          payload['description'] = '$description\n\n(Image upload failed or image_url unsupported. Image was not attached to this report.)';
        }
      }

      if (reportedItems != null && reportedItems.isNotEmpty) {
        // Only include the reported_items column if it exists in the DB schema.
        try {
          final hasColumn = await _tableHasColumn('reservation_issues', 'reported_items');
          if (hasColumn) {
            payload['reported_items'] = reportedItems;
          } else {
            // Fallback: append a short list of reported items to the description
            payload['description'] = '$description\n\nReported items: ${reportedItems.join(', ')}';
          }
        } catch (_) {
          payload['description'] = '$description\n\nReported items: ${reportedItems.join(', ')}';
        }
      }

      final response = await _client.from('reservation_issues').insert(payload).select().maybeSingle();
      return response != null;
    } catch (e) {
      print('Error submitting issue report: $e');
      if (SupabaseService.serviceRoleKey.isNotEmpty) {
        return await _submitIssueReportWithServiceRole(payload);
      }
      return false;
    }
  }

  Future<bool> _submitIssueReportWithServiceRole(Map<String, dynamic> payload) async {
    final serviceRoleKey = SupabaseService.serviceRoleKey;
    if (serviceRoleKey.isEmpty) {
      print('Service role key not available for report insert fallback');
      return false;
    }

    try {
      final serviceClient = SupabaseClient(SupabaseService.supabaseUrl, serviceRoleKey);
      final response = await serviceClient.from('reservation_issues').insert(payload).select().maybeSingle();
      return response != null;
    } catch (e) {
      print('Service-role report insert failed: $e');
      return false;
    }
  }

  Future<String?> _uploadReportImageFromBase64(String imageBase64, String filePath) async {
    try {
      final imageBytes = base64Decode(imageBase64);
      final tempDir = Directory.systemTemp;
      final uploadTempFile = File('${tempDir.path}/$filePath');
      await uploadTempFile.parent.create(recursive: true);
      await uploadTempFile.writeAsBytes(imageBytes, flush: true);

      try {
        await _client.storage.from('reports').upload(
              filePath,
              uploadTempFile,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
      } catch (e) {
        final serviceRoleKey = SupabaseService.serviceRoleKey;
        if (serviceRoleKey.isNotEmpty) {
          try {
            final storageClient = SupabaseClient(SupabaseService.supabaseUrl, serviceRoleKey);
            await storageClient.storage.from('reports').upload(
                  filePath,
                  uploadTempFile,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: true,
                  ),
                );
            return _getPublicUrlFromStorageClient(storageClient, filePath);
          } catch (fallbackError) {
            print('Service-role upload fallback failed: $fallbackError');
            return null;
          }
        }
        print('Error uploading report image: $e');
        return null;
      }

      return _getPublicUrlFromStorageClient(_client, filePath);
    } catch (e) {
      print('Error uploading report image: $e');
      return null;
    }
  }

  String? _getPublicUrlFromStorageClient(SupabaseClient client, String filePath) {
    final urlResponse = client.storage.from('reports').getPublicUrl(filePath);
    if (urlResponse is String) {
      return urlResponse;
    }
    if (urlResponse is Map) {
      final urlMap = Map<String, dynamic>.from(urlResponse as Map);
      return urlMap['publicUrl']?.toString() ?? urlMap['publicURL']?.toString();
    }
    return null;
  }

  String _buildReportFilePath(int reservationId, String imageName) {
    final sanitizedName = imageName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'reports/$reservationId/${timestamp}_$sanitizedName';
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

  /// Check whether a table has a specific column by querying the table directly.
  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    try {
      await _client
          .from(tableName)
          .select(columnName)
          .limit(1)
          .maybeSingle();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ReservationTimelineEntry>> _buildApprovalTimeline(
      int reservationId, DateTime date) async {
    try {
      // Use canonical chain to force UI order, but read DB rows for status/timestamps.
      final itemOwnerNames = await _getReservationItemOwnerNames(reservationId);

      final roomType = await _getReservationRoomType(reservationId);
      final itemIds = await _getReservationItemIds(reservationId);

      final approvalChain = await calculateApprovalChain(
        roomType: roomType ?? '',
        itemIds: itemIds.isEmpty ? null : itemIds,
      );

      final approvalsResponse = await _client
          .from('reservation_approvals')
          .select('office_id, status, created_at, updated_at')
          .eq('reservation_id', reservationId)
          .order('created_at', ascending: true);

      final rawApprovals = <Map<String, dynamic>>[];
      if (approvalsResponse != null) {
        for (final a in approvalsResponse as List) {
          final row = Map<String, dynamic>.from(a as Map<String, dynamic>);
          // Augment with office_name when possible for robust matching
          final officeId = row['office_id'] as int?;
          if (officeId != null) {
            final office = await _getOfficeById(officeId);
            row['office_name'] = office?['department_name'] as String?;
          } else {
            row['office_name'] = null;
          }
          rawApprovals.add(row);
        }
      }

      // Debug: print canonical approval chain and raw approval rows
      try {
        print('DEBUG: reservation $reservationId approvalChain offices: ${jsonEncode(approvalChain.offices)}');
        print('DEBUG: reservation $reservationId approvalChain officeIds: ${jsonEncode(approvalChain.officeIds)}');
        print('DEBUG: reservation $reservationId rawApprovals: ${jsonEncode(rawApprovals.map((r) => {'office_id': r['office_id'], 'status': r['status'], 'created_at': r['created_at'], 'updated_at': r['updated_at']}).toList())}');
      } catch (_) {}

      final entries = <ReservationTimelineEntry>[];
      entries.add(ReservationTimelineEntry(
        title: 'Request Submitted',
        status: 'Completed',
        date: date,
        timestamp: _formatTimestamp(date),
        description: 'Your reservation request was submitted successfully.',
      ));

      final used = List<bool>.filled(rawApprovals.length, false);
      final itemOwnerOfficeId = await _getOfficeIdByName('Item Owner');

      // First pass: attempt to match rows to canonical slots by office_id or office_name
      final slots = <Map<String, dynamic>>[];
      for (var i = 0; i < approvalChain.officeIds.length; i++) {
        final expectedOfficeId = approvalChain.officeIds[i];
        final displayName = approvalChain.offices[i];

        int matchIndex = -1;
        for (var j = 0; j < rawApprovals.length; j++) {
          if (used[j]) continue;
          final rowOfficeId = rawApprovals[j]['office_id'] as int?;
          if (rowOfficeId != null && expectedOfficeId != null && rowOfficeId == expectedOfficeId) {
            matchIndex = j;
            break;
          }
        }

        // Fallback: match by office name (normalized contains) when ID matching failed
        if (matchIndex == -1) {
          final expectedNorm = displayName.toLowerCase().replaceAll(RegExp(r"\s+"), '');
          for (var j = 0; j < rawApprovals.length; j++) {
            if (used[j]) continue;
            final rowName = (rawApprovals[j]['office_name'] as String?)?.toLowerCase();
            if (rowName == null) continue;
            final rowNorm = rowName.replaceAll(RegExp(r"\s+"), '');
            if (rowNorm.contains(expectedNorm) || expectedNorm.contains(rowNorm)) {
              matchIndex = j;
              break;
            }
          }
        }

        // Reserve if matched now
        if (matchIndex != -1) used[matchIndex] = true;

        slots.add({
          'index': i,
          'displayName': displayName,
          'expectedOfficeId': expectedOfficeId,
          'matchIndex': matchIndex,
        });
      }

      // Second pass: assign any remaining rows to unmatched slots using best-effort (prefer approved rows)
      final remainingRowIndexes = <int>[];
      for (var j = 0; j < rawApprovals.length; j++) {
        if (!used[j]) remainingRowIndexes.add(j);
      }

      final unmatchedSlots = slots.where((s) => s['matchIndex'] == -1).toList();
      for (final slot in unmatchedSlots) {
        if (remainingRowIndexes.isEmpty) break;

        int pick = -1;
        // prefer an approved/completed/accepted row
        for (var k = 0; k < remainingRowIndexes.length; k++) {
          final ri = remainingRowIndexes[k];
          final rs = (rawApprovals[ri]['status'] as String?)?.toLowerCase() ?? '';
          if (rs.contains('approved') || rs.contains('completed') || rs.contains('accepted')) {
            pick = ri;
            remainingRowIndexes.removeAt(k);
            break;
          }
        }

        // otherwise pick the earliest by created_at
        if (pick == -1) {
          int earliestIdx = -1;
          int? earliestTs;
          for (var k = 0; k < remainingRowIndexes.length; k++) {
            final ri = remainingRowIndexes[k];
            final created = rawApprovals[ri]['created_at'] as String?;
            int ts;
            try {
              ts = DateTime.parse(created ?? DateTime.now().toIso8601String()).millisecondsSinceEpoch;
            } catch (_) {
              ts = DateTime.now().millisecondsSinceEpoch;
            }
            if (earliestTs == null || ts < earliestTs) {
              earliestTs = ts;
              earliestIdx = k;
            }
          }
          if (earliestIdx != -1) {
            pick = remainingRowIndexes.removeAt(earliestIdx);
          }
        }

        if (pick != -1) {
          // Mark used and set matchIndex on slot
          used[pick] = true;
          slot['matchIndex'] = pick;
          try {
            print('DEBUG: reservation $reservationId second-pass assigned row $pick to slot ${slot['index']} (${slot['displayName']})');
          } catch (_) {}
        }
      }

      // Now build entries preserving slot order
      for (final slot in slots) {
        final displayName = slot['displayName'] as String;
        final matchIndex = slot['matchIndex'] as int;

        String status = 'Pending';
        String timestamp = 'Pending';
        String description = 'Waiting for approval from $displayName.';

        if (matchIndex != -1) {
          final row = rawApprovals[matchIndex];
          final rowStatus = (row['status'] as String?)?.trim().toLowerCase() ?? 'pending';
          final createdAt = row['created_at'] as String?;
          final updatedAt = row['updated_at'] as String?;
          status = rowStatus == 'approved' || rowStatus == 'completed' || rowStatus == 'accepted'
              ? 'Approved'
              : rowStatus == 'rejected' || rowStatus == 'denied'
                  ? 'Rejected'
                  : 'Pending';
          if (status == 'Pending') {
            timestamp = 'Pending';
          } else {
            timestamp = _formatTimestamp(DateTime.parse(updatedAt ?? createdAt ?? DateTime.now().toIso8601String()));
          }
          description = status == 'Approved'
              ? 'Your reservation has been approved by $displayName.'
              : status == 'Rejected'
                  ? 'Your reservation was rejected by $displayName.'
                  : 'Waiting for approval from $displayName.';
        }

        entries.add(ReservationTimelineEntry(
          title: displayName,
          status: status,
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

  /// Debug helper: print raw and sorted approval entries for a reservation.
  Future<void> printDebugApprovalOrder(int reservationId) async {
    try {
      final itemOwnerNames = await _getReservationItemOwnerNames(reservationId);
      final approvalsResponse = await _client
          .from('reservation_approvals')
          .select('office_id, status, created_at, updated_at')
          .eq('reservation_id', reservationId)
          .order('created_at', ascending: true);

      if (approvalsResponse == null) {
        print('DEBUG: reservation $reservationId no approvals found');
        return;
      }

      final approvalEntries = <Map<String, dynamic>>[];
      for (final approval in approvalsResponse as List) {
        final officeId = approval['office_id'] as int?;
        String officeName = officeId == null
            ? 'Approval Step'
            : (await _getOfficeById(officeId))?['department_name'] as String? ?? 'Approval Step';
        if (officeName.toLowerCase() == 'item owner' && itemOwnerNames.isNotEmpty) {
          officeName = itemOwnerNames.join(', ');
        }
        approvalEntries.add({
          'office_name': officeName,
          'status': approval['status'],
          'created_at': approval['created_at'],
          'office_id': officeId,
        });
      }

      print('DEBUG: reservation $reservationId raw approvals: ${approvalEntries.map((e) => e['office_name']).toList()}');

      final ordered = sortApprovalEntriesForTimeline(
        approvalEntries,
        itemOwnerOfficeId: await _getOfficeIdByName('Item Owner'),
      );

      print('DEBUG: reservation $reservationId ordered approvals: ${ordered.map((e) => e['office_name']).toList()}');
    } catch (e) {
      print('DEBUG: error printing approval order for $reservationId: $e');
    }
  }

  Future<String?> _getReservationRoomType(int reservationId) async {
    try {
      final detailResponse = await _client
          .from('reservation_details')
          .select('reservation_rooms_id')
          .eq('reservation_id', reservationId)
          .limit(1)
          .maybeSingle();

      final roomReservationId = detailResponse?['reservation_rooms_id'] as int?;
      if (roomReservationId == null) return null;

      final roomReservation = await _client
          .from('reservation_rooms')
          .select('room_id')
          .eq('reservation_rooms_id', roomReservationId)
          .limit(1)
          .maybeSingle();
      final roomId = roomReservation?['room_id'] as int?;
      if (roomId == null) return null;

      final room = await _client
          .from('rooms')
          .select('room_type')
          .eq('room_id', roomId)
          .limit(1)
          .maybeSingle();

      return room?['room_type'] as String?;
    } catch (e) {
      print('Error fetching reservation room type: $e');
      return null;
    }
  }

  Future<List<int>> _getReservationItemIds(int reservationId) async {
    final ids = <int>[];
    try {
      final details = await _client
          .from('reservation_details')
          .select('reservation_items_id')
          .eq('reservation_id', reservationId);
      if (details == null) return ids;
      for (final det in details as List) {
        final reservationItemsId = det['reservation_items_id'] as int?;
        if (reservationItemsId == null) continue;

        final itemLink = await _client
            .from('reservation_items')
            .select('item_id')
            .eq('reservation_items_id', reservationItemsId)
            .maybeSingle();
        final itemId = itemLink?['item_id'] as int?;
        if (itemId != null) ids.add(itemId);
      }
    } catch (e) {
      print('Error fetching reservation item ids: $e');
    }
    return ids;
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

          await _reserveItemUnitsForReservation(
            reservationItemsId: reservationItemsId,
            itemId: itemId,
            quantity: 1,
          );

          final currentItem = await getItemDetails(itemId);
          if (currentItem != null) {
            await _client.from('items').update({
              'quantity_in_use': currentItem.quantityInUse,
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
    DateTime? requestStart,
    DateTime? requestEnd,
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

      // Validate requested item availability before persisting the reservation.
      for (final itemId in itemQuantities.keys) {
        final quantity = itemQuantities[itemId]!;
        if (quantity <= 0) {
          throw Exception('Invalid quantity requested for item $itemId: $quantity');
        }

        final availableUnits = await _getAvailableItemUnits(
          itemId,
          quantity,
          requestStart: requestStart,
          requestEnd: requestEnd,
        );
        if (availableUnits.length < quantity) {
          throw Exception('Not enough available units for item $itemId: requested $quantity, available ${availableUnits.length}');
        }
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

        await _reserveItemUnitsForReservation(
          reservationItemsId: reservationItemsId,
          itemId: itemId,
          quantity: quantity,
          requestStart: requestStart,
          requestEnd: requestEnd,
        );

        // Update the item's in-use quantity from the actual unit state.
        final currentItem = await getItemDetails(itemId);
        if (currentItem != null) {
          await _client.from('items').update({
            'quantity_in_use': currentItem.quantityInUse,
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
    } catch (e, stack) {
      print('Error creating item reservation: $e');
      print(stack);
      rethrow;
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
