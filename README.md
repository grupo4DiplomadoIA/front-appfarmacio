
# IAFarma - Aplicación Móvil

## Descripción

**IAFarma** es una aplicación móvil desarrollada con Flutter que proporciona asistencia especializada en farmacología y búsqueda de información relacionada con medicamentos y farmacias. Esta aplicación se integra con un backend avanzado basado en Flask, OpenAI, Qdrant, y otros servicios de IA para ofrecer una experiencia completa y útil a los usuarios.

## Propósito

El propósito principal de IAFarma es:

1. **Asistencia en Farmacología**: Proporcionar información relevante y detallada sobre medicamentos a través de consultas textuales y visuales.
2. **Búsqueda de Farmacias Cercanas**: Localizar farmacias cercanas, incluyendo farmacias de turno, basándose en la ubicación del usuario.
3. **Consulta de Especialistas Médicos**: Sugerir la especialidad médica adecuada según la consulta del usuario y localizar médicos cercanos.
4. **Búsqueda por Imágenes**: Permitir la búsqueda de productos farmacéuticos utilizando imágenes capturadas por la cámara del dispositivo móvil.

## Características Principales

- **Interfaz Intuitiva**: Diseñada para ser fácil de usar, permitiendo a los usuarios interactuar con la aplicación a través de texto e imágenes.
- **Integración con Backend IA**: Comunicación fluida con el backend para obtener respuestas precisas sobre medicamentos, farmacias y especialistas.
- **Búsqueda Visual**: Función para tomar fotos de medicamentos y obtener información detallada mediante reconocimiento de imágenes.
- **Geolocalización**: Utiliza la ubicación del dispositivo para encontrar farmacias cercanas y especialistas médicos.
- **Historial de Consultas**: Guarda el historial de interacciones para mejorar la experiencia del usuario y ofrecer un contexto continuo.

## Arquitectura

La aplicación **IAFarma** se integra con un backend desarrollado en Flask que maneja las solicitudes de información y consultas del usuario. El backend utiliza servicios de IA como OpenAI y Qdrant para procesamiento de lenguaje natural y búsqueda vectorial, así como Redis para el almacenamiento del contexto de las conversaciones.

### Componentes Clave

1. **Frontend (Flutter)**
   - **Dart**: Lenguaje de programación utilizado para desarrollar la aplicación móvil.
   - **Flutter**: Framework que proporciona una interfaz de usuario rica y responsiva para Android y iOS.

2. **Backend (Flask)**
   - **OpenAI**: Para generar embeddings de texto y buscar información sobre medicamentos.
   - **Qdrant**: Motor de búsqueda vectorial que almacena y busca datos farmacéuticos.
   - **Redis**: Almacena el contexto de las interacciones para mantener la continuidad en las consultas.
   - **Groq**: Clasifica las consultas para identificar la especialidad médica adecuada.

## Requisitos

- Flutter SDK
- Dart SDK
- Conexión a Internet para la comunicación con el backend
- Backend del sistema IAFarma implementado y configurado (ver [README del backend](../backend/README.md))

## Instalación

1. **Clonar este repositorio:**

   ```bash
   git clone https://github.com/tu-repositorio/iafarma-flutter.git
   cd iafarma-flutter

============================================================
App de referencia original
# map_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
