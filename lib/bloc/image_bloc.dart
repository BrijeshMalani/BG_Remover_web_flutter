import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Events
abstract class ImageEvent extends Equatable {
  const ImageEvent();

  @override
  List<Object> get props => [];
}

class ImageUploaded extends ImageEvent {
  final File? imageFile;
  final Uint8List? imageBytes;
  final String fileName;

  // For web, pass imageBytes; for mobile/desktop, pass imageFile
  const ImageUploaded(
      {this.imageFile, this.imageBytes, required this.fileName});

  @override
  List<Object> get props =>
      [imageFile ?? Object(), imageBytes ?? Object(), fileName];
}

class ImageProcessed extends ImageEvent {
  final Uint8List processedImageBytes;
  final String originalFileName;

  const ImageProcessed(this.processedImageBytes, this.originalFileName);

  @override
  List<Object> get props => [processedImageBytes, originalFileName];
}

class ImageError extends ImageEvent {
  final String message;

  const ImageError(this.message);

  @override
  List<Object> get props => [message];
}

// States
abstract class ImageState extends Equatable {
  const ImageState();

  @override
  List<Object> get props => [];
}

class ImageInitial extends ImageState {}

class ImageLoading extends ImageState {
  final double progress;

  const ImageLoading({this.progress = 0.0});

  @override
  List<Object> get props => [progress];
}

class ImageSuccess extends ImageState {
  final Uint8List processedImageBytes;
  final String originalFileName;

  const ImageSuccess(this.processedImageBytes, this.originalFileName);

  @override
  List<Object> get props => [processedImageBytes, originalFileName];
}

class ImageFailure extends ImageState {
  final String message;

  const ImageFailure(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class ImageBloc extends Bloc<ImageEvent, ImageState> {
  // Replace with your Remove.bg API key
  static const String _apiKey = 'gBqAS1TxxfERzxghkztXvW38';
  static const String _apiUrl = 'https://api.remove.bg/v1.0/removebg';

  ImageBloc() : super(ImageInitial()) {
    on<ImageUploaded>(_onImageUploaded);
    on<ImageProcessed>(_onImageProcessed);
    on<ImageError>(_onImageError);
  }

  Future<void> _onImageUploaded(
    ImageUploaded event,
    Emitter<ImageState> emit,
  ) async {
    if ((event.imageFile == null && event.imageBytes == null) ||
        event.fileName.isEmpty) {
      emit(ImageInitial());
      return;
    }

    emit(const ImageLoading(progress: 0.0));

    try {
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      // Add API key to headers
      request.headers.addAll({
        'X-Api-Key': _apiKey,
      });

      // Add image file
      if (kIsWeb && event.imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image_file',
            event.imageBytes!,
            filename: event.fileName,
          ),
        );
      } else if (event.imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image_file',
            event.imageFile!.path,
          ),
        );
      } else {
        emit(const ImageFailure('No image selected.'));
        return;
      }

      // Add parameters
      request.fields.addAll({
        'size': 'auto',
        'format': 'auto',
        'bg_color': '',
      });

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        add(ImageProcessed(
          response.bodyBytes,
          event.fileName,
        ));
      } else {
        final error = jsonDecode(response.body);
        add(ImageError(
            error['errors']?[0]?['title'] ?? 'Failed to process image'));
      }
    } catch (e) {
      add(ImageError(e.toString()));
    }
  }

  void _onImageProcessed(
    ImageProcessed event,
    Emitter<ImageState> emit,
  ) {
    emit(ImageSuccess(event.processedImageBytes, event.originalFileName));
  }

  void _onImageError(
    ImageError event,
    Emitter<ImageState> emit,
  ) {
    emit(ImageFailure(event.message));
  }
}
