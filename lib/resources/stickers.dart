import 'package:flutter/material.dart';

class StickerData {
  final String id;
  final String emoji;
  final String? lottieAsset;
  final Color? backgroundColor;
  final double size;

  const StickerData({
    required this.id,
    required this.emoji,
    this.lottieAsset,
    this.backgroundColor,
    this.size = 48,
  });

  bool get hasAnimation => lottieAsset != null;
}

class StickerPack {
  final String name;
  final String icon;
  final List<StickerData> stickers;

  const StickerPack({
    required this.name,
    required this.icon,
    required this.stickers,
  });
}

class StickerService {
  static const List<StickerPack> packs = [
    StickerPack(
      name: 'Reactions',
      icon: '❤️',
      stickers: [
        StickerData(
          id: 'heart',
          emoji: '❤️',
          lottieAsset: 'assets/stickers/heart.json',
          backgroundColor: Color(0xFFFF4757),
        ),
        StickerData(
          id: 'like',
          emoji: '👍',
          lottieAsset: 'assets/stickers/thumbs_up.json',
          backgroundColor: Color(0xFF5352ED),
        ),
        StickerData(
          id: 'fire',
          emoji: '🔥',
          lottieAsset: 'assets/stickers/fire.json',
          backgroundColor: Color(0xFFFF6B35),
        ),
        StickerData(
          id: 'star',
          emoji: '⭐',
          lottieAsset: 'assets/stickers/star.json',
          backgroundColor: Color(0xFFFFD700),
        ),
        StickerData(
          id: 'laugh',
          emoji: '😂',
          lottieAsset: 'assets/stickers/laughing.json',
          backgroundColor: Color(0xFFFFDD59),
        ),
        StickerData(
          id: 'wow',
          emoji: '😮',
          lottieAsset: 'assets/stickers/wow.json',
          backgroundColor: Color(0xFF7BED9F),
        ),
      ],
    ),
    StickerPack(
      name: 'Emoji',
      icon: '😀',
      stickers: [
        StickerData(id: 'smile', emoji: '😀'),
        StickerData(id: 'happy', emoji: '😃'),
        StickerData(id: 'love_eyes', emoji: '🥰'),
        StickerData(id: 'cool', emoji: '😎'),
        StickerData(id: 'sad', emoji: '😢'),
        StickerData(id: 'angry', emoji: '😡'),
        StickerData(id: 'kiss', emoji: '😘'),
        StickerData(id: 'sleepy', emoji: '😴'),
        StickerData(id: 'blush', emoji: '😊'),
        StickerData(id: 'surprise', emoji: '😱'),
        StickerData(id: 'cry', emoji: '😭'),
        StickerData(id: 'thinking', emoji: '🤔'),
      ],
    ),
    StickerPack(
      name: 'Hands',
      icon: '👋',
      stickers: [
        StickerData(id: 'wave', emoji: '👋'),
        StickerData(id: 'thumbsup', emoji: '👍'),
        StickerData(id: 'thumbsdown', emoji: '👎'),
        StickerData(id: 'clap', emoji: '👏'),
        StickerData(id: 'fist', emoji: '✊'),
        StickerData(id: 'ok_hand', emoji: '👌'),
        StickerData(id: 'rock', emoji: '🤘'),
        StickerData(id: 'point', emoji: '👉'),
        StickerData(id: 'pray', emoji: '🙏'),
        StickerData(id: 'hug', emoji: '🤗'),
        StickerData(id: 'shake', emoji: '🤝'),
      ],
    ),
    StickerPack(
      name: 'Love',
      icon: '💕',
      stickers: [
        StickerData(id: 'pink_heart', emoji: '💖'),
        StickerData(id: 'sparkling', emoji: '💗'),
        StickerData(id: 'growing_heart', emoji: '💕'),
        StickerData(id: 'heart_arrow', emoji: '💘'),
        StickerData(id: 'ribbon', emoji: '🎀'),
        StickerData(id: 'rose', emoji: '🌹'),
        StickerData(id: 'kiss', emoji: '💋'),
        StickerData(id: 'cupid', emoji: '💘'),
        StickerData(id: 'ring', emoji: '💍'),
        StickerData(id: 'couple', emoji: '👫'),
      ],
    ),
    StickerPack(
      name: 'Celebration',
      icon: '🎉',
      stickers: [
        StickerData(id: 'party', emoji: '🎉'),
        StickerData(id: 'confetti', emoji: '🎊'),
        StickerData(id: 'balloon', emoji: '🎈'),
        StickerData(id: 'cake', emoji: '🎂'),
        StickerData(id: 'gift', emoji: '🎁'),
        StickerData(id: 'trophy', emoji: '🏆'),
        StickerData(id: 'medal', emoji: '🏅'),
        StickerData(
          id: 'clapping',
          emoji: '👏',
          lottieAsset: 'assets/stickers/clapping.json',
          backgroundColor: Color(0xFFFFDD59),
        ),
        StickerData(id: 'fireworks', emoji: '🎆'),
        StickerData(id: 'sparkler', emoji: '🎇'),
      ],
    ),
    StickerPack(
      name: 'Fun',
      icon: '😎',
      stickers: [
        StickerData(id: 'ninja', emoji: '🥷'),
        StickerData(id: 'robot', emoji: '🤖'),
        StickerData(id: 'alien', emoji: '👽'),
        StickerData(id: 'ghost', emoji: '👻'),
        StickerData(id: 'skull', emoji: '💀'),
        StickerData(id: 'devil', emoji: '😈'),
        StickerData(id: 'angel', emoji: '👼'),
        StickerData(id: 'clown', emoji: '🤡'),
        StickerData(id: 'sunglasses', emoji: '😎'),
        StickerData(id: 'cat', emoji: '😺'),
        StickerData(id: 'poop', emoji: '💩'),
        StickerData(id: 'brain', emoji: '🧠'),
      ],
    ),
  ];

  static List<StickerData> get allStickers {
    return packs.expand((pack) => pack.stickers).toList();
  }
}

class WallpaperPreset {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isGradient;

  const WallpaperPreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    this.isGradient = true,
  });
}

class WallpaperService {
  static const List<WallpaperPreset> presets = [
    WallpaperPreset(
      id: 'default',
      name: 'Dark',
      primaryColor: Color(0xFF0A0A0A),
      secondaryColor: Color(0xFF1A1A1A),
    ),
    WallpaperPreset(
      id: 'blue',
      name: 'Ocean Blue',
      primaryColor: Color(0xFF0D1B2A),
      secondaryColor: Color(0xFF1B3A4B),
    ),
    WallpaperPreset(
      id: 'purple',
      name: 'Purple Night',
      primaryColor: Color(0xFF1A0A2E),
      secondaryColor: Color(0xFF2D1B4E),
    ),
    WallpaperPreset(
      id: 'green',
      name: 'Matrix',
      primaryColor: Color(0xFF001100),
      secondaryColor: Color(0xFF002200),
    ),
    WallpaperPreset(
      id: 'red',
      name: 'Sunset',
      primaryColor: Color(0xFF1A0A0A),
      secondaryColor: Color(0xFF2A1515),
    ),
    WallpaperPreset(
      id: 'teal',
      name: 'Teal Dream',
      primaryColor: Color(0xFF0A1A1A),
      secondaryColor: Color(0xFF153535),
    ),
    WallpaperPreset(
      id: 'orange',
      name: 'Warm Orange',
      primaryColor: Color(0xFF1A120A),
      secondaryColor: Color(0xFF2A1F15),
    ),
    WallpaperPreset(
      id: 'pink',
      name: 'Pink Night',
      primaryColor: Color(0xFF1A0A15),
      secondaryColor: Color(0xFF2A1525),
    ),
    WallpaperPreset(
      id: 'gradient1',
      name: 'Cyberpunk',
      primaryColor: Color(0xFF0F0F23),
      secondaryColor: Color(0xFF1A0A2E),
    ),
    WallpaperPreset(
      id: 'gradient2',
      name: 'Neon',
      primaryColor: Color(0xFF0A0A0A),
      secondaryColor: Color(0x3300FF9C),
    ),
    WallpaperPreset(
      id: 'solid1',
      name: 'Pure Black',
      primaryColor: Color(0xFF000000),
      secondaryColor: Color(0xFF000000),
      isGradient: false,
    ),
    WallpaperPreset(
      id: 'solid2',
      name: 'Dark Gray',
      primaryColor: Color(0xFF121212),
      secondaryColor: Color(0xFF121212),
      isGradient: false,
    ),
  ];

  static WallpaperPreset getById(String id) {
    return presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
  }
}
