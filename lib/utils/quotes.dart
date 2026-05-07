import 'dart:math';

class Quotes {
  static const List<String> cricketQuotes = [
    "“Cricket is not just a game, it's an emotion.”",
    "“খেলাধুলায় বাড়ে বল, মাদক ছেড়ে খেলতে চল।”",
    "“Winning isn't everything, but wanting to win is.”",
    "“Success is where preparation and opportunity meet.”",
    "“Don't let yesterday take up too much of today.”",
    "“Your talent determines what you can do. Your motivation determines how much you are willing to do.”",
    "“The only way to do great work is to love what you do.”",
    "“Believe you can and you're halfway there.”",
    "“Don't watch the clock; do what it does. Keep going.”",
    "“Believe in yourself and all that you are.”",
  ];

  static String getRandomQuote() {
    return cricketQuotes[Random().nextInt(cricketQuotes.length)];
  }
}
