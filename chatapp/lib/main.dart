import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.microphone.request();
  await Permission.camera.request();
  await Permission.photos.request();
  await Permission.storage.request();
  runApp(chat3rak());
}

class chat3rak extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شات العراق',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: Colors.white,
        ),
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
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
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> permissions = await [
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.camera,
    ].request();

    bool allGranted = permissions.values.every((status) => status.isGranted);

    if (!allGranted) {
      _showPermissionDialog();
    } else {
      _navigateToHome();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'الأذونات المطلوبة',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'يحتاج التطبيق إلى أذونات الوصول للميكروفون والصور لتوفير تجربة كاملة في الدردشة.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToHome();
              },
              child: Text('متابعة'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestPermissions();
              },
              child: Text('إعادة المحاولة'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToHome() {
    Future.delayed(Duration(seconds: 1), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ChatWebViewScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[800],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'شات العراق',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'موقع الدردشة الأول في العراق',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 50),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'جاري التحميل...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatWebViewScreen extends StatefulWidget {
  @override
  _ChatWebViewScreenState createState() => _ChatWebViewScreenState();
}

class _ChatWebViewScreenState extends State<ChatWebViewScreen> {
  InAppWebViewController? webViewController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _lastBackPressed;

  void _refreshPage() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    webViewController?.reload();
  }

  Future<void> _openInExternalBrowser() async {
    final url = await webViewController?.getUrl();
    if (url != null) {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<NavigationActionPolicy> _handleNavigationAction(
      InAppWebViewController controller,
      NavigationAction navigationAction) async {
    final url = navigationAction.request.url.toString();

    // فتح روابط Google في المتصفح الخارجي
    if (url.contains('accounts.google.com') ||
        url.contains('oauth.googleusercontent.com') ||
        url.contains('google.com/oauth') ||
        url.contains('googleapis.com/oauth')) {
      // فتح الرابط في المتصفح الخارجي
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }

      // منع فتح الرابط في WebView
      return NavigationActionPolicy.CANCEL;
    }

    // السماح بباقي الروابط
    return NavigationActionPolicy.ALLOW;
  }

  // معالج زر الرجوع
  Future<bool> _onWillPop() async {
    // التحقق من وجود صفحات سابقة في WebView
    if (webViewController != null) {
      bool canGoBack = await webViewController!.canGoBack();

      if (canGoBack) {
        // الرجوع للصفحة السابقة في WebView
        await webViewController!.goBack();
        return false; // منع الخروج من التطبيق
      }
    }

    // إذا لم تكن هناك صفحات سابقة، اسأل المستخدم عن الخروج
    DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > Duration(seconds: 2)) {
      _lastBackPressed = now;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اضغط مرة أخرى للخروج من التطبيق'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue[800],
        ),
      );
      return false; // منع الخروج
    }

    return true; // السماح بالخروج
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            'شات العراق',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _refreshPage,
              tooltip: 'تحديث الصفحة',
            ),
            IconButton(
              icon: Icon(Icons.open_in_browser),
              onPressed: _openInExternalBrowser,
              tooltip: 'فتح في المتصفح',
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[800]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 50,
                      color: Colors.white,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'شات العراق',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'موقع الدردشة الأول في العراق',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.home, color: Colors.blue[800]),
                title: Text('الصفحة الرئيسية'),
                onTap: () {
                  Navigator.pop(context);
                  webViewController?.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri('https://www.chatal3rak.xyz/'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.chat, color: Colors.blue[800]),
                title: Text('الدردشة'),
                onTap: () {
                  Navigator.pop(context);
                  webViewController?.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri('https://www.chatal3rak.xyz/chat/'),
                    ),
                  );
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.privacy_tip, color: Colors.green),
                title: Text('سياسة الخصوصية'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.description, color: Colors.orange),
                title: Text('شروط الاستخدام'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TermsOfServiceScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info, color: Colors.purple),
                title: Text('حول التطبيق'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AboutScreen(),
                    ),
                  );
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.exit_to_app, color: Colors.red),
                title: Text('الخروج'),
                onTap: () {
                  _showExitDialog(context);
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            if (_hasError)
              _buildErrorWidget()
            else
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://www.chatal3rak.xyz/chat/'),
                ),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptEnabled: true,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 10; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
                    clearCache: false,
                    cacheEnabled: true,
                    supportZoom: false,
                  ),
                  android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                    thirdPartyCookiesEnabled: true,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    useWideViewPort: true,
                    domStorageEnabled: true,
                  ),
                  ios: IOSInAppWebViewOptions(
                    allowsInlineMediaPlayback: true,
                    allowsBackForwardNavigationGestures: true,
                  ),
                ),
                androidOnPermissionRequest:
                    (controller, origin, resources) async {
                  return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT,
                  );
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return _handleNavigationAction(controller, navigationAction);
                },
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    _isLoading = false;
                  });
                },
                onLoadError: (controller, url, code, message) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                  });
                },
                onConsoleMessage: (controller, consoleMessage) {
                  // طباعة رسائل وحدة التحكم للتشخيص
                  print("Console: ${consoleMessage.message}");
                },
              ),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'جاري تحميل الموقع...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
            SizedBox(height: 20),
            Text(
              'خطأ في تحميل الموقع',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _refreshPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                'إعادة المحاولة',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'تأكيد الخروج',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'هل تريد الخروج من التطبيق؟',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: Text('خروج', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سياسة الخصوصية'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سياسة الخصوصية',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'نحن في شات العراق نحترم خصوصيتك ونلتزم بحماية معلوماتك الشخصية. توضح هذه السياسة كيفية جمع واستخدام وحماية المعلومات التي تقدمها لنا.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 20),
            _buildSection(
              'جمع المعلومات',
              'نحن نجمع المعلومات التي تقدمها لنا طوعاً عند:\n'
                  '• التسجيل في الموقع\n'
                  '• المشاركة في الدردشة\n'
                  '• الاتصال بخدمة العملاء\n'
                  '• استخدام ميزات الموقع المختلفة',
            ),
            _buildSection(
              'استخدام المعلومات',
              'نستخدم المعلومات المجمعة للأغراض التالية:\n'
                  '• توفير وتحسين خدماتنا\n'
                  '• التواصل معك\n'
                  '• ضمان الأمان والحماية\n'
                  '• الامتثال للقوانين واللوائح',
            ),
            _buildSection(
              'حماية المعلومات',
              'نحن نتخذ تدابير أمنية مناسبة لحماية معلوماتك من الوصول غير المصرح به أو التغيير أو الكشف أو التدمير. تشمل هذه التدابير:\n'
                  '• التشفير الآمن للبيانات\n'
                  '• جدران الحماية المتقدمة\n'
                  '• المراقبة المستمرة للأنظمة\n'
                  '• التدريب المنتظم للموظفين',
            ),
            _buildSection(
              'مشاركة المعلومات',
              'نحن لا نبيع أو نؤجر أو نشارك معلوماتك الشخصية مع أطراف ثالثة إلا في الحالات التالية:\n'
                  '• بموافقتك الصريحة\n'
                  '• للامتثال للقوانين\n'
                  '• لحماية حقوقنا وحقوق المستخدمين\n'
                  '• في حالات الطوارئ',
            ),
            _buildSection(
              'حقوقك',
              'لديك الحق في:\n'
                  '• الوصول إلى معلوماتك الشخصية\n'
                  '• تصحيح المعلومات غير الدقيقة\n'
                  '• حذف معلوماتك الشخصية\n'
                  '• الاعتراض على معالجة معلوماتك\n'
                  '• نقل معلوماتك إلى خدمة أخرى',
            ),
            _buildSection(
              'ملفات تعريف الارتباط',
              'نستخدم ملفات تعريف الارتباط (الكوكيز) لتحسين تجربتك على موقعنا. يمكنك التحكم في هذه الملفات من خلال إعدادات متصفحك.',
            ),
            _buildSection(
              'التحديثات',
              'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر. سنقوم بإشعارك بأي تغييرات مهمة عبر الموقع أو البريد الإلكتروني.',
            ),
            _buildSection(
              'الاتصال بنا',
              'إذا كان لديك أي أسئلة حول سياسة الخصوصية هذه، يرجى الاتصال بنا عبر:\n'
                  '• البريد الإلكتروني: privacy@chatal3rak.xyz\n'
                  '• الهاتف: +964 XXX XXX XXXX',
            ),
            SizedBox(height: 20),
            Text(
              'تاريخ آخر تحديث: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('شروط الاستخدام'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'شروط الاستخدام',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'مرحباً بك في شات العراق. باستخدامك لهذا الموقع، فإنك توافق على الالتزام بشروط الاستخدام التالية.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 20),
            _buildSection(
              'قبول الشروط',
              'باستخدام موقع شات العراق، فإنك تقر بأنك قد قرأت وفهمت ووافقت على جميع شروط وأحكام الاستخدام هذه.',
            ),
            _buildSection(
              'الاستخدام المقبول',
              'يجب عليك استخدام الموقع بطريقة مناسبة ومسؤولة. يُمنع منعاً باتاً:\n'
                  '• استخدام لغة مسيئة أو غير لائقة\n'
                  '• نشر محتوى مخالف للآداب العامة\n'
                  '• التحرش بالمستخدمين الآخرين\n'
                  '• نشر معلومات شخصية للآخرين\n'
                  '• استخدام الموقع لأغراض تجارية دون إذن\n'
                  '• محاولة اختراق أو تخريب الموقع',
            ),
            _buildSection(
              'التسجيل والحساب',
              'عند التسجيل في الموقع، يجب عليك:\n'
                  '• تقديم معلومات صحيحة ودقيقة\n'
                  '• الحفاظ على سرية كلمة المرور\n'
                  '• عدم مشاركة حسابك مع الآخرين\n'
                  '• إبلاغنا فوراً عن أي استخدام غير مصرح به لحسابك',
            ),
            _buildSection(
              'المحتوى والمسؤولية',
              'أنت مسؤول عن جميع المحتويات التي تنشرها على الموقع. نحن نحتفظ بالحق في:\n'
                  '• مراجعة ومراقبة المحتوى\n'
                  '• حذف أي محتوى مخالف\n'
                  '• تعليق أو إنهاء الحسابات المخالفة\n'
                  '• اتخاذ الإجراءات القانونية اللازمة',
            ),
            _buildSection(
              'الخصوصية والأمان',
              'نحن ملتزمون بحماية خصوصيتك وأمان معلوماتك. يرجى مراجعة سياسة الخصوصية الخاصة بنا لمزيد من التفاصيل.',
            ),
            _buildSection(
              'التعديلات على الشروط',
              'نحن نحتفظ بالحق في تعديل هذه الشروط في أي وقت. سيتم إشعارك بأي تغييرات مهمة، واستمرارك في استخدام الموقع يعني موافقتك على الشروط المحدثة.',
            ),
            _buildSection(
              'إنهاء الخدمة',
              'نحن نحتفظ بالحق في إنهاء أو تعليق حسابك في أي وقت إذا:\n'
                  '• انتهكت شروط الاستخدام\n'
                  '• تصرفت بطريقة تضر بالموقع أو المستخدمين\n'
                  '• طلبت إنهاء حسابك بنفسك',
            ),
            _buildSection(
              'إخلاء المسؤولية',
              'الموقع متاح "كما هو" دون أي ضمانات. نحن غير مسؤولين عن:\n'
                  '• أي أضرار مباشرة أو غير مباشرة\n'
                  '• فقدان البيانات أو الأرباح\n'
                  '• انقطاع الخدمة\n'
                  '• أخطاء أو عيوب في الموقع',
            ),
            _buildSection(
              'القانون المعمول به',
              'تخضع هذه الشروط لقوانين جمهورية العراق، وأي نزاع ينشأ عنها سيتم حله في المحاكم العراقية المختصة.',
            ),
            _buildSection(
              'الاتصال بنا',
              'إذا كان لديك أي أسئلة حول شروط الاستخدام، يرجى الاتصال بنا عبر:\n'
                  '• البريد الإلكتروني: support@chatal3rak.xyz\n'
                  '• الهاتف: +964 XXX XXX XXXX',
            ),
            SizedBox(height: 20),
            Text(
              'تاريخ آخر تحديث: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('حول التطبيق'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 100,
              color: Colors.blue[800],
            ),
            SizedBox(height: 20),
            Text(
              'شات العراق',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'موقع الدردشة الأول في العراق',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 30),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معلومات التطبيق',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 15),
                    _buildInfoRow('الإصدار', '1.0.0'),
                    _buildInfoRow('تاريخ الإصدار', '2024'),
                    _buildInfoRow('المطور', 'فريق شات العراق'),
                    _buildInfoRow('الموقع الإلكتروني', 'www.chatal3rak.xyz'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عن التطبيق',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'شات العراق هو منصة الدردشة الرائدة في العراق، نوفر بيئة آمنة وودية للتواصل والدردشة بين العراقيين من جميع أنحاء العالم.',
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'مميزات التطبيق:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildFeature('دردشة مباشرة وسريعة'),
                    _buildFeature('واجهة سهلة الاستخدام'),
                    _buildFeature('حماية وخصوصية عالية'),
                    _buildFeature('دعم للغة العربية بالكامل'),
                    _buildFeature('إمكانية مشاركة الصور والملفات'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تواصل معنا',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 15),
                    _buildContactInfo(Icons.email, 'البريد الإلكتروني',
                        'info@chatal3rak.xyz'),
                    _buildContactInfo(
                        Icons.phone, 'الهاتف', '+964 XXX XXX XXXX'),
                    _buildContactInfo(
                        Icons.web, 'الموقع الإلكتروني', 'www.chatal3rak.xyz'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            Text(
              'جميع الحقوق محفوظة © 2024 شات العراق',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(String feature) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.blue[700],
            size: 24,
          ),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
