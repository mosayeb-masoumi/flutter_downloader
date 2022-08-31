import 'package:downloader/home_page.dart';
import 'package:downloader/second_example/second_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    final platform = Theme.of(context).platform;

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: HomePage(platform: platform,),
      // home: SecondPage(platform: platform,),
    );
  }
}