import 'dart:math';

import 'package:flutter/material.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:word_generator/word_generator.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(EmbeddleApp());
}

double cosineDistance(List<double> vector1, List<double> vector2) {
  double upper = 0;
  double bottomA = 0;
  double bottomB = 0;
  int len = min(vector1.length, vector2.length);
  for (int i = 0; i < len; i++) {
    upper += vector1[i] * vector2[i];
    bottomA += vector1[i] * vector1[i];
    bottomB += vector2[i] * vector2[i];
  }
  double diviser = sqrt(bottomA) * sqrt(bottomB);
  return 1.0 - (diviser != 0 ? (upper / diviser) : 0);
}

class EmbeddleApp extends StatelessWidget {
  const EmbeddleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embeddle',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: MyHomePage(),
    );
  }
}

class Guess {
  final String value;
  final double distance;
  final List<double> embedding;

  Guess(this.value, this.distance, this.embedding);

  static Future<List<double>> getEmbedding(String valueToEmbed) async {
    final openai = OpenAIEmbeddings(
      apiKey: dotenv.env['API_KEY'],
      baseUrl: "https://api.together.xyz/v1",
      model: "togethercomputer/m2-bert-80M-2k-retrieval",
    );
    var result = await openai.embedQuery(valueToEmbed);
    return result.cast<double>();
  }

  static Future<Guess> create(String value, Guess target) async {
    var valueEmbedding = await getEmbedding(value);
    var distance = cosineDistance(valueEmbedding, target.embedding);
    return Guess(value, distance, valueEmbedding);
  }

  static bool isTarget(Guess guess) {
    // Futures in Flutter are weird, so we just take the distance
    return guess.distance == 0.0;
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final textController = TextEditingController();
  late final Future<Guess> target;
  var guesses = <Guess>[];
  Guess? lastGuess;

  @override
  void initState() {
    super.initState();
    target = initializeTarget();
  }

  Future<Guess> initializeTarget() async {
    String target = WordGenerator().randomNoun().toLowerCase();
    print("Target: $target"); // Remove, obviously
    return Guess(target, 0.0, await Guess.getEmbedding(target));
  }

  Future<void> addGuess(String value) async {
    var guess = await Guess.create(value.toLowerCase(), await target);
    setState(() {
      guesses.add(guess);
      guesses.sort((a, b) => a.distance.compareTo(b.distance));
      lastGuess = guess;
    });
  }

  bool alreadyGuessed(String value) {
    return guesses.any((element) => element.value == value);
  }

  String? validateInput(String? value) {
    if (value == null || value.isEmpty) {
      return "Please enter a value";
    }
    if (alreadyGuessed(value)) {
      return "You already guessed this value";
    }

    final regex = RegExp(r'^[a-zA-Z]+$');
    if (!regex.hasMatch(value)) {
      return "Please enter only alphabetic characters";
    }
    return null;
  }

  Color? getListItemColor(Guess guess) {
    return Color.lerp(
      Colors.green,
      Colors.red,
      guess.distance * 15,
    )?.withAlpha(Guess.isTarget(guess) ? 255 : 150);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Embeddle",
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        toolbarHeight: 40,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    "This is 'Embeddle'. Your task is to guess the word. Each guess gives you a distance to the word we are looking for. The closer you are, the better.",
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "Good Luck!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: "Enter your guess",
                  errorText: validateInput(textController.value.text),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.secondary,
                      width: 2.0,
                    ),
                  ),
                ),
                onSubmitted: (value) => {
                  if (validateInput(value) == null)
                    {addGuess(value), textController.clear()}
                },
              ),
            ),
            SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Guess",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "Distance",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: guesses.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    tileColor: getListItemColor(guesses[index]),
                    minTileHeight: 0,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(guesses[index].value),
                        Text(
                          guesses[index].distance.toStringAsFixed(4),
                          textAlign: TextAlign.right,
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
