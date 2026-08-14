import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? userName = prefs.getString('user_name');
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.blue, scaffoldBackgroundColor: const Color(0xFFF4F6F8)),
    home: userName == null ? const LoginScreen() : const MainChatScreen(),
  ));
}

// --- 1. شاشة إعداد الحساب قبل الدخول ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  XFile? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _profileImage = img);
  }

  Future<void> _saveAndEnter() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    if (_profileImage != null) {
      await prefs.setString('user_img', _profileImage!.path);
    }

    bool isAdmin = name.toLowerCase() == 'aziz';
    await prefs.setBool('is_admin', isAdmin);

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("مرحباً بك في الشلة 👋", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("يرجى وضع اسمك وصورتك قبل الدخول لشات المجموعة", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: _pickProfileImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: _profileImage != null ? FileImage(File(_profileImage!.path)) : null,
                  child: _profileImage == null ? const Icon(Icons.add_a_photo, size: 35, color: Colors.blue) : null,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: "اكتب اسمك هنا...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0084FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: _saveAndEnter,
                  child: const Text("دخول الشات 🎉", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. شاشة المحادثة الرئيسية ---
class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _msgCtrl = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _galleryImages = [];
  
  String _myName = "عضو";
  String? _myImgPath;
  bool _isAdmin = false;
  bool _isRecording = false;
  String? _typingUser;

  final String _groupName = "قروب الشلة الرسمي 🔥";
  final String _groupIcon = "https://i.pravatar.cc/300?u=shalla_group";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initUserData();
  }

  Future<void> _initUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _myName = prefs.getString('user_name') ?? "عضو";
    _myImgPath = prefs.getString('user_img');
    _isAdmin = _myName.toLowerCase() == 'aziz';

    final String? savedChat = prefs.getString('app_chat_data');
    if (savedChat != null) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(json.decode(savedChat));
        _updateGallery();
      });
    } else {
      _messages = [
        {
          'sender': 'النظام 🔔',
          'text': '🎉 مرحباً بك! $_myName انضم لـ "$_groupName".',
          'isSystem': true,
        },
        {
          'sender': 'الذكاء الاصطناعي 🤖',
          'text': 'أهلاً يا $_myName! أنا معك في الشلة، نادني بكتابة @ai في أي وقت! ✨',
          'isAI': true,
        }
      ];
      _saveData();
    }
  }

  void _updateGallery() {
    _galleryImages = _messages.where((m) => m['img'] != null).toList();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_chat_data', json.encode(_messages));
    _updateGallery();
  }

  void _sendMessage({String? text, String? audioPath, String? imgPath}) {
    final msgText = text ?? _msgCtrl.text.trim();
    if (msgText.isEmpty && audioPath == null && imgPath == null) return;

    setState(() {
      _messages.add({
        'sender': _myName,
        'userImg': _myImgPath,
        'text': msgText,
        'audio': audioPath,
        'img': imgPath,
        'isMe': true,
        'isAdmin': _isAdmin,
      });
      _msgCtrl.clear();
    });

    _saveData();

    if (msgText.toLowerCase().contains('ai') || msgText.contains('@ai')) {
      _triggerAIResponse(msgText);
    }
  }

  void _triggerAIResponse(String query) {
    setState(() => _typingUser = 'الذكاء الاصطناعي 🤖 يكتب الآن...');

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _typingUser = null;
        _messages.add({
          'sender': 'الذكاء الاصطناعي 🤖',
          'text': 'أهلاً يا $_myName! أنا مستعد لمساعدتك ولخدمة أعضاء الشلة 🚀',
          'isAI': true,
        });
      });
      _saveData();
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _sendMessage(imgPath: image.path);
    }
  }

  Future<void> _toggleAudioRecord() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) _sendMessage(audioPath: path);
    } else {
      if (await _recorder.hasPermission()) {
        await _recorder.start(const RecordConfig(), path: '');
        setState(() => _isRecording = true);
      }
    }
  }

  void _showGroupDetails() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 40, backgroundImage: NetworkImage(_groupIcon)),
              const SizedBox(height: 10),
              Text(_groupName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text("المسؤول: aziz 👑", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
              const Divider(height: 30),
              const Align(
                alignment: Alignment.centerRight,
                child: Text("أعضاء المجموعة:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const CircleAvatar(child: Text("A")),
                title: const Text("aziz"),
                subtitle: const Text("المسؤول الأساسي (Admin)"),
                trailing: const Icon(Icons.star, color: Colors.amber),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: _myImgPath != null ? FileImage(File(_myImgPath!)) as ImageProvider : null,
                  child: _myImgPath == null ? Text(_myName[0]) : null,
                ),
                title: Text(_myName),
                subtitle: Text(_isAdmin ? "مسؤول (أنت)" : "عضو"),
              ),
              const ListTile(
                leading: CircleAvatar(child: Text("🤖")),
                title: Text("الذكاء الاصطناعي"),
                subtitle: Text("مساعد الشلة الذكي"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(radius: 18, backgroundImage: NetworkImage(_groupIcon)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_groupName, style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(_isAdmin ? "أنت الأدمن (aziz) 👑" : "نشط الآن", style: const TextStyle(color: Colors.green, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0084FF),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble), text: "المسنجر"),
            Tab(icon: Icon(Icons.grid_view), text: "معرض بنترست"),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'details') _showGroupDetails();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.group, color: Colors.black50),
                    SizedBox(width: 8),
                    Text('تفاصيل المجموعة والأعضاء'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMessengerView(),
                _buildPinterestView(),
              ],
            ),
          ),
          if (_typingUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(_typingUser!, style: const TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // --- واجهة الشات (مسنجر) ---
  Widget _buildMessengerView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        if (msg['isSystem'] == true) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(15)),
              child: Text(msg['text'], style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          );
        }

        bool isMe = msg['isMe'] ?? false;
        bool isAI = msg['isAI'] ?? false;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF0084FF) : (isAI ? Colors.blue.shade50 : Colors.white),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg['sender'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white70 : Colors.black50,
                      ),
                    ),
                    if (msg['isAdmin'] == true)
                      const Text(" 👑", style: TextStyle(fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                if (msg['text'] != null && msg['text'].toString().isNotEmpty)
                  Text(
                    msg['text'],
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                  ),
                if (msg['img'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(msg['img'])),
                    ),
                  ),
                if (msg['audio'] != null)
                  IconButton(
                    icon: Icon(Icons.play_circle_fill, color: isMe ? Colors.white : Colors.blue, size: 30),
                    onPressed: () => _player.play(DeviceFileSource(msg['audio'])),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- واجهة بنترست (Grid) ---
  Widget _buildPinterestView() {
    if (_galleryImages.isEmpty) {
      return const Center(child: Text("لا توجد صور في المعرض بعد. أرسل صوراً في الشات لتعرض هنا!"));
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.all(10),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: _galleryImages.length,
      itemBuilder: (context, index) {
        final imgMsg = _galleryImages[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black05, blurRadius: 4)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.file(File(imgMsg['img']), fit: BoxFit.cover),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("بواسطة: ${imgMsg['sender']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: _isRecording ? Colors.red : const Color(0xFF0084FF)),
            onPressed: _toggleAudioRecord,
          ),
          IconButton(
            icon: const Icon(Icons.image, color: Color(0xFF0084FF)),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(
                hintText: _isRecording ? 'جاري التسجيل...' : 'اكتب أو نادِ ai...',
                fillColor: Colors.grey[100],
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF0084FF)),
            onPressed: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}
