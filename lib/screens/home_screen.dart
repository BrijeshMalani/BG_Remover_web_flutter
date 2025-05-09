import 'dart:io';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:web_bg_remover/bloc/image_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleFileSelection(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb && file.bytes != null) {
          // For web
          context.read<ImageBloc>().add(
                ImageUploaded(
                  imageBytes: file.bytes,
                  fileName: file.name,
                ),
              );
        } else if (file.path != null) {
          // For desktop/mobile
          context.read<ImageBloc>().add(
                ImageUploaded(
                  imageFile: File(file.path!),
                  fileName: file.name,
                ),
              );
        }
      }
    } catch (e) {
      context.read<ImageBloc>().add(ImageError(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Remover'),
        centerTitle: true,
      ),
      body: BlocBuilder<ImageBloc, ImageState>(
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state is ImageInitial) _buildInitialView(context),
                  if (state is ImageLoading) _buildLoadingView(state),
                  if (state is ImageSuccess) _buildSuccessView(context, state),
                  if (state is ImageFailure) _buildErrorView(state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image,
          size: 100,
          color: Colors.grey,
        ),
        const SizedBox(height: 24),
        const Text(
          'Drag and drop an image here\nor click to select',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _handleFileSelection(context),
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Select Image'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView(ImageLoading state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Processing image... ${(state.progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context, ImageSuccess state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: 500,
            maxHeight: 500,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              state.processedImageBytes,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _shareImage(state.processedImageBytes),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _downloadImage(
                state.processedImageBytes,
                state.originalFileName,
              ),
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _handleFileSelection(context),
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Process Another Image'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(ImageFailure state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline,
          size: 100,
          color: Colors.red,
        ),
        const SizedBox(height: 24),
        Text(
          state.message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _handleFileSelection(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareImage(Uint8List imageBytes) async {
    try {
      await Share.shareXFiles(
        [XFile.fromData(imageBytes)],
        text: 'Check out my background-removed image!',
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }

  void _downloadImage(Uint8List imageBytes, String originalFileName) {
    final blob = html.Blob([imageBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'no_bg_$originalFileName')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
