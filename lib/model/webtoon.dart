String normalizeGenre(String value) {
  return value.trim().toLowerCase();
}

class Webtoon {
  final String id;
  final String title;
  final String genre;
  final String rating;
  final String image;
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

  factory Webtoon.fromJson(Map<String, dynamic> json) {
    return Webtoon(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      genre: json['genre'] ?? '',
      rating: json['rating'] ?? '0.0',
      image: json['image'] ?? '',
      synopsis: json['synopsis'] ?? '',
      episodes: List<String>.from(json['episodes'] ?? []),
    );
  }
}

final List<Webtoon> dummyWebtoons = [
  Webtoon(
    id: '1',
    title: 'The Secret of Angel',
    genre: 'Romance',
    rating: '9.8',
    image: 'the_secret_of_angel.jpeg',
    synopsis:
        'Jugyeong yang tidak percaya diri dengan wajahnya, bertransformasi menjadi dewi sekolah berkat kemampuan makeup-nya.',
    episodes: ['Episode 1', 'Episode 2', 'Episode 3', 'Episode 4'],
  ),
  Webtoon(
    id: '2',
    title: 'Tower of God',
    genre: 'Fantasy',
    rating: '9.9',
    image: 'tower_of_god.jpeg',
    synopsis:
        'Mencapai puncak menara akan mengabulkan segala keinginanmu. Ikuti petualangan Bam mengejar takdirnya.',
    episodes: ['Eps 1: Lantai Pertama', 'Eps 2: Ujian', 'Eps 3: Mahkota'],
  ),
  Webtoon(
    id: '3',
    title: 'Solo Leveling',
    genre: 'Fantasy',
    rating: '9.9',
    image: 'solo_leveling.jpeg',
    synopsis:
        'Hunter terlemah sedunia, Sung Jin-Woo, mendapatkan sistem misterius yang membuatnya bisa naik level tanpa batas.',
    episodes: [
      'Eps 1: Hunter Terlemah',
      'Eps 2: Double Dungeon',
      'Eps 3: Kebangkitan',
    ],
  ),
];
