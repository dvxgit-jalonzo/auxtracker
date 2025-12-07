class Auxiliary {
  final int id;
  final String main;
  final String sub;

  Auxiliary({required this.id, required this.main, required this.sub});

  factory Auxiliary.fromJson(Map<String, dynamic> json) {
    return Auxiliary(id: json['id'], main: json['main'], sub: json['sub']);
  }
}
