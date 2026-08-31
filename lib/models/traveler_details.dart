/// The in-memory payload of checkout step 1 (Traveler Info).
///
/// Nothing here is written to Firestore by the client. `DATA_MODEL.md` grants
/// the app **owner-read only** on `bookings`: the document is created by the
/// checkout Cloud Function once the payment provider confirms the charge. This
/// object is therefore handed to the Payment step as an argument and dies with
/// the flow — there is deliberately no draft collection holding named
/// travellers' birth dates before a purchase exists.
library;

/// One person on the booking.
class TravelerDetails {
  const TravelerDetails({
    this.fullName = '',
    this.dateOfBirth,
    this.isLead = false,
  });

  final String fullName;
  final DateTime? dateOfBirth;

  /// The person the booking is issued to. Exactly one traveller carries this;
  /// [TravelerParty] is what enforces that, not the caller.
  final bool isLead;

  bool get isComplete => fullName.trim().length >= 2 && dateOfBirth != null;

  /// Whole years elapsed, or null when no birth date has been entered.
  ///
  /// Counts the birthday itself, not the month arithmetic: someone born on
  /// 29 February whose birthday has not "occurred" this year is still their
  /// real age the day after it would have fallen.
  int? ageOn(DateTime when) {
    final born = dateOfBirth;
    if (born == null) return null;
    var years = when.year - born.year;
    final hadBirthday =
        when.month > born.month ||
        (when.month == born.month && when.day >= born.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? 0 : years;
  }

  TravelerDetails copyWith({
    String? fullName,
    DateTime? dateOfBirth,
    bool? isLead,
  }) => TravelerDetails(
    fullName: fullName ?? this.fullName,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    isLead: isLead ?? this.isLead,
  );
}

/// Who to contact about the booking — not necessarily someone travelling.
///
/// Kept separate from the traveller list for that reason: a parent booking a
/// tour for two adult children is the contact and appears nowhere on the bus.
class BookingContact {
  const BookingContact({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.dialCode = '+964',
  });

  final String fullName;
  final String email;
  final String phone;

  /// Stored beside [phone] rather than concatenated into it, so the number can
  /// be re-rendered or re-validated later without re-parsing a prefix back out.
  final String dialCode;

  /// Deliberately permissive: one `@`, a dot in the domain, no spaces. A
  /// stricter regex rejects real addresses, and the address is verified by the
  /// confirmation email actually arriving, not by this check.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  bool get hasValidName => fullName.trim().length >= 2;
  bool get hasValidEmail => _email.hasMatch(email.trim());

  /// Digits only, 6–15, matching E.164's national-number range once the dial
  /// code is excluded.
  bool get hasValidPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 6 && digits.length <= 15;
  }

  bool get isComplete => hasValidName && hasValidEmail && hasValidPhone;

  BookingContact copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? dialCode,
  }) => BookingContact(
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    dialCode: dialCode ?? this.dialCode,
  );
}

/// The travellers on one booking, with the "exactly one lead" rule enforced
/// here rather than trusted to every caller that resizes the list.
class TravelerParty {
  TravelerParty._(this.travelers);

  /// Builds a party of [count] people, the first of whom leads.
  factory TravelerParty.ofSize(int count) => TravelerParty._(
    List<TravelerDetails>.unmodifiable([
      for (var i = 0; i < count; i++) TravelerDetails(isLead: i == 0),
    ]),
  );

  final List<TravelerDetails> travelers;

  int get size => travelers.length;

  int get leadIndex {
    final found = travelers.indexWhere((t) => t.isLead);
    return found < 0 ? 0 : found;
  }

  /// Grows or shrinks the party, keeping what the user already typed.
  ///
  /// Shrinking past the lead traveller re-seats the lead on the first person
  /// instead of leaving the party with none.
  TravelerParty resized(int count) {
    if (count == size) return this;
    final next = <TravelerDetails>[
      for (var i = 0; i < count; i++)
        i < travelers.length ? travelers[i] : const TravelerDetails(),
    ];
    return TravelerParty._(
      List<TravelerDetails>.unmodifiable(next),
    )._withLead();
  }

  TravelerParty updated(int index, TravelerDetails traveler) {
    if (index < 0 || index >= size) return this;
    final next = [...travelers]..[index] = traveler;
    return TravelerParty._(
      List<TravelerDetails>.unmodifiable(next),
    )._withLead();
  }

  /// Moves the lead designation, clearing it everywhere else.
  TravelerParty withLead(int index) {
    if (index < 0 || index >= size) return this;
    return TravelerParty._(
      List<TravelerDetails>.unmodifiable([
        for (var i = 0; i < size; i++)
          travelers[i].copyWith(isLead: i == index),
      ]),
    );
  }

  /// Re-seats the lead on the first traveller when a resize or edit left the
  /// party with none — never with two.
  TravelerParty _withLead() =>
      travelers.any((t) => t.isLead) ? this : withLead(0);

  bool get isComplete => travelers.every((t) => t.isComplete);

  /// Travellers younger than [minAge] on [when]. Empty when the tour has no
  /// age restriction, or when no birth date has been entered yet — an
  /// unanswered field is incomplete, not underage.
  List<int> underageIndexes(int? minAge, DateTime when) {
    if (minAge == null) return const [];
    return [
      for (var i = 0; i < size; i++)
        if ((travelers[i].ageOn(when) ?? minAge) < minAge) i,
    ];
  }
}
