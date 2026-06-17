String normalizeGenre(String value) {
  return value.trim().toLowerCase();
}

class Webtoon {
  final String id;
  final String title;
  final String genre;
  final String rating;
  final String image; // Bisa berisi URL atau Base64 String
  final String synopsis;
  final List<String> episodes;

  Webtoon({
    required this.id,
    required this.title,
    required this.genre,
    required this.rating,
    required this.image,
    required this.synopsis,
    required this.episodes,
  });

  // Mengubah Map/JSON menjadi Objek Webtoon
  factory Webtoon.fromJson(Map<String, dynamic> json) {
    return Webtoon(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      genre: json['genre'] ?? '',
      rating: json['rating']?.toString() ?? '0.0', // Memastikan aman jika inputnya double/num
      image: json['image'] ?? '',
      synopsis: json['synopsis'] ?? '',
      episodes: json['episodes'] != null 
          ? List<String>.from(json['episodes']) 
          : [],
    );
  }

  // Mengubah Objek Webtoon kembali ke Map untuk disimpan ke SharedPreferences / Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'genre': genre,
      'rating': rating,
      'image': image,
      'synopsis': synopsis,
      'episodes': episodes,
    };
  }
}