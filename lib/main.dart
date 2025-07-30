import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  runApp(const ZiraHomesApp());
}

class ZiraHomesApp extends StatelessWidget {
  const ZiraHomesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZiraHomes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isConnected = true;
  bool _showFAB = true; // Controls FAB visibility

  /// Checks for active internet connection
  Future<void> _checkConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  /// Toast helper
  void _showToast(String message) {
    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM);
  }

  /// Capture image from camera for <input type="file">
  Future<List<String>> _captureFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showToast('Camera permission denied');
      return [];
    }
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) {
        _showToast('No image captured');
        return [];
      }
      _showToast('Photo captured for upload');
      return [image.path];
    } catch (e) {
      _showToast('Error opening camera: $e');
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _checkConnection();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      final hasInternet = result != ConnectivityResult.none;
      if (hasInternet != _isConnected) {
        setState(() {
          _isConnected = hasInternet;
        });
        if (hasInternet) {
          _controller.reload(); // reload webview when back online
        }
      }
    });

    // Choose correct platform controller
    PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS-specific settings
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params)
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                // Show FAB only if not on login page
                setState(() {
                  _showFAB = url != "https://zira-homes.com/index.php";
                });
              },
              onNavigationRequest: (NavigationRequest request) async {
                final url = request.url;

                if (url.startsWith('tel:') || url.startsWith('mailto:')) {
                  final uri = Uri.parse(url);
                  _showToast('Opening external application…');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                  return NavigationDecision.prevent;
                }

                if (url.contains('payment-success')) {
                  _showToast('Payment received successfully');
                }
                if (url.contains('rent-due')) {
                  _showToast('Rent is due');
                }

                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse('https://zira-homes.com'));

    // Android: intercept <input type="file">
    if (controller.platform is AndroidWebViewController) {
      final AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;

      AndroidWebViewController.enableDebugging(true);

      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        return await _captureFromCamera();
      });
    }

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isConnected
            ? WebViewWidget(controller: _controller)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '📡',
                      style: TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'You are offline',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Please check your internet connection\nand try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      onPressed: () async {
                        await _checkConnection();
                        if (_isConnected) {
                          _controller.reload();
                        }
                      },
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: _showFAB && _isConnected
    ? Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center horizontally
          children: [
            FloatingActionButton(
              heroTag: "apartments_btn",
              tooltip: 'Apartments',
              child: const Icon(Icons.apartment),
              onPressed: () {
                _controller.loadRequest(Uri.parse(
                    'https://zira-homes.com/landlord/apartments_list.php'));
              },
            ),
            const SizedBox(width: 30), // More space between buttons
            FloatingActionButton(
              heroTag: "invoices_btn",
              tooltip: 'Invoices',
              child: const Icon(Icons.receipt_long),
              onPressed: () {
                _controller.loadRequest(Uri.parse(
                    'https://zira-homes.com/landlord/invoices.php'));
              },
            ),
          ],
        ),
      )
    : null,

    );
  }
}
