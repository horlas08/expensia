import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:animate_do/animate_do.dart';

class HtmlContentPage extends StatelessWidget {
  final String title;
  final String assetPath;

  const HtmlContentPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.onSurface,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading content: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final htmlContent = snapshot.data ?? '';

          return FadeIn(
            duration: const Duration(milliseconds: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: HtmlWidget(
                htmlContent,
                textStyle: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  height: 1.6,
                ),
                customStylesBuilder: (element) {
                  if (element.localName == 'h1') {
                    return {'font-weight': 'bold', 'font-size': '24px', 'margin-bottom': '16px'};
                  }
                  if (element.localName == 'h2') {
                    return {'font-weight': 'bold', 'font-size': '20px', 'margin-top': '24px', 'margin-bottom': '12px'};
                  }
                  if (element.localName == 'p') {
                    return {'margin-bottom': '12px'};
                  }
                  return null;
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
