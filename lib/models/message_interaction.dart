import 'enums.dart';

/// One person's appearance in a choice's respondent preview: who, and when.
///
/// The name is a SNAPSHOT taken when they answered, not a live lookup, exactly
/// as [MessageMention] snapshots a handle beside its id. Three places have no
/// roster to resolve against — history containing someone who has since left
/// the room, a cold boot off the disk cache, and the thread overlay — and a
/// card that needed one would render nameless faces in all three.
class InteractionRespondent {
  const InteractionRespondent({
    required this.userId,
    required this.name,
    required this.at,
  });

  final String userId;
  final String name;
  final DateTime at;

  factory InteractionRespondent.fromJson(Map<String, dynamic> j) =>
      InteractionRespondent(
        userId: (j['userId']).toString(),
        name: (j['name'] ?? '') as String,
        at: DateTime.fromMillisecondsSinceEpoch(
          (j['at'] as num?)?.toInt() ?? 0,
        ),
      );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'at': at.millisecondsSinceEpoch,
  };
}

/// One answerable thing: a poll option, a checklist item, or an RSVP button.
///
/// [count] is the full tally; [respondents] is only the first few, capped
/// server-side at `RESPONDENT_PREVIEW_CAP`. A card shows those faces and then
/// "+N" from the difference — so `count - respondents.length` is meaningful and
/// `respondents.length` alone never is.
///
/// [respondents] is EMPTY on an anonymous poll, and that is not a load failure:
/// the server never wrote the names, so there is nothing to wait for. Read
/// [MessageInteraction.anonymous] to tell the two apart — a card that inferred
/// "still loading" from an empty list would spin forever on exactly the poll
/// where it matters.
class InteractionChoice {
  const InteractionChoice({
    required this.id,
    required this.label,
    required this.count,
    this.respondents = const [],
  });

  /// A stable token, not a position. A checklist grows items, and a tick keyed
  /// by index would move to a different task when one was inserted above it.
  final String id;
  final String label;
  final int count;
  final List<InteractionRespondent> respondents;

  /// How many respondents this choice has that [respondents] does not name.
  /// Always zero on an anonymous poll, where the list is empty by design and
  /// the count is not a shortfall.
  int get hiddenCount =>
      respondents.isEmpty ? 0 : (count - respondents.length).clamp(0, count);

  factory InteractionChoice.fromJson(Map<String, dynamic> j) =>
      InteractionChoice(
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? '') as String,
        count: (j['count'] as num?)?.toInt() ?? 0,
        respondents: ((j['respondents'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (e) => InteractionRespondent.fromJson(e.cast<String, dynamic>()),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'count': count,
    if (respondents.isNotEmpty)
      'respondents': [for (final r in respondents) r.toJson()],
  };

  InteractionChoice copyWith({
    int? count,
    List<InteractionRespondent>? respondents,
  }) => InteractionChoice(
    id: id,
    label: label,
    count: count ?? this.count,
    respondents: respondents ?? this.respondents,
  );
}

/// The body of a poll, checklist or event — everything the message row does not
/// carry.
///
/// ## Why this is not on [ChatMessage]
///
/// Because a vote must not rebuild the transcript. `messages:list` is a live
/// subscription that hands every row it reads to every member of the room, so
/// anything it touches refires for everybody on every change. Tallies move far
/// too often for that. They arrive instead on `interactions:listForRoom`, a
/// second small subscription whose payload is a handful of rows — see the
/// header on `backend/convex/schema.ts:messageInteractions`.
///
/// The consequence to keep in mind when rendering: a message and its
/// interaction land INDEPENDENTLY, and the message usually lands first. Every
/// card here has to have a state for "the prompt is known, the choices are
/// not", which is what [ChatMessage.content] is for — it holds the question,
/// so a poll with no body yet still says what it asked.
class MessageInteraction {
  const MessageInteraction({
    required this.messageId,
    required this.kind,
    required this.createdBy,
    required this.createdAt,
    required this.choices,
    required this.respondentCount,
    this.myChoiceIds = const [],
    this.multiple = false,
    this.anonymous = false,
    this.quiz = false,
    this.correctChoiceId,
    this.explanation,
    this.othersMayCheck = true,
    this.othersMayAdd = true,
    this.startsAt,
    this.endsAt,
    this.place,
    this.closedAt,
    this.closedBy,
    this.pendingChoiceIds = const {},
    this.pendingSelectedChoiceIds,
  });

  final String messageId;

  /// Which card to draw. Mirrors the message's own [MessageType], and is
  /// carried here as well so a card can be built from this object alone — the
  /// respondents sheet and the optimistic paths both hold one without a
  /// message beside it.
  final MessageType kind;
  final String createdBy;
  final DateTime createdAt;
  final List<InteractionChoice> choices;

  /// Distinct people who answered at all. NOT the sum of the choice counts,
  /// which double-counts a [multiple] poll's voters — "12 voted" is what a
  /// footer says, and it is not "19 votes".
  final int respondentCount;

  /// What this reader picked. Their own answers, so anonymity never withholds
  /// it — a poll that hid your vote from you would just be broken.
  final List<String> myChoiceIds;

  /// The intended selection while a write is running. A subscription can
  /// acknowledge the same answer before the mutation returns; keeping this
  /// snapshot prevents that acknowledgement from toggling the control twice.
  final Set<String>? pendingSelectedChoiceIds;

  final bool multiple;
  final bool anonymous;
  final bool quiz;

  /// Which option is right, on a quiz — and null until this reader has answered
  /// or the poll is closed, because the server withholds it until then. Null is
  /// therefore "not yet due", never "no answer": a quiz always has one.
  final String? correctChoiceId;
  final String? explanation;

  final bool othersMayCheck;
  final bool othersMayAdd;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? place;

  final DateTime? closedAt;
  final String? closedBy;

  /// Choices this device has just tapped and is still waiting on the server
  /// for.
  ///
  /// Held apart from [myChoiceIds] rather than folded into it, because the two
  /// mean different things to the card: a confirmed answer draws a filled
  /// control, and a pending one draws the same control with the tap
  /// acknowledged but the tally NOT yet moved. Merging them would make a
  /// dropped mutation indistinguishable from a counted vote — the bar would
  /// grow, then shrink again when the real state arrived, which is the one
  /// thing an optimistic update must never do.
  ///
  /// Local-only: never serialized, and cleared when the write completes.
  final Set<String> pendingChoiceIds;

  /// Paint only the new selection while a single-answer replacement is pending.
  /// The counts remain the server's confirmed counts.
  bool choiceSelected(InteractionChoice choice) {
    if (pendingChoiceIds.isNotEmpty && pendingSelectedChoiceIds != null) {
      return pendingSelectedChoiceIds!.contains(choice.id);
    }
    final held = kind == MessageType.checklist
        ? choice.count > 0
        : myChoiceIds.contains(choice.id);
    if (pendingChoiceIds.isEmpty) return held;
    if (kind != MessageType.checklist && !multiple) {
      final pending = pendingChoiceIds.last;
      return choice.id == pending && !myChoiceIds.contains(pending);
    }
    return pendingChoiceIds.contains(choice.id) ? !held : held;
  }

  bool get isClosed => closedAt != null;

  /// Whether this reader has answered. What reveals a quiz's answer, and what
  /// the poll footer switches on.
  bool get hasAnswered => myChoiceIds.isNotEmpty;

  /// A checklist's progress, as done and total. Meaningless on the other two
  /// kinds and not called there — a poll's "progress" is its tally.
  int get doneCount => choices.where((c) => c.count > 0).length;

  /// The largest tally any choice holds. What a poll's bars are scaled
  /// against, and what decides which row draws as the leader.
  ///
  /// Deliberately the MAX and not [respondentCount]: on a [multiple] poll the
  /// counts sum past the number of voters, so scaling by the voter count would
  /// draw bars past the end of the card.
  int get topCount => choices.isEmpty
      ? 0
      : choices.map((c) => c.count).reduce((a, b) => a > b ? a : b);

  /// This choice's share of the vote, 0..1, for the bar and the percentage.
  ///
  /// Denominated in [respondentCount] rather than the sum of counts, so a
  /// single-answer poll's percentages add to 100 and a [multiple] poll's read
  /// as "how many of the voters picked this" — which is the question a
  /// multiple-choice result is actually answering. Returns 0 rather than
  /// dividing by zero on a poll nobody has answered.
  double fractionOf(InteractionChoice choice) =>
      respondentCount == 0 ? 0 : choice.count / respondentCount;

  factory MessageInteraction.fromJson(Map<String, dynamic> j) {
    DateTime? at(String key) {
      final raw = j[key];
      return raw is num
          ? DateTime.fromMillisecondsSinceEpoch(raw.toInt())
          : null;
    }

    return MessageInteraction(
      messageId: (j['messageId']).toString(),
      kind: MessageTypeWire.parse(j['kind'] as String?),
      createdBy: (j['createdBy'] ?? '').toString(),
      createdAt: at('createdAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
      choices: ((j['choices'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => InteractionChoice.fromJson(e.cast<String, dynamic>()))
          .toList(),
      respondentCount: (j['respondentCount'] as num?)?.toInt() ?? 0,
      myChoiceIds: ((j['myChoiceIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      multiple: j['multiple'] == true,
      anonymous: j['anonymous'] == true,
      quiz: j['quiz'] == true,
      correctChoiceId: j['correctChoiceId'] as String?,
      explanation: j['explanation'] as String?,
      // `!= false`, not `== true`. Both flags default ON and the server writes
      // them only when the author turned one OFF, so an absent field means
      // "shared" — which is also what a row written before either flag existed
      // has to mean.
      othersMayCheck: j['othersMayCheck'] != false,
      othersMayAdd: j['othersMayAdd'] != false,
      startsAt: at('startsAt'),
      endsAt: at('endsAt'),
      place: j['place'] as String?,
      closedAt: at('closedAt'),
      closedBy: (j['closedBy'] as Object?)?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'kind': kind.wire,
    'createdBy': createdBy,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'choices': [for (final c in choices) c.toJson()],
    'respondentCount': respondentCount,
    if (myChoiceIds.isNotEmpty) 'myChoiceIds': myChoiceIds,
    if (multiple) 'multiple': true,
    if (anonymous) 'anonymous': true,
    if (quiz) 'quiz': true,
    if (correctChoiceId != null) 'correctChoiceId': correctChoiceId,
    if (explanation != null) 'explanation': explanation,
    if (!othersMayCheck) 'othersMayCheck': false,
    if (!othersMayAdd) 'othersMayAdd': false,
    if (startsAt != null) 'startsAt': startsAt!.millisecondsSinceEpoch,
    if (endsAt != null) 'endsAt': endsAt!.millisecondsSinceEpoch,
    if (place != null) 'place': place,
    if (closedAt != null) 'closedAt': closedAt!.millisecondsSinceEpoch,
    if (closedBy != null) 'closedBy': closedBy,
    // `pendingChoiceIds` is deliberately absent: it describes an in-flight
    // mutation on THIS device, and a cache that restored one would show a
    // tap that no longer has a request behind it.
  };

  MessageInteraction copyWith({
    List<InteractionChoice>? choices,
    int? respondentCount,
    List<String>? myChoiceIds,
    Set<String>? pendingChoiceIds,
    Set<String>? pendingSelectedChoiceIds,
    DateTime? closedAt,
    String? closedBy,
  }) => MessageInteraction(
    messageId: messageId,
    kind: kind,
    createdBy: createdBy,
    createdAt: createdAt,
    choices: choices ?? this.choices,
    respondentCount: respondentCount ?? this.respondentCount,
    myChoiceIds: myChoiceIds ?? this.myChoiceIds,
    multiple: multiple,
    anonymous: anonymous,
    quiz: quiz,
    correctChoiceId: correctChoiceId,
    explanation: explanation,
    othersMayCheck: othersMayCheck,
    othersMayAdd: othersMayAdd,
    startsAt: startsAt,
    endsAt: endsAt,
    place: place,
    closedAt: closedAt ?? this.closedAt,
    closedBy: closedBy ?? this.closedBy,
    pendingChoiceIds: pendingChoiceIds ?? this.pendingChoiceIds,
    pendingSelectedChoiceIds: pendingChoiceIds?.isEmpty == true
        ? null
        : pendingSelectedChoiceIds ?? this.pendingSelectedChoiceIds,
  );
}

/// One row of the "who answered what" sheet.
///
/// Flat rather than grouped by choice, because the sheet groups it itself and
/// the wire shape should not decide how it is displayed. Names are the same
/// snapshots [InteractionRespondent] carries, for the same reason.
class InteractionRespondentDetail {
  const InteractionRespondentDetail({
    required this.userId,
    required this.name,
    required this.choiceId,
    required this.at,
  });

  final String userId;
  final String name;
  final String choiceId;
  final DateTime at;

  factory InteractionRespondentDetail.fromJson(Map<String, dynamic> j) =>
      InteractionRespondentDetail(
        userId: (j['userId']).toString(),
        name: (j['name'] ?? '') as String,
        choiceId: (j['choiceId'] ?? '').toString(),
        at: DateTime.fromMillisecondsSinceEpoch(
          (j['at'] as num?)?.toInt() ?? 0,
        ),
      );
}
