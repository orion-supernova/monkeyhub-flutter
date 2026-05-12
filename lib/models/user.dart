class User {
  User({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarSeed,
    required this.isPublic,
    this.bio,
  });

  final String id;
  String name;
  String handle;
  final int avatarSeed;
  bool isPublic;
  String? bio;
}
