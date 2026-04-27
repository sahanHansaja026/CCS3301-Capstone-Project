import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class UploadSound extends StatefulWidget {
  const UploadSound({super.key});

  @override
  State<UploadSound> createState() => _UploadSoundState();
}

class _UploadSoundState extends State<UploadSound> {
  File? selectedFile;
  String resultMessage = "";
  bool isLoading = false;
  double progress = 0.0;

  Future<void> pickAudio() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.audio);

    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
        resultMessage = "File selected successfully ✅";
      });
    }
  }

  void predictSound() async {
    if (selectedFile == null) {
      setState(() {
        resultMessage = "Please upload a sound first ⚠️";
      });
      return;
    }

    setState(() {
      isLoading = true;
      progress = 0.0;
      resultMessage = "Processing audio... 🎧";
    });

    // simulate processing
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        progress = i / 10;
      });
    }

    // 🔥 fake model output (random example)
    List<double> output = [0.2, 0.7, 0.1];

    int maxIndex = 0;
    double maxVal = output[0];

    for (int i = 1; i < output.length; i++) {
      if (output[i] > maxVal) {
        maxVal = output[i];
        maxIndex = i;
      }
    }

    final List<String> labels = ["crow", "peacock", "rooster"];

    setState(() {
      isLoading = false;
      resultMessage = "Bird detected: ${labels[maxIndex]} 🐦";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Upload Sound")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 80, color: Colors.green),

            const SizedBox(height: 20),

            Text(
              selectedFile != null
                  ? selectedFile!.path.split('/').last
                  : "No file selected",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: pickAudio,
              child: const Text("Upload Audio"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: isLoading ? null : predictSound,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Predict Bird"),
            ),

            const SizedBox(height: 20),

            // 🔥 Progress Bar
            if (isLoading) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 10),
              Text("${(progress * 100).toInt()}%"),
            ],

            const SizedBox(height: 20),

            Text(
              resultMessage,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
