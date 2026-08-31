import 'package:flutter/foundation.dart';

import '../models/hotel.dart';
import '../models/hotel_detail.dart';
import 'hotel_service.dart';

/// A room and one rate selected for the current stay.
///
/// The first implementation deliberately supports one selection only. The
/// model is kept outside the widget so a provider-backed repository can replace
/// the preview service without changing the Choose Room or checkout layouts.
@immutable
class HotelRoomSelection {
  const HotelRoomSelection({
    required this.hotel,
    required this.criteria,
    required this.room,
    required this.offer,
  });

  final Hotel hotel;
  final HotelSearchCriteria criteria;
  final HotelRoomType room;
  final HotelRoomOffer offer;

  double get subtotal => offer.nightlyPrice * criteria.nights;
  double get total => offer.totalPrice;
}

@immutable
class HotelAvailability {
  const HotelAvailability({required this.detail, required this.offersByRoom});

  final HotelDetail detail;
  final Map<String, List<HotelRoomOffer>> offersByRoom;

  List<HotelRoomType> get availableRooms => detail.roomTypes
      .where((room) => offersByRoom[room.id]?.isNotEmpty ?? false)
      .toList(growable: false);
}

@immutable
class MockHotelHold {
  const MockHotelHold({required this.id, required this.expiresAt});

  final String id;
  final DateTime expiresAt;
}

abstract interface class HotelBookingService {
  Future<HotelAvailability> fetchAvailability(
    Hotel hotel,
    HotelSearchCriteria criteria,
  );

  Future<HotelRoomOffer?> revalidate(HotelRoomSelection selection);

  Future<MockHotelHold> createHold(HotelRoomSelection selection);
}

/// Development-only hotel availability and hold behavior.
///
/// No inventory is decremented, no document is written and no provider is
/// contacted. A real implementation must perform re-pricing and inventory
/// locking on the backend; this class exists only to make the approved flow
/// testable while that integration is undecided.
class PreviewHotelBookingService implements HotelBookingService {
  const PreviewHotelBookingService({
    this.hotelService = const PreviewHotelService(),
    this.delay = const Duration(milliseconds: 250),
  });

  final HotelService hotelService;
  final Duration delay;

  @override
  Future<HotelAvailability> fetchAvailability(
    Hotel hotel,
    HotelSearchCriteria criteria,
  ) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final detail = await hotelService.fetchDetail(hotel.id);
    if (detail == null) throw StateError('Hotel details are unavailable');

    final guests = criteria.adults + criteria.children;
    final offersByRoom = <String, List<HotelRoomOffer>>{};
    for (final room in detail.roomTypes) {
      if (criteria.rooms != 1 || guests > room.maxOccupancy) continue;
      final offers = detail.roomOffers
          .where((offer) => offer.roomTypeId == room.id && offer.isAvailable)
          .map((offer) => _priceForStay(offer, criteria.nights))
          .toList(growable: false);
      if (offers.isNotEmpty) offersByRoom[room.id] = offers;
    }
    return HotelAvailability(detail: detail, offersByRoom: offersByRoom);
  }

  HotelRoomOffer _priceForStay(HotelRoomOffer offer, int nights) {
    final subtotal = offer.nightlyPrice * nights;
    final taxes = subtotal * .15;
    final fees = 6.0 * nights;
    return HotelRoomOffer(
      id: offer.id,
      roomTypeId: offer.roomTypeId,
      name: offer.name,
      mealPlan: offer.mealPlan,
      currencyCode: offer.currencyCode,
      nightlyPrice: offer.nightlyPrice,
      totalPrice: subtotal + taxes + fees,
      taxes: taxes,
      fees: fees,
      taxesIncluded: false,
      breakfast: offer.breakfast,
      cancellationType: offer.cancellationType,
      cancellationDeadline: offer.cancellationDeadline,
      cancellationPenalty: offer.cancellationPenalty,
      prepayment: offer.prepayment,
      paymentTiming: offer.paymentTiming,
      availableQuantity: offer.availableQuantity,
      providerId: 'preview-only',
      providerHotelId: offer.providerHotelId,
      providerRoomId: offer.providerRoomId,
      ratePlanId: offer.ratePlanId ?? offer.id,
      searchSessionId: 'preview-session',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<HotelRoomOffer?> revalidate(HotelRoomSelection selection) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!selection.offer.isAvailable || selection.offer.isExpired) return null;
    return _priceForStay(selection.offer, selection.criteria.nights);
  }

  @override
  Future<MockHotelHold> createHold(HotelRoomSelection selection) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!selection.offer.isAvailable) {
      throw StateError('The selected preview room is unavailable');
    }
    final now = DateTime.now();
    return MockHotelHold(
      id: 'mock-${selection.offer.id}-${now.microsecondsSinceEpoch}',
      expiresAt: now.add(const Duration(minutes: 10)),
    );
  }
}
