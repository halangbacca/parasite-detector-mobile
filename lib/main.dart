import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
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
        MaterialPageRoute(builder: (context) => UploadScreen()),
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

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _file;
  bool _isVideo = false;
  double _threshold = 0.5;
  bool _loading = false;
  int _progress = 0;
  String? _processedUrl;
  Map<String, int> _detectionsCount = {};
  String? _csvUrl;
  String? _pdfUrl;
  String _selectedModel = 'yolov11n';
  final List<String> _modelOptions = [
    'yolov11n',
    'yolov11s',
    'yolov11m',
    'yolov11l',
    'yolov11x'
  ];
  WebSocketChannel? _channel;
  final String backendIp = '192.168.1.101';

  String fixUrl(String? url) {
    if (url == null) return '';
    return url.replaceAll("localhost", backendIp);
  }

  Future<void> _pickMedia(bool isVideo) async {
    final picked = isVideo
        ? await ImagePicker().pickVideo(source: ImageSource.gallery)
        : await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _file = File(picked.path);
        _isVideo = isVideo;
        _selectedModel = 'yolov11n';
        _processedUrl = null;
        _detectionsCount.clear();
        _csvUrl = null;
        _pdfUrl = null;
        _progress = 0;
      });
    }
  }

  void _iniciarWebSocket() {
    _channel = WebSocketChannel.connect(
        Uri.parse('ws://$backendIp:8000/ws/progresso'));
    _channel!.stream.listen((message) {
      setState(() {
        _progress = int.tryParse(message) ?? 0;
      });
    });
  }

  void _fecharWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _uploadFile() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione um arquivo primeiro!')),
      );
      return;
    }

    setState(() => _loading = true);
    _iniciarWebSocket();

    try {
      String url =
          'http://$backendIp:8000/predict/?threshold=$_threshold&model=$_selectedModel';
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_file!.path),
      });

      Response response = await Dio().post(url, data: formData);

      if (response.statusCode == 200) {
        setState(() {
          _detectionsCount =
              Map<String, int>.from(response.data['detections_count']);
          _processedUrl = fixUrl(response.data['download_url']);
          _csvUrl = fixUrl(response.data['csv_url']);
          _pdfUrl = fixUrl(response.data['pdf_url']);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar o arquivo.')),
      );
    } finally {
      _fecharWebSocket();
      setState(() => _loading = false);
    }
  }

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o link: $url')),
      );
    }
  }

  @override
  void dispose() {
    _fecharWebSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detector de Parasitas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.image),
                  label: Text('Imagem'),
                  onPressed: () => _pickMedia(false),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.videocam),
                  label: Text('Vídeo'),
                  onPressed: () => _pickMedia(true),
                ),
              ],
            ),
            SizedBox(height: 10),
            _file != null
                ? Text('Arquivo selecionado: ${_file!.path.split("/").last}')
                : Container(),
            SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedModel,
              items: _modelOptions.map((String model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: Text(model),
                  enabled: _isVideo ? model == 'yolov11n' : true,
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() => _selectedModel = newValue!);
              },
            ),
            Text('Confiança mínima: ${_threshold.toStringAsFixed(2)}'),
            Slider(
              value: _threshold,
              min: 0,
              max: 1,
              divisions: 100,
              label: _threshold.toStringAsFixed(2),
              onChanged: (value) => setState(() => _threshold = value),
            ),
            ElevatedButton(
              onPressed: _uploadFile,
              child: Text('Enviar'),
            ),
            if (_loading) ...[
              SizedBox(height: 20),
              Text(_isVideo ? 'Processando vídeo...' : 'Processando imagem...'),
              SizedBox(height: 10),
              LinearProgressIndicator(value: _progress / 100),
              SizedBox(height: 10),
              Text('$_progress%')
            ],
            if (_processedUrl != null)
              Column(
                children: [
                  SizedBox(height: 20),
                  Text('Arquivo Processado:'),
                  _isVideo
                      ? ElevatedButton.icon(
                          icon: Icon(Icons.play_circle_outline),
                          label: Text('Assistir vídeo'),
                          onPressed: () => _abrirUrl(_processedUrl!),
                        )
                      : Image.network(_processedUrl!, height: 200),
                ],
              ),
            if (_detectionsCount.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text('Ovos Detectados:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ..._detectionsCount.entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('${entry.key}: ${entry.value}',
                            style: TextStyle(fontSize: 16)),
                      )),
                ],
              ),
            if (_csvUrl != null || _pdfUrl != null)
              Column(
                children: [
                  SizedBox(height: 20),
                  Text('Relatórios:'),
                  if (_csvUrl != null)
                    ElevatedButton.icon(
                      icon: Icon(Icons.table_chart),
                      label: Text('Baixar CSV'),
                      onPressed: () => _abrirUrl(_csvUrl!),
                    ),
                  if (_pdfUrl != null)
                    ElevatedButton.icon(
                      icon: Icon(Icons.picture_as_pdf),
                      label: Text('Baixar PDF'),
                      onPressed: () => _abrirUrl(_pdfUrl!),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
