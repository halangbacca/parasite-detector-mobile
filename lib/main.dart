import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ImageUploadScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.biotech_outlined, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Detector de Parasitas',
              style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageUploadScreen extends StatefulWidget {
  @override
  _ImageUploadScreenState createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  File? _image;
  double _threshold = 0.5;
  bool _loading = false;
  String? _processedImage;
  Map<String, int> _detectionsCount = {};

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _processedImage = null;
        _detectionsCount.clear();
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione uma imagem primeiro!')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      String url = 'http://192.168.1.101:8000/predict/?threshold=$_threshold';
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_image!.path),
      });

      Response response = await Dio().post(url, data: formData);

      if (response.statusCode == 200) {
        setState(() {
          _detectionsCount =
              Map<String, int>.from(response.data['detections_count']);
          String imageHex = response.data['image'];
          Uint8List bytes = Uint8List.fromList(List<int>.generate(
              imageHex.length ~/ 2,
              (i) =>
                  int.parse(imageHex.substring(i * 2, i * 2 + 2), radix: 16)));
          _processedImage = 'data:image/jpeg;base64,' + base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar a imagem.')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _shareImage() async {
    if (_processedImage == null) return;

    final bytes = base64Decode(_processedImage!.split(',')[1]);
    final tempDir = await getTemporaryDirectory();
    final file =
        await File('${tempDir.path}/processed_image.jpg').writeAsBytes(bytes);

    Share.shareXFiles([XFile(file.path)], text: 'Imagem processada!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Processamento de Imagem')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.image),
                    label: Text('Galeria'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.camera),
                    label: Text('Câmera'),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ],
              ),
              SizedBox(height: 10),
              _image != null ? Image.file(_image!, height: 200) : Container(),
              SizedBox(height: 10),
              Text('Confiança mínima: ${_threshold.toStringAsFixed(2)}'),
              Slider(
                value: _threshold,
                min: 0,
                max: 1,
                divisions: 100,
                label: _threshold.toStringAsFixed(2),
                onChanged: (value) {
                  setState(() {
                    _threshold = value;
                  });
                },
              ),
              ElevatedButton(
                onPressed: _uploadImage,
                child: Text('Enviar'),
              ),
              if (_loading) CircularProgressIndicator(),
              if (_processedImage != null)
                Column(
                  children: [
                    SizedBox(height: 20),
                    Text('Imagem Processada:'),
                    Image.memory(base64Decode(_processedImage!.split(',')[1]),
                        height: 200),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: Icon(Icons.share),
                      label: Text('Compartilhar'),
                      onPressed: _shareImage,
                    ),
                    if (_detectionsCount.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20),
                          Text('Ovos Detectados:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          ..._detectionsCount.entries.map((entry) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text('${entry.key}: ${entry.value}',
                                    style: TextStyle(fontSize: 16)),
                              )),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
