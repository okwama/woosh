import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart';

class UpdatePageWidget extends StatefulWidget {
  const UpdatePageWidget({super.key});

  static String routeName = 'UpdatePage';
  static String routePath = '/updatePage';

  @override
  State<UpdatePageWidget> createState() => _UpdatePageWidgetState();
}

class _UpdatePageWidgetState extends State<UpdatePageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: appBackground,
        appBar: GradientAppBar(
          title: 'Update Page',
          automaticallyImplyLeading: false,
          centerTitle: false,
          elevation: 2,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Add your content here
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.system_update,
                        size: 80,
                        color: goldMiddle2,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Update Available',
                        style: GoogleFonts.interTight(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: blackColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A new version is available for download',
                        style: GoogleFonts.interTight(
                          fontSize: 16,
                          color: accentGrey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      GoldGradientButton(
                        onPressed: () {
                          // Handle update action
                        },
                        child: const Text(
                          'Update Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
