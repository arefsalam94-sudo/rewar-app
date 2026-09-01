import '../models/hotel.dart';
import '../models/hotel_detail.dart';

abstract interface class HotelService {
  Future<List<Hotel>> trendingHotels();

  Future<List<Hotel>> searchHotels(HotelSearchCriteria criteria);

  Future<List<HotelDestination>> searchDestinations(String query);

  /// Everything the Hotel Details page needs beyond the card data.
  ///
  /// Returns null when the hotel is not in the catalog, which the detail
  /// screen renders as its localized "not found" state rather than an
  /// empty page.
  Future<HotelDetail?> fetchDetail(String hotelId);
}

/// Typed design-review data used until an accommodation provider is chosen.
///
/// Nothing in this implementation represents live price or availability. A
/// provider-backed implementation can replace it without changing the screen.
///
/// The gallery entries, facilities, nearby places, rooms, rates and policies
/// below are **sample values** so the Hotel Details page can be reviewed. They
/// are not claims about these properties, and none of them is seeded to
/// Firestore — see `SEED_DATA.md`.
class PreviewHotelService implements HotelService {
  const PreviewHotelService();

  /// Bundled photographs the preview gallery pages through. Five entries
  /// because five is what the design review asked to see; the gallery itself
  /// renders whatever number a hotel carries.
  static const previewGallery = <String>[
    'assets/images/hotel background.webp',
    'assets/images/journey-stay.png',
    'assets/images/main screen back image.webp',
    'assets/images/featured-rawanduz.png',
    'assets/images/explore tour.webp',
  ];

  static const destinations = <HotelDestination>[
    HotelDestination(
      id: 'erbil',
      name: HotelText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
    ),
    HotelDestination(
      id: 'sulaimani',
      name: HotelText(en: 'Sulaimania', ku: 'سلێمانی', ar: 'السليمانية'),
    ),
    HotelDestination(
      id: 'duhok',
      name: HotelText(en: 'Duhok', ku: 'دهۆک', ar: 'دهوك'),
    ),
  ];

  static final hotels = <Hotel>[
    const Hotel(
      id: 'preview-divan-erbil',
      name: HotelText(en: 'Divan Erbil', ku: 'دیڤان هەولێر', ar: 'ديفان أربيل'),
      city: HotelText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
      address: HotelText(
        en: 'Gulan Street, Erbil, Kurdistan Region, Iraq',
        ku: 'شەقامی گوڵان، هەولێر، هەرێمی کوردستان، عێراق',
        ar: 'شارع كولان، أربيل، إقليم كوردستان، العراق',
      ),
      latitude: 36.2027,
      longitude: 43.9930,
      imageAsset: 'assets/images/journey-stay.png',
      images: previewGallery,
      starRating: 5,
      reviewScore: 9.1,
      reviewCount: 128,
      distanceFromCenterKm: 2.6,
      pricePerNight: 200,
      currencyCode: 'USD',
      amenities: {
        HotelAmenity.pool,
        HotelAmenity.wifi,
        HotelAmenity.gym,
        HotelAmenity.bar,
      },
      highlighted: true,
    ),
    const Hotel(
      id: 'preview-ramada-sulaimani',
      name: HotelText(
        en: 'Ramada Sulaimani',
        ku: 'ڕامادا سلێمانی',
        ar: 'رمادا السليمانية',
      ),
      city: HotelText(en: 'Sulaimania', ku: 'سلێمانی', ar: 'السليمانية'),
      address: HotelText(
        en: 'Salim Street, Sulaimania, Kurdistan Region, Iraq',
        ku: 'شەقامی سالم، سلێمانی، هەرێمی کوردستان، عێراق',
        ar: 'شارع سالم، السليمانية، إقليم كوردستان، العراق',
      ),
      latitude: 35.5556,
      longitude: 45.4351,
      imageAsset: 'assets/images/hotel background.webp',
      images: previewGallery,
      starRating: 4,
      reviewScore: 8.8,
      reviewCount: 64,
      distanceFromCenterKm: 1.4,
      pricePerNight: 145,
      currencyCode: 'USD',
      amenities: {
        HotelAmenity.pool,
        HotelAmenity.wifi,
        HotelAmenity.restaurant,
        HotelAmenity.parking,
      },
      highlighted: true,
    ),
    // Deliberately sparse: no gallery, no coordinates, no facilities, no
    // nearby places and no review aggregate, so the detail page's hidden
    // sections and empty states stay reviewable against a real object.
    const Hotel(
      id: 'preview-duhok-palace',
      name: HotelText(en: 'Duhok Palace', ku: 'کۆشکی دهۆک', ar: 'قصر دهوك'),
      city: HotelText(en: 'Duhok', ku: 'دهۆک', ar: 'دهوك'),
      imageAsset: 'assets/images/main screen back image.webp',
      starRating: 4,
      reviewScore: 8.5,
      distanceFromCenterKm: 3.2,
      pricePerNight: 120,
      currencyCode: 'USD',
      amenities: {
        HotelAmenity.wifi,
        HotelAmenity.restaurant,
        HotelAmenity.gym,
        HotelAmenity.parking,
      },
      highlighted: true,
    ),
  ];

  @override
  Future<List<Hotel>> trendingHotels() async => List.unmodifiable(hotels);

  @override
  Future<List<HotelDestination>> searchDestinations(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return destinations;
    return destinations
        .where(
          (destination) => <String>[
            destination.name.en,
            destination.name.ku,
            destination.name.ar,
          ].any((name) => name.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Hotel>> searchHotels(HotelSearchCriteria criteria) async {
    return hotels
        .where((hotel) {
          final destinationMatches =
              criteria.destination == null ||
              hotel.city.en.toLowerCase() ==
                  criteria.destination!.name.en.toLowerCase();
          final amenitiesMatch = criteria.amenities.every(
            hotel.amenities.contains,
          );
          return destinationMatches && amenitiesMatch;
        })
        .toList(growable: false);
  }

  @override
  Future<HotelDetail?> fetchDetail(String hotelId) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final matches = hotels.where((item) => item.id == hotelId);
    if (matches.isEmpty) return null;
    final hotel = matches.first;
    return switch (hotelId) {
      'preview-divan-erbil' => _divanDetail(hotel),
      'preview-ramada-sulaimani' => _ramadaDetail(hotel),
      _ => HotelDetail(hotel: hotel),
    };
  }
}

HotelDetail _divanDetail(Hotel hotel) => HotelDetail(
  hotel: hotel,
  facilities: _divanFacilities,
  reviewSummary: const HotelReviewSummary(
    score: 9.1,
    reviewCount: 128,
    categoryScores: <HotelReviewCategory, double>{
      HotelReviewCategory.location: 9.4,
      HotelReviewCategory.cleanliness: 9.0,
      HotelReviewCategory.comfort: 8.8,
      HotelReviewCategory.service: 9.2,
      HotelReviewCategory.value: 8.3,
    },
  ),
  nearbyPlaces: _erbilNearby,
  roomTypes: _divanRooms,
  roomOffers: _divanOffers,
  policies: _divanPolicies,
);

HotelDetail _ramadaDetail(Hotel hotel) => HotelDetail(
  hotel: hotel,
  facilities: _divanFacilities.take(6).toList(growable: false),
  reviewSummary: const HotelReviewSummary(
    score: 8.8,
    reviewCount: 64,
    categoryScores: <HotelReviewCategory, double>{
      HotelReviewCategory.location: 9.0,
      HotelReviewCategory.cleanliness: 8.7,
      HotelReviewCategory.comfort: 8.5,
      HotelReviewCategory.service: 8.9,
      HotelReviewCategory.value: 8.6,
      HotelReviewCategory.wifi: 8.1,
    },
  ),
  roomTypes: _divanRooms.take(1).toList(growable: false),
);

const _divanFacilities = <HotelFacility>[
  HotelFacility(
    id: 'outdoor-pool',
    name: HotelText(
      en: 'Outdoor Pool',
      ku: 'مەلەوانگەی دەرەوە',
      ar: 'مسبح خارجي',
    ),
    category: HotelFacilityCategory.pool,
    iconKey: 'pool',
  ),
  HotelFacility(
    id: 'breakfast',
    name: HotelText(en: 'Breakfast', ku: 'نانی بەیانی', ar: 'فطور'),
    category: HotelFacilityCategory.foodAndDrink,
    iconKey: 'breakfast',
  ),
  HotelFacility(
    id: 'airport-shuttle',
    name: HotelText(
      en: 'Airport Shuttle',
      ku: 'گواستنەوەی فڕۆکەخانە',
      ar: 'خدمة نقل المطار',
    ),
    category: HotelFacilityCategory.transportation,
    iconKey: 'airportShuttle',
  ),
  HotelFacility(
    id: 'free-wifi',
    name: HotelText(
      en: 'Free WiFi',
      ku: 'وایفای بەخۆڕایی',
      ar: 'واي فاي مجاني',
    ),
    category: HotelFacilityCategory.internet,
    iconKey: 'wifi',
  ),
  HotelFacility(
    id: 'front-desk-24h',
    name: HotelText(
      en: '24-hour front desk',
      ku: 'پێشوازی ٢٤ کاتژمێری',
      ar: 'استقبال على مدار الساعة',
    ),
    category: HotelFacilityCategory.general,
    iconKey: 'frontDesk',
  ),
  HotelFacility(
    id: 'free-parking',
    name: HotelText(
      en: 'Free private parking',
      ku: 'گەراجی تایبەتی بەخۆڕایی',
      ar: 'موقف خاص مجاني',
    ),
    category: HotelFacilityCategory.parking,
    iconKey: 'parking',
  ),
  HotelFacility(
    id: 'restaurant',
    name: HotelText(en: 'Restaurant', ku: 'چێشتخانە', ar: 'مطعم'),
    category: HotelFacilityCategory.foodAndDrink,
    iconKey: 'restaurant',
  ),
  HotelFacility(
    id: 'bar',
    name: HotelText(en: 'Bar', ku: 'بار', ar: 'بار'),
    category: HotelFacilityCategory.foodAndDrink,
    iconKey: 'bar',
  ),
  HotelFacility(
    id: 'fitness-centre',
    name: HotelText(en: 'Fitness centre', ku: 'هۆڵی وەرزش', ar: 'مركز لياقة'),
    category: HotelFacilityCategory.wellness,
    iconKey: 'gym',
  ),
  HotelFacility(
    id: 'spa',
    name: HotelText(
      en: 'Spa and wellness',
      ku: 'سپا و تەندروستی',
      ar: 'سبا وعافية',
    ),
    category: HotelFacilityCategory.wellness,
    iconKey: 'spa',
  ),
  HotelFacility(
    id: 'air-conditioning',
    name: HotelText(en: 'Air conditioning', ku: 'فێنککەرەوە', ar: 'تكييف'),
    category: HotelFacilityCategory.roomFacilities,
    iconKey: 'airConditioning',
  ),
  HotelFacility(
    id: 'family-rooms',
    name: HotelText(en: 'Family rooms', ku: 'ژووری خێزانی', ar: 'غرف عائلية'),
    category: HotelFacilityCategory.family,
    iconKey: 'familyRooms',
  ),
  HotelFacility(
    id: 'accessible-rooms',
    name: HotelText(
      en: 'Wheelchair accessible',
      ku: 'گونجاو بۆ کورسی چەرخدار',
      ar: 'مهيأ لذوي الاحتياجات',
    ),
    category: HotelFacilityCategory.accessibility,
    iconKey: 'accessible',
  ),
  HotelFacility(
    id: 'meeting-rooms',
    name: HotelText(
      en: 'Meeting rooms',
      ku: 'ژووری کۆبوونەوە',
      ar: 'قاعات اجتماعات',
    ),
    category: HotelFacilityCategory.business,
    iconKey: 'meetingRooms',
  ),
  HotelFacility(
    id: 'security-24h',
    name: HotelText(
      en: '24-hour security',
      ku: 'ئاسایشی ٢٤ کاتژمێری',
      ar: 'أمن على مدار الساعة',
    ),
    category: HotelFacilityCategory.safety,
    iconKey: 'security',
  ),
];

const _erbilNearby = <HotelNearbyPlace>[
  HotelNearbyPlace(
    id: 'erbil-citadel',
    name: HotelText(en: 'Erbil Citadel', ku: 'قەڵای هەولێر', ar: 'قلعة أربيل'),
    type: NearbyPlaceType.landmark,
    distanceMeters: 2400,
    minutes: 9,
    latitude: 36.1911,
    longitude: 44.0092,
  ),
  HotelNearbyPlace(
    id: 'sami-abdulrahman-park',
    name: HotelText(
      en: 'Sami Abdulrahman Park',
      ku: 'پارکی سامی عەبدولڕەحمان',
      ar: 'حديقة سامي عبد الرحمن',
    ),
    type: NearbyPlaceType.park,
    distanceMeters: 700,
    minutes: 8,
    latitude: 36.1934,
    longitude: 43.9757,
  ),
  HotelNearbyPlace(
    id: 'family-mall',
    name: HotelText(en: 'Family Mall', ku: 'فامیلی مۆڵ', ar: 'فاميلي مول'),
    type: NearbyPlaceType.mall,
    distanceMeters: 1200,
    minutes: 5,
    latitude: 36.2076,
    longitude: 43.9840,
  ),
  HotelNearbyPlace(
    id: 'shar-garden',
    name: HotelText(en: 'Shar Garden', ku: 'باخی شار', ar: 'حديقة شار'),
    type: NearbyPlaceType.park,
    distanceMeters: 2600,
    minutes: 10,
  ),
  HotelNearbyPlace(
    id: 'atm',
    name: HotelText(en: 'ATM', ku: 'ئەی تی ئێم', ar: 'صراف آلي'),
    type: NearbyPlaceType.atm,
    distanceMeters: 300,
    minutes: 4,
  ),
  HotelNearbyPlace(
    id: 'erbil-airport',
    name: HotelText(
      en: 'Erbil International Airport',
      ku: 'فڕۆکەخانەی نێودەوڵەتی هەولێر',
      ar: 'مطار أربيل الدولي',
    ),
    type: NearbyPlaceType.airport,
    distanceMeters: 8100,
    minutes: 17,
    latitude: 36.2376,
    longitude: 43.9632,
  ),
];

const _divanRooms = <HotelRoomType>[
  HotelRoomType(
    id: 'garden-view',
    hotelId: 'preview-divan-erbil',
    name: HotelText(
      en: 'Garden View Room',
      ku: 'ژووری دیمەنی باخچە',
      ar: 'غرفة بإطلالة على الحديقة',
    ),
    description: HotelText(
      en: 'A calm room overlooking the hotel garden.',
      ku: 'ژوورێکی ئارام بە دیمەنی باخچەی هوتێل.',
      ar: 'غرفة هادئة تطل على حديقة الفندق.',
    ),
    images: <String>['assets/images/journey-stay.png'],
    sizeSqm: 70,
    adultCapacity: 2,
    childCapacity: 1,
    maxOccupancy: 3,
    beds: <BedConfiguration>[BedConfiguration(type: BedType.king)],
    facilities: <HotelFacility>[
      HotelFacility(
        id: 'smart-tech',
        name: HotelText(en: 'Smart Tech', ku: 'تەکنەلۆژیای زیرەک', ar: 'تقنيات ذكية'),
        category: HotelFacilityCategory.roomFacilities,
        iconKey: 'smartTech',
      ),
      HotelFacility(
        id: 'spa',
        name: HotelText(en: 'Spa & Massage', ku: 'سپا و ماساژ', ar: 'سبا وتدليك'),
        category: HotelFacilityCategory.wellness,
        iconKey: 'spa',
      ),
      HotelFacility(
        id: 'safety-lock',
        name: HotelText(en: 'Safety Lock', ku: 'قفڵی پاراستن', ar: 'قفل أمان'),
        category: HotelFacilityCategory.safety,
        iconKey: 'security',
      ),
      HotelFacility(
        id: 'gym',
        name: HotelText(en: 'Gym Access', ku: 'چوونە ژوورەوەی جیم', ar: 'دخول النادي الرياضي'),
        category: HotelFacilityCategory.wellness,
        iconKey: 'gym',
      ),
    ],
  ),
  HotelRoomType(
    id: 'king-room',
    hotelId: 'preview-divan-erbil',
    name: HotelText(
      en: 'King Room',
      ku: 'ژووری کینگ',
      ar: 'غرفة كينغ',
    ),
    description: HotelText(
      en: 'A spacious city-view room with a separate sofa bed.',
      ku: 'ژوورێکی فراوان بە دیمەنی شار و قەنەفەی جێگای جیاواز.',
      ar: 'غرفة واسعة بإطلالة على المدينة وأريكة سرير منفصلة.',
    ),
    images: <String>['assets/images/hotel background.webp'],
    sizeSqm: 68,
    adultCapacity: 3,
    childCapacity: 1,
    maxOccupancy: 4,
    beds: <BedConfiguration>[
      BedConfiguration(type: BedType.king),
      BedConfiguration(type: BedType.sofa),
    ],
    facilities: <HotelFacility>[
      HotelFacility(
        id: 'room-service',
        name: HotelText(en: 'Room Service', ku: 'خزمەتگوزاری ژوور', ar: 'خدمة الغرف'),
        category: HotelFacilityCategory.roomFacilities,
        iconKey: 'roomService',
      ),
      HotelFacility(
        id: 'city-view',
        name: HotelText(en: 'City View', ku: 'دیمەنی شار', ar: 'إطلالة على المدينة'),
        category: HotelFacilityCategory.general,
        iconKey: 'cityView',
      ),
      HotelFacility(
        id: 'spa',
        name: HotelText(en: 'Spa & Massage', ku: 'سپا و ماساژ', ar: 'سبا وتدليك'),
        category: HotelFacilityCategory.wellness,
        iconKey: 'spa',
      ),
      HotelFacility(
        id: 'lounge',
        name: HotelText(en: 'Rooftop Lounge', ku: 'لانجی سەربان', ar: 'صالة على السطح'),
        category: HotelFacilityCategory.foodAndDrink,
        iconKey: 'lounge',
      ),
    ],
  ),
];

const _divanOffers = <HotelRoomOffer>[
  HotelRoomOffer(
    id: 'garden-dinner',
    roomTypeId: 'garden-view',
    name: HotelText(en: 'Stay + Dinner', ku: 'مانەوە + نانی ئێوارە', ar: 'إقامة + عشاء'),
    mealPlan: HotelText(en: 'Breakfast and dinner included', ku: 'نانی بەیانی و ئێوارە لەگەڵدایە', ar: 'يشمل الإفطار والعشاء'),
    currencyCode: 'USD',
    nightlyPrice: 200,
    totalPrice: 400,
    taxes: 60,
    fees: 12,
    breakfast: BreakfastPolicy.included,
    cancellationType: CancellationType.free,
    prepayment: PrepaymentType.none,
    paymentTiming: PaymentTiming.payAtProperty,
    availableQuantity: 5,
  ),
  HotelRoomOffer(
    id: 'garden-room-only',
    roomTypeId: 'garden-view',
    name: HotelText(en: 'Room Only', ku: 'تەنها ژوور', ar: 'الغرفة فقط'),
    mealPlan: HotelText(en: 'No meals included', ku: 'هیچ ژەمێک لەگەڵدا نییە', ar: 'لا تشمل الوجبات'),
    currencyCode: 'USD',
    nightlyPrice: 172,
    totalPrice: 344,
    taxes: 51.6,
    fees: 12,
    breakfast: BreakfastPolicy.extra,
    cancellationType: CancellationType.nonRefundable,
    prepayment: PrepaymentType.full,
    paymentTiming: PaymentTiming.payNow,
    availableQuantity: 2,
  ),
  HotelRoomOffer(
    id: 'king-flex',
    roomTypeId: 'king-room',
    name: HotelText(en: 'Flexible Stay', ku: 'مانەوەی گۆڕاو', ar: 'إقامة مرنة'),
    mealPlan: HotelText(en: 'Breakfast included', ku: 'نانی بەیانی لەگەڵدایە', ar: 'يشمل الإفطار'),
    currencyCode: 'USD',
    nightlyPrice: 185,
    totalPrice: 370,
    taxes: 55.5,
    fees: 12,
    breakfast: BreakfastPolicy.included,
    cancellationType: CancellationType.partial,
    prepayment: PrepaymentType.partial,
    paymentTiming: PaymentTiming.payLater,
    availableQuantity: 3,
  ),
  HotelRoomOffer(
    id: 'king-room-only',
    roomTypeId: 'king-room',
    name: HotelText(en: 'Room Only', ku: 'تەنها ژوور', ar: 'الغرفة فقط'),
    mealPlan: HotelText(en: 'No meals included', ku: 'هیچ ژەمێک لەگەڵدا نییە', ar: 'لا تشمل الوجبات'),
    currencyCode: 'USD',
    nightlyPrice: 154,
    totalPrice: 308,
    taxes: 46.2,
    fees: 12,
    breakfast: BreakfastPolicy.unavailable,
    cancellationType: CancellationType.nonRefundable,
    prepayment: PrepaymentType.none,
    paymentTiming: PaymentTiming.payAtProperty,
    availableQuantity: 3,
  ),
];

const _divanPolicies = HotelPolicies(
  checkInFrom: '14:00',
  checkOutUntil: '12:00',
  childPolicy: HotelText(
    en:
        'Children of all ages are welcome. Children under 6 stay free when '
        'using an existing bed.',
    ku:
        'منداڵ لە هەموو تەمەنێکدا بەخێربێن. منداڵانی خوار ٦ ساڵ بەخۆڕایی '
        'دەمێننەوە ئەگەر جێگای ئامادە بەکاربهێنن.',
    ar:
        'نرحب بالأطفال من جميع الأعمار. يقيم الأطفال دون سن 6 سنوات مجاناً '
        'عند استخدام سرير متوفر.',
  ),
  cribPolicy: HotelText(
    en: 'Cribs are available on request at no extra charge.',
    ku: 'لانکە بە داواکاری و بەبێ تێچووی زیادە بەردەستە.',
    ar: 'أسرة الأطفال متاحة عند الطلب بدون رسوم إضافية.',
  ),
  extraBedPolicy: HotelText(
    en: 'One extra bed can be added to most rooms for an additional fee.',
    ku: 'دەکرێت یەک جێگای زیادە بۆ زۆربەی ژوورەکان زیاد بکرێت بە تێچوویەکی زیادە.',
    ar: 'يمكن إضافة سرير إضافي واحد لمعظم الغرف مقابل رسوم إضافية.',
  ),
  minimumAge: 18,
  petPolicy: HotelText(
    en: 'Pets are not allowed.',
    ku: 'ئاژەڵی ماڵی ڕێگەپێدراو نییە.',
    ar: 'الحيوانات الأليفة غير مسموح بها.',
  ),
  smokingPolicy: HotelText(
    en: 'Smoking is permitted in designated areas only.',
    ku: 'جگەرەکێشان تەنها لە شوێنە دیاریکراوەکاندا ڕێگەپێدراوە.',
    ar: 'التدخين مسموح في المناطق المخصصة فقط.',
  ),
  acceptedPaymentMethods: <String>['Visa', 'Mastercard', 'Cash'],
  specialRequestsSupported: true,
  accessibility: HotelText(
    en:
        'Step-free entrance, lift access and accessible bathrooms are '
        'available.',
    ku: 'دەروازەی بێ پلیکانە، ئاسانسۆر و گەرماوی گونجاو بەردەستن.',
    ar: 'مدخل بدون درجات، مصعد وحمامات مهيأة متوفرة.',
  ),
);
