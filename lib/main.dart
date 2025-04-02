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
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
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
                fontWeight: FontWeight.bold,
              ),
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
  String _selectedModel = 'YOLO11n';
  final List<String> _modelOptions = [
    'YOLO11n',
    'YOLO11s',
    'YOLO11m',
    'YOLO11l',
    'YOLO11x'
  ];
  WebSocketChannel? _channel;
  final String backendIp = '192.168.1.101';

  String fixUrl(String? url) => url?.replaceAll("localhost", backendIp) ?? '';

  Future<void> _pickMedia(bool isVideo) async {
    final picked = isVideo
        ? await ImagePicker().pickVideo(source: ImageSource.gallery)
        : await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _file = File(picked.path);
        _isVideo = isVideo;
        _selectedModel = 'YOLO11n';
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
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
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
      appBar: AppBar(title: Text('Detector de Parasitas'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard(),
            SizedBox(height: 12),
            _buildUploadButtons(),
            if (_file != null) ...[
              SizedBox(height: 10),
              Text(
                'Selecionado: ${_file!.path.split("/").last}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 8),
              _buildModelDropdown(),
              SizedBox(height: 8),
              _buildConfidenceSlider(),
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.cloud_upload),
                label: Text('Enviar'),
                onPressed: _uploadFile,
              ),
            ],
            if (_loading) _buildProgressSection(),
            if (_processedUrl != null) _buildResultSection(),
            if (_detectionsCount.isNotEmpty) _buildDetectionsList(),
            if (_csvUrl != null || _pdfUrl != null) _buildReportsButtons(),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('🧠 Nota:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'Modelos maiores oferecem mais precisão, mas exigem mais recursos. Para vídeos, somente YOLO11n está disponível.',
            ),
            Divider(),
            Text('⚠️ Aviso:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
                'Este app pode cometer erros e não substitui o diagnóstico de um profissional laboratorial.'),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButtons() {
    return Row(
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
    );
  }

  Widget _buildModelDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modelo YOLOv11:'),
        DropdownButton<String>(
          value: _selectedModel,
          isExpanded: true,
          items: _modelOptions.map((String model) {
            final isEnabled = !_isVideo || model == 'YOLO11n';
            return DropdownMenuItem<String>(
              value: model,
              enabled: isEnabled,
              child: Text(
                model + (isEnabled ? '' : ' (indisponível para vídeo)'),
                style: TextStyle(
                  color: isEnabled ? null : Colors.grey,
                  fontStyle: isEnabled ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) =>
              setState(() => _selectedModel = newValue!),
        ),
      ],
    );
  }

  Widget _buildConfidenceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confiança mínima: ${_threshold.toStringAsFixed(2)}'),
        Slider(
          value: _threshold,
          min: 0,
          max: 1,
          divisions: 100,
          label: _threshold.toStringAsFixed(2),
          onChanged: (value) => setState(() => _threshold = value),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        SizedBox(height: 20),
        Text(_isVideo ? 'Processando vídeo...' : 'Processando imagem...'),
        SizedBox(height: 10),
        LinearProgressIndicator(value: _progress / 100),
        SizedBox(height: 10),
        Text('$_progress%'),
      ],
    );
  }

  Widget _buildResultSection() {
    return Column(
      children: [
        SizedBox(height: 20),
        Text('Arquivo Processado:'),
        _isVideo
            ? ElevatedButton.icon(
                icon: Icon(Icons.play_circle_outline),
                label: Text('Assistir vídeo'),
                onPressed: () => _abrirUrl(_processedUrl!),
              )
            : GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: Image.network(_processedUrl!),
                    ),
                  ),
                ),
                child: Image.network(_processedUrl!, height: 200),
              ),
        SizedBox(height: 10),
        ElevatedButton.icon(
          icon: Icon(Icons.download),
          label: Text('Baixar arquivo processado'),
          onPressed: () => _abrirUrl(_processedUrl!),
        ),
      ],
    );
  }

  Widget _buildDetectionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text('Ovos Detectados:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ..._detectionsCount.entries.map((entry) => ListTile(
              leading: Icon(Icons.bug_report),
              title: Text(entry.key),
              trailing: Text(entry.value.toString()),
            )),
      ],
    );
  }

  Widget _buildReportsButtons() {
    return Column(
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
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Desenvolvido por Halan Germano Bacca - PPGINFOS - UFSC - 2025',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _abrirUrl('https://github.com/halangbacca'),
                icon: Icon(Icons.code),
                label: Text('GitHub'),
              ),
              TextButton.icon(
                onPressed: () =>
                    _abrirUrl('https://www.linkedin.com/in/halanbacca'),
                icon: Icon(Icons.business),
                label: Text('LinkedIn'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
