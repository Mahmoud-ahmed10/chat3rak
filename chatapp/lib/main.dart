import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // متغير لتتبع حالة الرجوع
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // تحسين User Agent لدعم Google Sign-In
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            print('Page started loading: $url');
            _updateBackButtonState();
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            print('Page finished loading: $url');
            _updateBackButtonState();

            // حقن JavaScript محسن
            _injectGoogleSignInFix();
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
          // معالجة محسنة للروابط
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request: ${request.url}');

            // السماح للروابط العادية
            if (request.url.contains('chatal3rak.xyz')) {
              return NavigationDecision.navigate;
            }

            // التعامل مع روابط Google
            if (_isGoogleUrl(request.url)) {
              print('Google URL detected: ${request.url}');
              _handleGoogleSignIn(request.url);
              return NavigationDecision.prevent;
            }

            // للروابط الخارجية الأخرى
            if (request.url.startsWith('http') &&
                !request.url.contains('chatal3rak.xyz')) {
              _launchExternalUrl(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.chatal3rak.xyz/chat/'));
  }

  // تحديث حالة زر الرجوع
  Future<void> _updateBackButtonState() async {
    try {
      bool canGoBack = await _webViewController.canGoBack();
      setState(() {
        _canGoBack = canGoBack;
      });
    } catch (e) {
      print('Error checking back button state: $e');
    }
  }

  // معالجة زر الرجوع
  Future<bool> _handleBackButton() async {
    try {
      if (_canGoBack) {
        await _webViewController.goBack();
        return false; // لا تخرج من التطبيق
      } else {
        // إذا لم يكن هناك صفحة للرجوع إليها، اعرض رسالة تأكيد الخروج
        return await _showExitConfirmationDialog();
      }
    } catch (e) {
      print('Error handling back button: $e');
      return await _showExitConfirmationDialog();
    }
  }

  // حوار تأكيد الخروج
  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
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
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('خروج'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // تحقق محسن من روابط Google
  bool _isGoogleUrl(String url) {
    List<String> googleDomains = [
      'accounts.google.com',
      'oauth2.googleapis.com',
      'www.googleapis.com',
      'signin.googleapis.com',
      'accounts.youtube.com'
    ];

    return googleDomains.any((domain) => url.contains(domain)) ||
        url.contains('oauth') ||
        url.contains('google') && url.contains('auth');
  }

  // معالج محسن لتسجيل الدخول بـ Google
  void _handleGoogleSignIn(String url) async {
    print('Handling Google Sign-In: $url');

    // عرض رسالة للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري فتح تسجيل الدخول بـ Google...'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue[800],
      ),
    );

    try {
      final Uri uri = Uri.parse(url);
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );

      if (launched) {
        print('Successfully launched Google Sign-In');

        // انتظار قصير ثم إعادة تحميل الصفحة
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            _refreshPage();
          }
        });
      } else {
        print('Failed to launch Google Sign-In');
        _showManualSignInDialog();
      }
    } catch (e) {
      print('Error launching Google Sign-In: $e');
      _showManualSignInDialog();
    }
  }

  // فتح روابط خارجية
  void _launchExternalUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error launching external URL: $e');
    }
  }

  // حقن JavaScript محسن
  void _injectGoogleSignInFix() {
    String jsCode = '''
      console.log('Injecting Google Sign-In fix...');
      
      // تحسين User Agent
      if (navigator.userAgent.indexOf('wv') !== -1) {
        Object.defineProperty(navigator, 'userAgent', {
          get: function() {
            return 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
          }
        });
      }
      
      // إزالة WebView indicators
      Object.defineProperty(navigator, 'webdriver', {
        get: function() { return false; }
      });
      
      // تحسين Google Sign-In
      function enhanceGoogleSignIn() {
        // البحث عن أزرار Google Sign-In
        const selectors = [
          'button[data-provider="google"]',
          'a[href*="google"]',
          'button[class*="google"]',
          'div[data-provider="google"]',
          '[role="button"][aria-label*="Google"]',
          'button:contains("Google")',
          'a:contains("Google")'
        ];
        
        selectors.forEach(selector => {
          try {
            const elements = document.querySelectorAll(selector);
            elements.forEach(element => {
              console.log('Found Google sign-in element:', element);
              
              element.addEventListener('click', function(e) {
                console.log('Google sign-in clicked');
                // السماح للحدث بالتنفيذ بشكل طبيعي
                // لا نمنعه هنا
              });
            });
          } catch (error) {
            console.log('Error processing selector:', selector, error);
          }
        });
      }
      
      // تشغيل التحسينات
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', enhanceGoogleSignIn);
      } else {
        enhanceGoogleSignIn();
      }
      
      // مراقبة التغييرات في DOM
      const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          if (mutation.addedNodes.length > 0) {
            enhanceGoogleSignIn();
          }
        });
      });
      
      observer.observe(document.body, {
        childList: true,
        subtree: true
      });
      
      console.log('Google Sign-In enhancement complete');
    ''';

    _webViewController.runJavaScript(jsCode);
  }

  // حوار إرشادي للتسجيل الدليل
  void _showManualSignInDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[800]),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تسجيل الدخول بـ Google',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إذا لم يعمل تسجيل الدخول بـ Google تلقائياً، يمكنك:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 15),
              _buildInstructionStep('1', 'فتح الموقع في المتصفح الخارجي'),
              _buildInstructionStep('2', 'تسجيل الدخول بحساب Google'),
              _buildInstructionStep('3', 'العودة للتطبيق وتحديث الصفحة'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('موافق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openInExternalBrowser();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
              child: Text('فتح في المتصفح'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[800],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // فتح الموقع في متصفح خارجي
  Future<void> _openInExternalBrowser() async {
    final Uri uri = Uri.parse('https://www.chatal3rak.xyz/chat/');
    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم فتح الموقع في المتصفح الخارجي'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('خطأ في فتح المتصفح: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ في فتح المتصفح'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshPage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _webViewController.reload();
      _updateBackButtonState();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الصفحة'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error refreshing page: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackButton,
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
        drawer: _buildDrawer(context),
        body: Stack(
          children: [
            if (_hasError)
              _buildErrorWidget()
            else
              WebViewWidget(controller: _webViewController),
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
              mainAxisAlignment: MainAxisAlignment.center,
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
                  'موقع الدردشة الأول',
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
            title: Text(
              'الصفحة الرئيسية',
              style: TextStyle(fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              _webViewController
                  .loadRequest(Uri.parse('https://www.chatal3rak.xyz/chat/'));
            },
          ),
          ListTile(
            leading: Icon(Icons.open_in_browser, color: Colors.green[700]),
            title: Text(
              'فتح في المتصفح',
              style: TextStyle(fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              _openInExternalBrowser();
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: Colors.green[700]),
            title: Text(
              'سياسة الخصوصية',
              style: TextStyle(fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PolicyScreen(
                    title: 'سياسة الخصوصية',
                    content: _getPrivacyPolicyContent(),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.description, color: Colors.orange[700]),
            title: Text(
              'شروط الاستخدام',
              style: TextStyle(fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PolicyScreen(
                    title: 'شروط الاستخدام',
                    content: _getTermsContent(),
                  ),
                ),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info, color: Colors.blue[700]),
            title: Text(
              'حول التطبيق',
              style: TextStyle(fontSize: 16),
            ),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red[700]),
            title: Text(
              'خروج',
              style: TextStyle(fontSize: 16),
            ),
            onTap: () {
              _showExitDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'حول التطبيق',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: Colors.blue[800],
              ),
              SizedBox(height: 20),
              Text(
                'شات العراق',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'الإصدار 1.2.1',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'تطبيق الدردشة الأول في العراق\nيوفر تجربة دردشة آمنة وممتعة\nمع دعم محسن لتسجيل الدخول بـ Google\nودعم متطور لزر الرجوع',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  void _showExitDialog() {
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
            'هل أنت متأكد من رغبتك في الخروج من التطبيق؟',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: Text('خروج'),
            ),
          ],
        );
      },
    );
  }

  String _getPrivacyPolicyContent() {
    return '''
سياسة الخصوصية - شات العراق

آخر تحديث: يونيو 2025

نحن في شات العراق نلتزم بحماية خصوصيتك وبياناتك الشخصية. توضح هذه السياسة كيفية جمع واستخدام وحماية المعلومات التي تقدمها لنا.

1. المعلومات التي نجمعها:
- المعلومات الشخصية التي تقدمها طوعياً (الاسم، البريد الإلكتروني)
- معلومات الاستخدام والتصفح
- ملكات تعريف الارتباط (Cookies)

2. كيفية استخدام المعلومات:
- تحسين تجربة المستخدم
- توفير خدمات الدردشة
- الحماية من الاستخدام غير المشروع

3. حماية البيانات:
- نستخدم تقنيات التشفير المتقدمة
- لا نشارك بياناتك مع أطراف ثالثة
- نحافظ على سرية محادثاتك

4. حقوقك:
- حق الوصول إلى بياناتك
- حق تصحيح المعلومات
- حق حذف البيانات

5. التواصل معنا:
إذا كان لديك أي استفسارات حول سياسة الخصوصية، يرجى التواصل معنا.

نحتفظ بالحق في تحديث هذه السياسة من وقت لآخر.
''';
  }

  String _getTermsContent() {
    return '''
شروط الاستخدام - شات العراق

آخر تحديث: يونيو 2025

مرحباً بك في شات العراق. باستخدامك لهذا التطبيق، فإنك توافق على الشروط والأحكام التالية:

1. القواعد العامة:
- يجب أن تكون 18 سنة أو أكثر لاستخدام التطبيق
- احترام المستخدمين الآخرين في جميع الأوقات
- عدم نشر محتوى مخالف للقانون أو مسيء

2. السلوك المقبول:
- استخدام لغة مهذبة ومحترمة
- عدم التحرش أو التنمر
- احترام الخصوصية الشخصية للآخرين

3. المحتوى المحظور:
- المحتوى الإباحي أو الجنسي
- خطاب الكراهية أو العنصرية
- المحتوى المخالف للقانون العراقي

4. الخصوصية والأمان:
- لا تشارك معلوماتك الشخصية الحساسة
- أبلغ عن أي سلوك مشبوه أو مخالف
- نحتفظ بالحق في مراقبة المحادثات للحماية

5. المسؤولية:
- أنت مسؤول عن المحتوى الذي تنشره
- نحتفظ بالحق في إزالة المحتوى المخالف
- يمكننا حظر المستخدمين المخالفين

6. التحديثات:
- نحتفظ بالحق في تحديث هذه الشروط
- ستتم إعلامك بأي تغييرات مهمة

7. إنهاء الخدمة:
- يمكنك إنهاء استخدام التطبيق في أي وقت
- نحتفظ بالحق في إنهاء الخدمة لأي مستخدم

باستخدامك للتطبيق، فإنك تؤكد موافقتك على هذه الشروط.

للاستفسارات، يرجى التواصل معنا.
''';
  }
}

class PolicyScreen extends StatelessWidget {
  final String title;
  final String content;

  const PolicyScreen({
    Key? key,
    required this.title,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    title.contains('الخصوصية')
                        ? Icons.privacy_tip
                        : Icons.description,
                    size: 50,
                    color: Colors.blue[800],
                  ),
                  SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'العودة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
