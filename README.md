# 📱 Detector de Ovos - Aplicativo Mobile (Flutter)

Este é o aplicativo mobile do projeto de detecção de ovos de parasitas com **YOLOv11**, desenvolvido em **Flutter** para **Android** e **iOS**. O app permite tirar ou escolher uma imagem, enviar para o backend FastAPI, e visualizar os resultados com contagem e compartilhamento.

## 🚀 Funcionalidades

- 📷 Captura de imagem pela **câmera** ou **galeria**
- 📤 Envio da imagem para a API FastAPI
- 🎯 Ajuste do **limiar de confiança (threshold)**
- 🧮 Exibição da contagem de ovos detectados por classe
- 🖼️ Exibição da imagem processada com as detecções
- 🔗 Compartilhamento da imagem processada

## 🛠️ Tecnologias Usadas

- Flutter
- Dio (HTTP)
- image_picker (seleção de imagem)
- path_provider (armazenamento temporário)
- share_plus (compartilhamento)
- FastAPI como backend

## 📦 Dependências

Adicione no `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  image_picker: ^1.0.4
  share_plus: ^7.2.1
  path_provider: ^2.1.1
```

Execute:

```bash
flutter pub get
```

## ▶️ Execução

```bash
flutter run
```

> Certifique-se de que o backend esteja acessível no IP configurado no app (ex: `http://192.168.1.101:8000/predict/`).

## ⚠️ Permissões

No `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

No iOS (`Info.plist`):

```xml
<key>NSCameraUsageDescription</key>
<string>Necessário para tirar fotos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Necessário para escolher imagens</string>
```

## 🌐 Integração com a API

- Envia imagens via `multipart/form-data`
- Recebe resposta com:
  - `detections_count`: contagem por classe
  - `image`: imagem processada em formato hex codificado em base64

## 📌 Observações

- Funciona localmente com IPs locais (use IP real, não `localhost`)
- Ideal para testes em laboratório com amostras de ovos
- Interface simples e responsiva para uso em campo

## 📄 Licença

Este projeto está sob a licença [MIT](LICENSE).