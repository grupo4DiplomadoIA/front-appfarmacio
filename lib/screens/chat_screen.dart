import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _conversationId;
  String _selectedModel = "gpt-4o";
  final SpeechToText speech = SpeechToText();
  bool _hasSpeech = false;
  bool _logEvents = false;
  bool _onDevice = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  List<LocaleName> _localeNames = [];
  String _transcribedText = '';
  final FlutterTts flutterTts = FlutterTts();
  bool _isTtsEnabled = false;
  bool _isListening = false;
  File? _image;
  final picker = ImagePicker();
  List<Map<String, dynamic>> _chatHistory = [];
  final Map<String, String> pharmacyLinks = {
    'CRUZ VERDE': 'https://www.cruzverde.cl',
    'AHUMADA': 'https://www.farmaciasahumada.cl',
    'SALCOBRAND': 'https://salcobrand.cl',
    'DEL DR. SIMI': 'https://www.drsimi.cl',
    'FARMACIA KNOP': 'https://www.farmaciasknop.com',
    // Añade más farmacias y sus links según sea necesario
  };
  final List<String> _availableModels = [
    "gpt-4o",
    "llama3-8b-8192",
    "llama-3.1-70b-versatile",
    "gpt-4o-mini"
  ];
  @override
  void initState() {
    super.initState();
    initializeSpeech();
    initializeTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
Future<void> getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _addImageMessage(_image!);
      } else {
        print('No image selected.');
      }
    });
  }

  void _addImageMessage(File image) {
    setState(() {
      _messages.add(ChatMessage(
        text: '',
        isUser: true,
        imageFile: image,
      ));
    });
    _scrollToBottom();
    _sendImageToServer(image);
  }
Future<void> _sendImageToServer(File imageFile) async {
    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://biopc.cl/search_by_image'));
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      Position position = await _getCurrentPosition();
      request.fields['lat'] = position.latitude.toString();
      request.fields['lng'] = position.longitude.toString();
      request.fields['model_name'] = _selectedModel;
      if (_conversationId != null) {
        request.fields['conversation_id'] = _conversationId!;
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(await response.stream.bytesToString());
        _processApiResponse(jsonResponse);
        if (_conversationId == null && jsonResponse['conversation_id'] != null) {
          _conversationId = jsonResponse['conversation_id'];
        }
      } else {
        _addErrorMessage("Error al procesar la imagen.");
      }
    } catch (e) {
      _addErrorMessage("Error al enviar la imagen: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }
    void _addErrorMessage(String errorText) {
    setState(() {
      _messages.add(ChatMessage(
        text: errorText,
        isUser: false,
      ));
    });
  }
  Future<void> initializeTts() async {
    try {
      await flutterTts.setLanguage("es-US");
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
    } catch (e) {
      print("Error initializing TTS: $e");
    }
  }

  Future<void> speakText(String text) async {
    await flutterTts.speak(text);
  }
  Future<void> stopTts() async {
    await flutterTts.stop();
  }
  Future<void> initializeSpeech() async {
    try {
      var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: _logEvents,
      );
      if (hasSpeech) {
        _localeNames = await speech.locales();
        _currentLocaleId = 'es_ES';
      }
      if (!mounted) return;
      setState(() {
        _hasSpeech = hasSpeech;
      });
    } catch (e) {
      setState(() {
        lastError = 'Speech recognition failed: ${e.toString()}';
        _hasSpeech = false;
      });
    }
  }

  void _toggleTts() {
    setState(() {
      _isTtsEnabled = !_isTtsEnabled;
    });
    if (!_isTtsEnabled) {
      stopTts();
    }
  }

  void startListening() {
     stopTts();
    lastWords = '';
    lastError = '';

    final options = SpeechListenOptions(
      onDevice: _onDevice,
      listenMode: ListenMode.dictation, // Cambiado a modo dictado
      cancelOnError: false, // No cancelar en caso de error
      partialResults: true,
      autoPunctuation: false, // Desactivado para capturar más audio
      enableHapticFeedback: true,
    );
    speech.listen(
      onResult: resultListener,
      listenFor: Duration(seconds: 60), // Aumentado a 60 segundos
      pauseFor: Duration(seconds: 1), // Reducido a 1 segundo
      localeId: _currentLocaleId,
      onSoundLevelChange: soundLevelListener,
      listenOptions: options,
    );
    setState(() {});
  }

  void stopListening() {
    speech.stop();
    setState(() {
      level = 0.0;
      _isListening = false;
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    setState(() {
      _transcribedText = result.recognizedWords;
      if (result.finalResult) {
        _textController.text = _transcribedText;
        _isListening = false;
      } else {
        _textController.text = _transcribedText;
      }
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
    });
  }

  void statusListener(String status) {
    setState(() {
      lastStatus = status;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _conversationId = null;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('chat_history');
    if (historyJson != null) {
      setState(() {
        _chatHistory = List<Map<String, dynamic>>.from(jsonDecode(historyJson));
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(_chatHistory);
    await prefs.setString('chat_history', historyJson);
  }

  void _addToHistory(String title) {
    _chatHistory.insert(0, {
      'title': title,
      'messages': _messages.map((msg) => msg.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    _saveChatHistory();
  }

  void _handleSuggestionSelected(String suggestion) {
    // Enviar la sugerencia seleccionada al servidor
    _handleSubmitted(suggestion);
  }

  Future<Position> _getCurrentPosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('error');
      }
    }
    return await Geolocator.getCurrentPosition();
  }

  void _handleSubmitted(String text) async {
     stopTts(); 
    _textController.clear();
    ChatMessage message = ChatMessage(
      text: text,
      isUser: true,
    );
    setState(() {
      _messages.add(message);
      _isLoading = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      Position position = await _getCurrentPosition();
      final response = await http.post(
        Uri.parse('https://biopc.cl/chat'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'mensaje': text,
          'lat': position.latitude,
          'lng': position.longitude,
          'model_name': _selectedModel,
          'conversation_id': _conversationId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        _processApiResponse(jsonResponse);
        if (_conversationId == null &&
            jsonResponse['conversation_id'] != null) {
          _conversationId = jsonResponse['conversation_id'];
        }
      } else {
        ChatMessage errorMessage = ChatMessage(
          text: "Lo siento, hubo un error al procesar tu solicitud.",
          isUser: false,
        );
        setState(() {
          _messages.add(errorMessage);
        });
      }
    } catch (e) {
      ChatMessage errorMessage = ChatMessage(
        text: "Lo siento, ocurrió un error al conectar con el servidor.",
        isUser: false,
      );
      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _processApiResponse(Map<String, dynamic> jsonResponse) {
    final buscarFarmacoResultado = jsonResponse['buscar_farmaco_resultado'];
    final localesCercanosResultado = jsonResponse['locales_cercanos_resultado'];
    final buscarMedicosResultado = jsonResponse['buscar_medicos_resultado'];
    final respuestaAgente = jsonResponse['respuesta_agente'];
    if (respuestaAgente != null) {
      ChatMessage agentMessage = ChatMessage(
        text: respuestaAgente,
        isUser: false,
        isAgent: true,
      );
      setState(() {
        _messages.add(agentMessage);
      });
      if (_isTtsEnabled) {
        speakText(respuestaAgente);
      }
    }
    if (buscarFarmacoResultado != null) {
      _processBuscarFarmacoResultado(buscarFarmacoResultado);
    }
    if (localesCercanosResultado != null) {
      _processLocalesCercanosResultado(localesCercanosResultado);
    }

    // Procesar resultado de búsqueda de médicos
    if (buscarMedicosResultado != null) {
      _processBuscarMedicosResultado(jsonResponse);
    }
  }

  void _processLocalesCercanosResultado(Map<String, dynamic> resultado) {
    List<Map<String, dynamic>> pharmaciesData = [];
    for (var pharmacy in resultado['Farmacias']) {
      pharmaciesData.add({
        ...pharmacy,
        'is_on_duty': false,
      });
    }
    for (var onDuty in resultado['Turno']) {
      pharmaciesData.add({
        ...onDuty,
        'is_on_duty': true,
      });
    }

    // Obtener información de la farmacia más cercana
    String nearestPharmacyInfo = "";
    String? pharmacyLink;
    if (pharmaciesData.isNotEmpty) {
      var nearestPharmacy = pharmaciesData.first;
      nearestPharmacyInfo =
          "\nLa farmacia más cercana es ${nearestPharmacy['local_nombre']}.";

      // Buscar si la farmacia tiene un link en nuestra lista
      String pharmacyName = nearestPharmacy['local_nombre'].toString();
      pharmacyLink = pharmacyLinks.entries
          .firstWhere(
            (entry) =>
                pharmacyName.toLowerCase().contains(entry.key.toLowerCase()),
            orElse: () => MapEntry('', ''),
          )
          .value;
    }

    ChatMessage mapMessage = ChatMessage(
      text:
          "Aquí tienes Información de Farmacias en tu zona. $nearestPharmacyInfo" +
              (pharmacyLink != null && pharmacyLink.isNotEmpty
                  ? "\nVisita su página web: $pharmacyLink"
                  : "") +
              "\nSigue el link para ver el mapa!!",
      isUser: false,
      onMapPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MapScreen(pharmaciesData: pharmaciesData)),
        );
      },
    );
    setState(() {
      _messages.add(mapMessage);
    });
  }

  void _processBuscarFarmacoResultado(Map<String, dynamic> resultado) {
    final qdrantResults = resultado['qdrant_results'] as List<dynamic>?;

    if (qdrantResults != null && qdrantResults.isNotEmpty) {
      var primerResultado = qdrantResults.first['payload'];
      ChatMessage infoMessage = ChatMessage(
        text: "",
        isUser: false,
        farmacoInfo: primerResultado,
      );
      setState(() {
        _messages.add(infoMessage);
      });
    }

    if (resultado['productos'] != null && resultado['productos'].isNotEmpty) {
      ChatMessage productMessage = ChatMessage(
        text: "Sugerencias de productos basadas en tu consulta:",
        isUser: false,
        productCards: resultado['productos'],
      );
      setState(() {
        _messages.add(productMessage);
      });
    }
  }

  void _processBuscarMedicosResultado(Map<String, dynamic> resultado) {
    String messageText = resultado['respuesta_agente'] ??
        "Aquí tienes los resultados de la búsqueda de médicos:";

    List<Map<String, dynamic>> medicos = [];
    String especialidad = "";
    String ciudad = "";

    if (resultado['buscar_medicos_resultado'] != null &&
        resultado['buscar_medicos_resultado'] is Map<String, dynamic>) {
      var buscarMedicosResultado = resultado['buscar_medicos_resultado'];

      especialidad = buscarMedicosResultado['especialidad'] ?? "";
      ciudad = buscarMedicosResultado['ciudad'] ?? "";

      if (buscarMedicosResultado['medicos'] is List) {
        medicos =
            List<Map<String, dynamic>>.from(buscarMedicosResultado['medicos']);

        // Asegurar que cada médico tenga los campos necesarios
        medicos = medicos.map((medico) {
          return {
            'nombre': medico['nombre'] ?? 'Nombre no disponible',
            'especialidades':
                medico['especialidades'] ?? 'Especialidad no especificada',
            'direccion': medico['direccion'] ?? 'Dirección no disponible',
            'imagen': medico['imagen'] ??
                '//platform.docplanner.com/img/general/doctor/doctor-default-80-80.png',
          };
        }).toList();
      }
    }

    ChatMessage message = ChatMessage(
      text: messageText,
      isUser: false,
      especialidad: especialidad,
      ciudad: ciudad,
      medicos: medicos,
    );

    setState(() {
      _messages.add(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 225, 224, 224),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundImage: AssetImage('assets/images/logo.png'),
              radius: 20,
            ),
            SizedBox(width: 8),
            Text(
              "IAFarma",
              style: TextStyle(color: Colors.black,fontWeight:FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: _isTtsEnabled ? Colors.green : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isTtsEnabled ? Icons.volume_up : Icons.volume_off,
                color: Colors.black,
              ),
                onPressed: () {
                _toggleTts();
                stopTts(); 
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.chat, color: Colors.black),
            onPressed: () {
              _showSaveDialog(context);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            Container(
              width: 60,
              height: 60,
              child: Image(
                image: AssetImage('assets/images/logo.png'),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.history),
              title: Text('Historial'),
              onTap: () {
                Navigator.pop(context);
                _showHistoryDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configuración'),
              onTap: () {
                _showConfigurationDialog(context);
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(2.0),
                itemBuilder: (_, int index) => _messages[index],
                itemCount: _messages.length,
              ),
            ),
            if (_isLoading) // Agregar el indicador de carga
              Padding(
                padding: EdgeInsets.all(2.0),
                child: CircularProgressIndicator(),
              ),
            Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 59, 57, 57),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              margin: EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigurationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Configuración'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Selecciona el modelo LLM:'),
              DropdownButton<String>(
                value: _selectedModel,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedModel = newValue;
                    });
                    Navigator.of(context).pop();
                  }
                },
                items: _availableModels
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSaveDialog(BuildContext context) {
    TextEditingController titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Guardar conversación'),
          content: TextField(
            controller: titleController,
            decoration: InputDecoration(hintText: "Título de la conversación"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Guardar'),
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  _addToHistory(titleController.text);
                  _clearChat();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Conversación guardada')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Historial de conversaciones'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final conversation = _chatHistory[index];
                return Dismissible(
                  key: Key(conversation['timestamp']),
                  background: Container(
                    color: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteConversation(index);
                  },
                  child: ListTile(
                    title: Text(conversation['title']),
                    subtitle: Text(
                        DateTime.parse(conversation['timestamp']).toString()),
                    onTap: () {
                      Navigator.of(context).pop();
                      _loadConversation(conversation);
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        _showDeleteConfirmationDialog(context, index);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content:
              Text('¿Estás seguro de que quieres eliminar esta conversación?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Eliminar'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteConversation(index);
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteConversation(int index) {
    setState(() {
      _chatHistory.removeAt(index);
    });
    _saveChatHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conversación eliminada')),
    );
  }

  void _loadConversation(Map<String, dynamic> conversation) {
    setState(() {
      _messages.clear();
      _messages.addAll(
        (conversation['messages'] as List)
            .map((msg) => ChatMessage.fromJson(msg))
            .toList(),
      );
    });
  }

Widget _buildTextComposer() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 1.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center, // Centramos verticalmente
      children: [
        Center(
          child: IconButton(
              icon: Icon(
                Icons.image,
                color: Colors.white,
              ),
              onPressed: getImage,
            ),
          ),
        
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted,
              decoration: InputDecoration(
                hintText: "Mensaje",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                fillColor: Colors.white, // Añadido color de fondo blanco
                filled: true, // Asegura que el color de fondo se aplique
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ),
        Center(
          child: IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
            ),
            onPressed: () {
              stopTts();
              if (_isListening) {
                stopListening();
              } else {
                startListening();
              }
            },
          ),
        ),
        Center(
          child: IconButton(
            icon: Icon(
              Icons.send,
              color: const Color.fromARGB(255, 247, 245, 246), size: 30.0
            ),
            onPressed: () {
              stopTts(); // Detener TTS al enviar un mensaje
              _handleSubmitted(_textController.text);
            },
          ),
        ),
      ],
    ),
  );
}

}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final VoidCallback? onMapPressed;
  final List<Map<String, dynamic>>? qdrantResults;
  final List<dynamic>? productCards;
  final List<String>? suggestions;
  final Function(String)? onSuggestionSelected;
  final String? especialidad;
  final String? ciudad;
  final List<Map<String, dynamic>>? medicos;
  final Map<String, dynamic>? farmacoInfo;
  final bool isAgent;
   final File? imageFile;
  ChatMessage({
    required this.text,
    required this.isUser,
    this.onMapPressed,
    this.qdrantResults,
    this.productCards,
    this.suggestions,
    this.onSuggestionSelected,
    this.especialidad,
    this.ciudad,
    this.medicos,
    this.farmacoInfo,
    this.isAgent = false,
     this.imageFile,
  });
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'isAgent': isAgent,
      'qdrantResults': qdrantResults,
      'productCards': productCards,
      'suggestions': suggestions,
      'especialidad': especialidad,
      'ciudad': ciudad,
      'medicos': medicos,
      'farmacoInfo': farmacoInfo,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'],
      isUser: json['isUser'],
      isAgent: json['isAgent'] ?? false,
      qdrantResults: json['qdrantResults'],
      productCards: json['productCards'],
      suggestions: json['suggestions'] != null
          ? List<String>.from(json['suggestions'])
          : null,
      especialidad: json['especialidad'],
      ciudad: json['ciudad'],
      medicos: json['medicos'],
      farmacoInfo: json['farmacoInfo'],
    );
  }
  @override
    Widget build(BuildContext context) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser && isAgent)
                  CircleAvatar(
                    child: Image.asset('assets/images/logo.png'),
                    radius: 15,
                  ),
                SizedBox(width: 8.0),
                Flexible(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color.fromARGB(255, 186, 217, 176)
                          : const Color.fromARGB(72, 192, 189, 189),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageFile != null)
                          Image.file(
                            imageFile!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        if (text.isNotEmpty)
                          MarkdownBody(
                            data: text,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: Colors.black87),
                              h1: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              h2: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              strong: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              listBullet: TextStyle(color: Colors.black87),
                            ),
                          ),
                      if (onMapPressed != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ElevatedButton(
                            onPressed: onMapPressed,
                            child: Text('Ver mapa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (medicos != null && medicos!.isNotEmpty)
                        _buildMedicosList(),
                      if (suggestions != null && suggestions!.isNotEmpty)
                        _buildSuggestions(),
                      if (farmacoInfo != null)
                        InformacionFarmaco(data: farmacoInfo!)
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.0),
              if (isUser) CircleAvatar(radius: 15, child: Icon(Icons.person)),
            ],
          ),
          if (productCards != null && productCards!.isNotEmpty)
            Container(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: productCards!.length,
                itemBuilder: (context, index) {
                  var product = productCards![index];
                  return ProductCard(
                    imageUrl: product['imagen'],
                    name: product['nombre'],
                    price: product['precio'],
                    url: product['url'],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicosList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          "Especialistas en $especialidad en $ciudad:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        SizedBox(height: 8),
        Column(
          children: medicos!.map((medico) {
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                      medico['imagen'].startsWith('//')
                          ? 'https:${medico['imagen']}'
                          : medico['imagen']),
                  radius: 25,
                  onBackgroundImageError: (_, __) {
                    // Manejar errores de carga de imagen
                  },
                ),
                title: Text(medico['nombre'],
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medico['especialidades']),
                    Text(medico['direccion']),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        Text(
          "Sugerencias:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: suggestions!.map((suggestion) {
            return ElevatedButton(
              child: Text(suggestion),
              onPressed: () {
                if (onSuggestionSelected != null) {
                  onSuggestionSelected!(suggestion);
                }
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQdrantResultsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Resultados relacionados:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        SizedBox(height: 4),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          defaultColumnWidth: IntrinsicColumnWidth(),
          children: [
            TableRow(
              children: [
                TableCell(
                    child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Nombre',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )),
                TableCell(
                    child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Fármaco',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )),
                TableCell(
                    child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Laboratorio',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )),
              ],
            ),
            ...qdrantResults!
                .map((result) => TableRow(
                      children: [
                        TableCell(
                            child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(result['nombre'],
                              style: TextStyle(fontSize: 10)),
                        )),
                        TableCell(
                            child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(result['farmaco'],
                              style: TextStyle(fontSize: 10)),
                        )),
                        TableCell(
                            child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(result['laboratorio'],
                              style: TextStyle(fontSize: 10)),
                        )),
                      ],
                    ))
                .toList(),
          ],
        ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String price;
  final String url;

  ProductCard({
    required this.imageUrl,
    required this.name,
    required this.price,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Card(
        margin: EdgeInsets.all(8),
        color: const Color.fromARGB(255, 239, 238, 241),
        child: Container(
          width: 180,
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center, // Centramos la imagen
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.error);
                    },
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                price,
                style:
                    TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InformacionFarmaco extends StatelessWidget {
  final Map<String, dynamic> data;

  InformacionFarmaco({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información del Fármaco',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),
            _buildInfoTile('Fármaco', data['farmaco']),
            _buildInfoTile('Acción Terapéutica', data['accionTerapeutica']),
            _buildInfoTile('Indicaciones', data['indicaciones']),
            _buildInfoTile('Precauciones', data['precauciones']),
            _buildInfoTile('Contraindicaciones', data['contraindicaciones']),
            _buildInfoTile('Sobredosificación', data['sobredosificacion']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String? content) {
    if (content == null || content.isEmpty) {
      return SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4, // Mejora la legibilidad del texto.
            ),
          ),
        ],
      ),
    );
  }
}
