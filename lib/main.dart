import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'audio_url_stub.dart' if (dart.library.js_interop) 'audio_url_web.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile Form',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ProfileFormPage(),
    );
  }
}

/// Simple model holding everything the user enters.
class UserProfile {
  final String name;
  final String email;
  final String job;
  final DateTime? birthDate;
  final List<String> hobbies;
  final String sport;
  final String favoriteTeam;
  final List<String> favoritePlayers;
  final String bio;
  final Uint8List? imageBytes;
  final String? songName;
  final String? songPath; // null on web
  final Uint8List? songBytes; // only filled on web

  UserProfile({
    required this.name,
    required this.email,
    required this.job,
    required this.birthDate,
    required this.hobbies,
    required this.sport,
    required this.favoriteTeam,
    required this.favoritePlayers,
    required this.bio,
    this.imageBytes,
    this.songName,
    this.songPath,
    this.songBytes,
  });

  bool get hasSong => songPath != null || songBytes != null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'job': job,
        'birthDate': birthDate?.toIso8601String(),
        'hobbies': hobbies,
        'sport': sport,
        'favoriteTeam': favoriteTeam,
        'favoritePlayers': favoritePlayers,
        'bio': bio,
        'songName': songName,
      };
}

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _teamCtrl = TextEditingController();
  final _playerCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  DateTime? _birthDate;
  String? _sport;

  static const _sports = [
    'Football (Soccer)',
    'Rugby',
    'Cricket',
    'Basketball',
    'American Football',
    'Baseball',
    'Tennis',
    'Formula 1',
    'Other',
  ];

  static const _hobbyOptions = [
    'Reading',
    'Gaming',
    'Cooking',
    'Hiking',
    'Music',
    'Travel',
    'Photography',
    'Fitness',
    'Coding',
    'Movies',
    'Art',
    'Gardening',
  ];

  final Set<String> _selectedHobbies = {};
  final List<String> _players = [];

  final _imagePicker = ImagePicker();
  Uint8List? _imageBytes;
  String? _songName;
  String? _songPath;
  Uint8List? _songBytes;
  int? _songSize;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _jobCtrl.dispose();
    _teamCtrl.dispose();
    _playerCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    } catch (e) {
      _showError('Could not load image: $e');
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            if (_imageBytes != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _imageBytes = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Uses the newer file_picker API (`FilePicker.pickFile`). On web there is no
  /// real file path, so we read the bytes and play them from memory.
  Future<void> _pickSong() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.audio);
      if (file == null) return; // user cancelled

      final size = await file.length();
      final bytes = kIsWeb ? await file.readAsBytes() : null;

      if (!mounted) return;
      setState(() {
        _songName = file.name;
        _songSize = size;
        _songPath = kIsWeb ? null : file.path;
        _songBytes = bytes;
      });
    } catch (e) {
      _showError('Could not pick song: $e');
    }
  }

  void _clearSong() => setState(() {
        _songName = null;
        _songPath = null;
        _songBytes = null;
        _songSize = null;
      });

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addPlayer() {
    final player = _playerCtrl.text.trim();
    if (player.isEmpty) return;
    if (_players.any((p) => p.toLowerCase() == player.toLowerCase())) {
      _playerCtrl.clear();
      return;
    }
    setState(() {
      _players.add(player);
      _playerCtrl.clear();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedHobbies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one hobby')),
      );
      return;
    }

    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      job: _jobCtrl.text.trim(),
      birthDate: _birthDate,
      hobbies: _selectedHobbies.toList(),
      sport: _sport ?? '',
      favoriteTeam: _teamCtrl.text.trim(),
      favoritePlayers: List.of(_players),
      bio: _bioCtrl.text.trim(),
      imageBytes: _imageBytes,
      songName: _songName,
      songPath: _songPath,
      songBytes: _songBytes,
    );

    // TODO: send profile.toJson() to your backend here.

    // Submit -> play the animated "video" with the song in the background.
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => ProfileVideoPage(profile: profile),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _reset() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _emailCtrl.clear();
    _jobCtrl.clear();
    _teamCtrl.clear();
    _playerCtrl.clear();
    _bioCtrl.clear();
    setState(() {
      _birthDate = null;
      _sport = null;
      _selectedHobbies.clear();
      _players.clear();
      _imageBytes = null;
      _songName = null;
      _songPath = null;
      _songBytes = null;
      _songSize = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about you')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImageOptions,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundImage:
                            _imageBytes == null ? null : MemoryImage(_imageBytes!),
                        child: _imageBytes == null
                            ? const Icon(Icons.person, size: 56)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primary,
                          child: Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _showImageOptions,
                  child: Text(_imageBytes == null ? 'Upload your photo' : 'Change photo'),
                ),
              ),
              const SizedBox(height: 8),
              _sectionTitle('About you', theme),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Please enter your email';
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                  return ok ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _jobCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Job / occupation',
                  prefixIcon: Icon(Icons.work),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter your job' : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    prefixIcon: Icon(Icons.cake),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Tap to choose'
                        : '${_birthDate!.year}-${_two(_birthDate!.month)}-${_two(_birthDate!.day)}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Short bio (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              _sectionTitle('Hobbies', theme),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _hobbyOptions.map((h) {
                  final selected = _selectedHobbies.contains(h);
                  return FilterChip(
                    label: Text(h),
                    selected: selected,
                    onSelected: (value) => setState(() {
                      value ? _selectedHobbies.add(h) : _selectedHobbies.remove(h);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Sports', theme),
              DropdownButtonFormField<String>(
                value: _sport,
                decoration: const InputDecoration(
                  labelText: 'Favorite sport',
                  prefixIcon: Icon(Icons.sports),
                  border: OutlineInputBorder(),
                ),
                items: _sports
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _sport = v),
                validator: (v) => v == null ? 'Please pick a sport' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teamCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Favorite team',
                  prefixIcon: Icon(Icons.shield),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a team' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _playerCtrl,
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _addPlayer(),
                      decoration: const InputDecoration(
                        labelText: 'Favorite player',
                        prefixIcon: Icon(Icons.star),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton.icon(
                      onPressed: _addPlayer,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_players.isEmpty)
                Text(
                  'Add as many players as you like.',
                  style: theme.textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  children: _players
                      .map((p) => InputChip(
                            label: Text(p),
                            onDeleted: () => setState(() => _players.remove(p)),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 24),
              _sectionTitle('Your song', theme),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(
                    _songName ?? 'No song selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _songSize == null ? 'MP3, M4A, WAV, etc.' : _formatSize(_songSize!),
                  ),
                  trailing: _songName == null
                      ? FilledButton.tonalIcon(
                          onPressed: _pickSong,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose'),
                        )
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearSong,
                        ),
                  onTap: _pickSong,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      );

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ---------------------------------------------------------------------------
// Animated "video" page
// ---------------------------------------------------------------------------

/// Plays a Ken Burns style animation of the uploaded photo with rotating
/// caption slides, floating particles, and the submitted song in the
/// background. Everything loops until the user closes the page.
class ProfileVideoPage extends StatefulWidget {
  final UserProfile profile;
  const ProfileVideoPage({super.key, required this.profile});

  @override
  State<ProfileVideoPage> createState() => _ProfileVideoPageState();
}

class _ProfileVideoPageState extends State<ProfileVideoPage>
    with SingleTickerProviderStateMixin {
  static const _videoLength = Duration(seconds: 24);

  late final AnimationController _c;
  final AudioPlayer _player = AudioPlayer();
  late final List<_Caption> _captions;
  late final List<_Particle> _particles;

  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _captions = _buildCaptions(widget.profile);

    final rnd = math.Random(7);
    _particles = List.generate(
      28,
      (_) => _Particle(
        x: rnd.nextDouble(),
        offset: rnd.nextDouble(),
        speed: 0.3 + rnd.nextDouble() * 0.7,
        size: 2 + rnd.nextDouble() * 4,
        sway: rnd.nextDouble() * 0.05,
      ),
    );

    _c = AnimationController(vsync: this, duration: _videoLength)..repeat();

    // Give the page transition and first frames time to render before we
    // load/decode the song, so the UI never appears frozen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _startMusic();
      });
    });
  }

  String? _blobUrl;

  Future<void> _startMusic() async {
    final p = widget.profile;
    try {
      Source? source;
      if (p.songBytes != null) {
        // Web: blob URL is instant; BytesSource would base64-encode the whole
        // file on the main thread and freeze the page.
        _blobUrl = createAudioUrl(p.songBytes!, p.songName);
        source = UrlSource(_blobUrl!);
      } else if (p.songPath != null) {
        source = DeviceFileSource(p.songPath!);
      }
      if (source == null) return; // no song uploaded
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(source);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play song: $e')),
      );
    }
  }

  List<_Caption> _buildCaptions(UserProfile p) {
    final list = <_Caption>[
      _Caption(p.name, p.job),
      _Caption('Hobbies', p.hobbies.join('  •  ')),
      _Caption(p.sport, 'Supporting ${p.favoriteTeam}'),
    ];
    if (p.favoritePlayers.isNotEmpty) {
      list.add(_Caption('Favorite players', p.favoritePlayers.join('  •  ')));
    }
    if (p.bio.isNotEmpty) list.add(_Caption('', '"${p.bio}"'));
    if (p.songName != null) list.add(_Caption('Now playing', p.songName!));
    return list;
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _c.repeat(); // continues from the current value
      if (widget.profile.hasSong) _player.resume();
    } else {
      _c.stop();
      _player.pause();
    }
  }

  Future<void> _close() async {
    await _player.stop();
    if (mounted) Navigator.of(context).pop();
  }

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileSummaryPage(profile: widget.profile),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _player.dispose();
    if (_blobUrl != null) revokeAudioUrl(_blobUrl!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(child: _buildBackground(t)),
                // Dark gradient so the text stays readable.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black38, Colors.transparent, Colors.black87],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(painter: _ParticlePainter(_particles, t)),
                ),
                _buildCaption(t),
                _buildControls(t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackground(double t) {
    // Triangle wave 0 -> 1 -> 0 so the loop is seamless.
    final wave = 1 - (2 * t - 1).abs();
    final eased = Curves.easeInOut.transform(wave);
    final scale = 1.0 + 0.3 * eased;
    // Slow drifting focal point makes it feel like a camera move.
    final focal = Alignment(
      math.sin(t * math.pi * 2) * 0.6,
      math.cos(t * math.pi * 2) * 0.4,
    );

    final bytes = widget.profile.imageBytes;
    if (bytes == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + eased, -1),
            end: Alignment(1, 1 - eased),
            colors: const [Color(0xFF283593), Color(0xFF7E57C2), Color(0xFFEC407A)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.person, size: 160, color: Colors.white24),
        ),
      );
    }

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: focal,
        child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }

  Widget _buildCaption(double t) {
    final n = _captions.length;
    final slot = t * n;
    final index = slot.floor().clamp(0, n - 1);
    final local = slot - index; // 0..1 within this caption

    // Fade in over the first 20%, fade out over the last 20%.
    final opacity = (math.min(local, 1 - local) / 0.2).clamp(0.0, 1.0);
    final slide = (1 - Curves.easeOut.transform((local / 0.25).clamp(0.0, 1.0))) * 30;
    final cap = _captions[index];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 90),
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slide),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cap.title.isNotEmpty)
                  Text(
                    cap.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black87)],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  cap.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(double t) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _close,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'View details',
              icon: const Icon(Icons.list_alt, color: Colors.white),
              onPressed: _openDetails,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _playing ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: _togglePlay,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Caption {
  final String title;
  final String body;
  const _Caption(this.title, this.body);
}

class _Particle {
  final double x, offset, speed, size, sway;
  const _Particle({
    required this.x,
    required this.offset,
    required this.speed,
    required this.size,
    required this.sway,
  });
}

/// Soft glowing dots floating upwards.
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Whole cycles per loop keep the animation seamless.
      final cycles = (p.speed * 3).round().clamp(1, 3);
      final progress = (t * cycles + p.offset) % 1.0;
      final y = size.height * (1 - progress);
      final x = size.width * p.x + math.sin(progress * math.pi * 4) * size.width * p.sway;
      final alpha = math.sin(progress * math.pi).clamp(0.0, 1.0) * 0.6;
      // No blur mask: 28 blurred circles per frame is very heavy on web/low-end phones.
      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()..color = Colors.white.withOpacity(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

/// Shows what the user entered.
class ProfileSummaryPage extends StatelessWidget {
  final UserProfile profile;
  const ProfileSummaryPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final b = profile.birthDate;
    final birth = b == null
        ? '—'
        : '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profile.imageBytes != null) ...[
            Center(
              child: CircleAvatar(
                radius: 56,
                backgroundImage: MemoryImage(profile.imageBytes!),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _tile(Icons.person, 'Name', profile.name),
          _tile(Icons.email, 'Email', profile.email),
          _tile(Icons.work, 'Job', profile.job),
          _tile(Icons.cake, 'Date of birth', birth),
          if (profile.bio.isNotEmpty) _tile(Icons.notes, 'Bio', profile.bio),
          _tile(Icons.interests, 'Hobbies', profile.hobbies.join(', ')),
          _tile(Icons.sports, 'Favorite sport', profile.sport),
          _tile(Icons.shield, 'Favorite team', profile.favoriteTeam),
          _tile(
            Icons.star,
            'Favorite players',
            profile.favoritePlayers.isEmpty ? '—' : profile.favoritePlayers.join(', '),
          ),
          if (profile.songName != null)
            _tile(Icons.music_note, 'Song', profile.songName!),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(value),
        ),
      );
}