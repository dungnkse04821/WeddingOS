import 'package:flutter/material.dart';
import '../services/cover_media_service.dart';

class CoverMediaScreen extends StatefulWidget {
  const CoverMediaScreen({super.key, required this.wedding});
  final Map<String, dynamic> wedding;

  @override
  State<CoverMediaScreen> createState() => _CoverMediaScreenState();
}

class _CoverMediaScreenState extends State<CoverMediaScreen> {
  final _media = CoverMediaService();
  String? _url;
  String? _message;
  bool _loading = true;
  bool _uploading = false;

  bool get _archived => widget.wedding['status'] == 'ARCHIVED';
  String get _weddingId => widget.wedding['id'] as String;

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    setState(() { _loading = true; _message = null; });
    final url = await _media.loadSignedUrl(_weddingId);
    if (mounted) setState(() { _url = url; _loading = false; });
  }

  Future<void> _chooseAndUpload() async {
    setState(() { _uploading = true; _message = null; });
    try {
      final bytes = await _media.pickAndOptimize();
      if (bytes == null) return;
      await _media.upload(_weddingId, bytes);
      await _reload();
      if (mounted) setState(() => _message = 'Cover photo updated.');
    } on FormatException catch (_) {
      if (mounted) setState(() => _message = 'Choose a JPEG, PNG, or WebP image no larger than 5 MB after optimization.');
    } catch (_) {
      await _reload();
      if (mounted) setState(() => _message = 'The upload outcome could not be confirmed. The current cover was reloaded; you can safely try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cover Photo')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_loading) const Center(child: CircularProgressIndicator())
        else if (_url != null) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(_url!, height: 220, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const SizedBox(height: 220, child: Center(child: Text('Cover preview is unavailable.'))))
        else const SizedBox(height: 220, child: Center(child: Text('No cover photo yet.'))),
        const SizedBox(height: 20),
        if (_archived) const Text('This archived Wedding is read-only. Existing cover photos remain visible to members.')
        else ElevatedButton.icon(onPressed: _uploading ? null : _chooseAndUpload, icon: const Icon(Icons.photo_library_outlined), label: Text(_uploading ? 'Uploading...' : (_url == null ? 'Upload Cover Photo' : 'Change Cover Photo'))),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!)),
      ]),
    ),
  );
