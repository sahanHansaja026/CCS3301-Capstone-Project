import 'package:birds_app/global_language.dart';
import 'package:birds_app/services/translation_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

class BirdPage extends StatefulWidget {
  final String birdId;

  const BirdPage({super.key, required this.birdId});

  @override
  State<BirdPage> createState() => _BirdPageState();
}

class _BirdPageState extends State<BirdPage> {
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();

    _player.onPlayerComplete.listen((event) {
      setState(() => isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> playSound(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
    setState(() => isPlaying = true);
  }

  Future<void> stopSound() async {
    await _player.stop();
    setState(() => isPlaying = false);
  }

  Future<String> t(String text) async {
    return await TranslationService.translate(
      text: text,
      targetLang: currentLanguage.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('birds')
          .doc(widget.birdId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bird = snapshot.data!.data() as Map<String, dynamic>;

        final soundUrl = bird['sound_url'];
        final List habitats = bird['habitats'] ?? [];
        final List diet = bird['diet'] ?? [];
        final List funFacts = bird['fun_facts'] ?? [];

        return Scaffold(
          backgroundColor: Colors.white,

          // ================= APP BAR =================
          appBar: AppBar(
            backgroundColor: const Color(0xFFDEBAFE),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 25, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(
              bird['name'] ?? "Bird Details",
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inriaSans(
                fontSize: 25,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),

          // ================= BODY =================
          body: SingleChildScrollView(
            child: Column(
              children: [
                // ================= IMAGE =================
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 150,
                      color: const Color(0xFFDEBAFE),
                    ),
                    Positioned(
                      top: 30,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          (bird['images'] != null && bird['images'].isNotEmpty)
                              ? bird['images'][0]
                              : "https://via.placeholder.com/300",
                          width: 300,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 130),

                // ================= SOUND =================
                if (soundUrl != null && soundUrl != "")
                  ElevatedButton.icon(
                    onPressed: () {
                      isPlaying ? stopSound() : playSound(soundUrl.toString());
                    },
                    icon: Icon(
                      isPlaying ? Icons.volume_up : Icons.volume_off,
                      color: Colors.black,
                    ),
                    label: Text(
                      isPlaying ? "Stop Sound" : "Play Sound",
                      style: GoogleFonts.inriaSans(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDEBAFE),
                    ),
                  ),

                const SizedBox(height: 30),

                // ================= DESCRIPTION =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEBAFE),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    padding: const EdgeInsets.all(12),
                    child: FutureBuilder<String>(
                      future: t(bird['long_description'] ?? ""),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return Text(snapshot.data!);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ================= HABITATS + DIET =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBox("Live in", habitats),
                      const SizedBox(width: 10),
                      _buildBox("Diet", diet),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ================= FUN FACTS =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEBAFE),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String>(
                          future: t("Fun Facts"),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(
                                height: 12,
                                child: LinearProgressIndicator(),
                              );
                            }

                            return Text(
                              snapshot.data!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        funFacts.isEmpty
                            ? const Text("No fun facts")
                            : Column(
                                children: funFacts.map((e) {
                                  return FutureBuilder<String>(
                                    future: t(e.toString()),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const LinearProgressIndicator();
                                      }
                                      return Text("• ${snapshot.data!}");
                                    },
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= REUSABLE BOX =================
  Widget _buildBox(String title, List items) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 136, 199, 152),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ TRANSLATED TITLE
            FutureBuilder<String>(
              future: t(title),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                return Text(
                  snapshot.data!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),

            const SizedBox(height: 10),

            // ✅ TRANSLATED ITEMS
            items.isEmpty
                ? const Text("No data")
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((e) {
                      return FutureBuilder<String>(
                        future: t(e.toString()),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }

                          return Text("• ${snapshot.data!}");
                        },
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
