import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'map_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Map<String, String> pharmacyLinks = {
    'CRUZ VERDE': 'https://www.cruzverde.cl',
    'AHUMADA': 'https://www.farmaciasahumada.cl',
    'SALCOBRAND': 'https://salcobrand.cl',
    'DEL DR. SIMI': 'https://www.drsimi.cl',
    'FARMACIA KNOP': 'https://www.farmaciasknop.com',
    // Añade más farmacias y sus links según sea necesario
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
 void _handleSuggestionSelected(String suggestion) {
    // Enviar la sugerencia seleccionada al servidor
    _handleSubmitted(suggestion);
  }

  void _handleSubmitted(String text) async {
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
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/chat'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'mensaje': text,
          'lat': -37.444513,
          'lng': -72.336370,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        _processApiResponse(jsonResponse);
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
    final tipo = jsonResponse['tipo'];
    final data = jsonResponse['data'];

    if (tipo == "2") {
      String markdownResponse = data['gpt_response'] + "\n\n";

      final qdrantResults = data['qdrant_results'] as List<dynamic>?;

      if (qdrantResults != null && qdrantResults.isNotEmpty) {
        markdownResponse += "## Resultados relacionados\n\n";
        markdownResponse +=
            "Aquí tienes una lista de productos relacionados:\n\n";
        markdownResponse += "| Nombre | Fármaco | Laboratorio |\n";
        markdownResponse += "|--------|---------|-------------|\n";

        for (var result in qdrantResults) {
          markdownResponse +=
              "| ${result['nombre']} | ${result['farmaco']} | ${result['laboratorio']} |\n";
        }
      }

      ChatMessage combinedMessage = ChatMessage(
        text: markdownResponse,
        isUser: false,
      );
      setState(() {
        _messages.add(combinedMessage);
      });
      if (data['productos'] != null && data['productos'].isNotEmpty) {
        ChatMessage productMessage = ChatMessage(
          text: "Sugerencias de productos basadas en tu consulta:",
          isUser: false,
          productCards: data['productos'],
        );
        setState(() {
          _messages.add(productMessage);
        });
      }
    } else if (tipo == "1") {
      List<Map<String, dynamic>> pharmaciesData = [];
      for (var pharmacy in data['Farmacias']) {
        pharmaciesData.add({
          ...pharmacy,
          'is_on_duty': false,
        });
      }
      for (var onDuty in data['Turno']) {
        pharmaciesData.add({
          ...onDuty,
          'is_on_duty': true,
        });
      }

      // Obtener información de la farmacia más cercana
      String nearestPharmacyInfo = "";
      String? pharmacyLink;
      if (data['Distancia'] != null && pharmaciesData.isNotEmpty) {
        var nearestPharmacy = pharmaciesData.first;
        nearestPharmacyInfo =
            "\nLa farmacia más cercana es ${nearestPharmacy['local_nombre']} a ${data['Distancia'].toStringAsFixed(2)} km.";

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
                builder: (context) =>
                    MapScreen(pharmaciesData: pharmaciesData)),
          );
        },
      );
      setState(() {
        _messages.add(mapMessage);
      });
    } else if (tipo == "3") {
      ChatMessage message = ChatMessage(
        text: data,
        isUser: false,
      );
      setState(() {
        _messages.add(message);
      });
    }else if (tipo == "4") {
    String messageText = data;
    List<Map<String, dynamic>> medicos = List<Map<String, dynamic>>.from(jsonResponse['medicos']);
    String especialidad = jsonResponse['especialidad'];
    String ciudad = jsonResponse['ciudad'];

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
    } else if (tipo == "5") {
      // Manejo de sugerencias
      List<String> alternativas = List<String>.from(jsonResponse['alternativas']);
      String mensaje = jsonResponse['mensaje'];
      
     ChatMessage suggestionMessage = ChatMessage(
        text: mensaje,
        isUser: false,
        suggestions: alternativas,
        onSuggestionSelected: _handleSuggestionSelected,
      );
      
      setState(() {
        _messages.add(suggestionMessage);
      });
    } 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.menu),
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
            Text("IAFarma"),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: () {},
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
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configuracion'),
              onTap: () {
                // Acción para la opción 2
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
                padding: EdgeInsets.all(8.0),
                itemBuilder: (_, int index) => _messages[index],
                itemCount: _messages.length,
              ),
            ),
            if (_isLoading) // Agregar el indicador de carga
              Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
              margin: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.camera_alt),
          onPressed: () {
            // Implementar funcionalidad de cámara
          },
        ),
        IconButton(
          icon: Icon(Icons.image),
          onPressed: () {
            // Implementar funcionalidad de galería
          },
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
                contentPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.send),
          onPressed: () => _handleSubmitted(_textController.text),
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
  });

  @override
@override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                CircleAvatar(
                  child: Image.asset('assets/images/logo.png'),
                  radius: 15,
                ),
              SizedBox(width: 8.0),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: isUser ? const Color.fromARGB(255, 186, 217, 176) : const Color.fromARGB(72, 192, 189, 189),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarkdownBody(
                        data: text,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(color: Colors.black87),
                          h1: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          strong: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          listBullet: TextStyle(color: Colors.black87),
                        ),
                      ),
                      if (medicos != null && medicos!.isNotEmpty)
                        _buildMedicosList(),
                      if (suggestions != null && suggestions!.isNotEmpty)
                        _buildSuggestions(),
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
                    : medico['imagen']
                ),
                radius: 25,
                onBackgroundImageError: (_, __) {
                  // Manejar errores de carga de imagen
                },
              ),
              title: Text(medico['nombre'], style: TextStyle(fontWeight: FontWeight.bold)),
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
