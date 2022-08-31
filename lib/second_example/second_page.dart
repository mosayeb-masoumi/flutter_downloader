import 'dart:isolate';
import 'dart:ui';
import 'dart:io';
import 'dart:ui';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:device_info/device_info.dart';
import 'package:downloader/data.dart';
import 'package:downloader/download_list_item.dart';
import 'package:downloader/home_page.dart';
import 'package:downloader/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


// url: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4",

// if (await Permission.storage.request().isGranted) {

class SecondPage extends StatefulWidget {

  final TargetPlatform? platform;
  const SecondPage({Key? key, required this.platform}) : super(key: key);

  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {

  List<TaskInfo>? _tasks;
  late List<ItemHolder> _items;
  late bool _loading;
  late bool _permissionReady;
  late String _localPath;
  final ReceivePort _port = ReceivePort();


  List<Model> myList = [];

  @override
  void initState() {
    super.initState();
    createDownloadList();

    _bindBackgroundIsolate();

    FlutterDownloader.registerCallback(downloadCallback, step: 1);

    _loading = true;
    _permissionReady = false;

    _prepare();
  }


  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }


  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloader_send_port',
    );
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      final taskId = (data as List<dynamic>)[0] as String;
      final status = data[1] as DownloadTaskStatus;
      final progress = data[2] as int;

      print(
        'Callback on UI isolate: '
            'task ($taskId) is in status ($status) and process ($progress)',
      );

      if (_tasks != null && _tasks!.isNotEmpty) {
        final task = _tasks!.firstWhere((task) => task.taskId == taskId);
        setState(() {
          task
            ..status = status
            ..progress = progress;
        });
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id,
      DownloadTaskStatus status,
      int progress,) {
    print(
      'Callback on background isolate: '
          'task ($id) is in status ($status) and process ($progress)',
    );

    IsolateNameServer.lookupPortByName('downloader_send_port')
        ?.send([id, status, progress]);
  }


  // Widget _buildDownloadList() =>
  //     ListView(
  //       padding: const EdgeInsets.symmetric(vertical: 16),
  //       children: [
  //         for (final item in _items)
  //           item.task == null
  //               ? _buildListSectionHeading(item.name!)
  //               : DownloadListItem(
  //             data: item,
  //             onTap: (task) async {
  //               final success = await _openDownloadedFile(task);
  //               if (!success) {
  //                 ScaffoldMessenger.of(context).showSnackBar(
  //                   const SnackBar(
  //                     content: Text('Cannot open this file'),
  //                   ),
  //                 );
  //               }
  //             },
  //             onActionTap: (task) {
  //               if (task.status == DownloadTaskStatus.undefined) {
  //                 _requestDownload(task);
  //               } else if (task.status == DownloadTaskStatus.running) {
  //                 _pauseDownload(task);
  //               } else if (task.status == DownloadTaskStatus.paused) {
  //                 _resumeDownload(task);
  //               } else if (task.status == DownloadTaskStatus.complete ||
  //                   task.status == DownloadTaskStatus.canceled) {
  //                 _delete(task);
  //               } else if (task.status == DownloadTaskStatus.failed) {
  //                 _retryDownload(task);
  //               }
  //             },
  //             onCancel: _delete,
  //           ),
  //       ],
  //     );


  // Widget _buildListSectionHeading(String title) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     child: Text(
  //       title,
  //       style: const TextStyle(
  //         fontWeight: FontWeight.bold,
  //         color: Colors.blue,
  //         fontSize: 18,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildNoPermissionWarning() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Grant storage permission to continue',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey, fontSize: 18),
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _retryRequestPermission,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          )
        ],
      ),
    );
  }


  Future<void> _retryRequestPermission() async {
    final hasGranted = await _checkPermission();

    if (hasGranted) {
      await _prepareSaveDir();
    }

    setState(() {
      _permissionReady = hasGranted;
    });
  }

  Future<void> _requestDownload(TaskInfo task) async {
    task.taskId = await FlutterDownloader.enqueue(
      url: task.link!,
      headers: {'auth': 'test_for_sql_encoding'},
      savedDir: _localPath,
      saveInPublicStorage: true,
    );
  }


  Future<void> _pauseDownload(TaskInfo task) async {
    await FlutterDownloader.pause(taskId: task.taskId!);
  }

  Future<void> _resumeDownload(TaskInfo task) async {
    final newTaskId = await FlutterDownloader.resume(taskId: task.taskId!);
    task.taskId = newTaskId;
  }

  Future<void> _retryDownload(TaskInfo task) async {
    final newTaskId = await FlutterDownloader.retry(taskId: task.taskId!);
    task.taskId = newTaskId;
  }

  Future<bool> _openDownloadedFile(TaskInfo? task) {
    if (task != null) {
      return FlutterDownloader.open(taskId: task.taskId!);
    } else {
      return Future.value(false);
    }
  }

  Future<void> _delete(TaskInfo task) async {
    await FlutterDownloader.remove(
      taskId: task.taskId!,
      shouldDeleteContent: true,
    );
    await _prepare();
    setState(() {});
  }


  Future<bool> _checkPermission() async {
    if (Platform.isIOS) {
      return true;
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    if (widget.platform == TargetPlatform.android &&
        androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }


  Future<void> _prepare() async {
    final tasks = await FlutterDownloader.loadTasks();

    if (tasks == null) {
      print('No tasks were retrieved from the database.');
      return;
    }

    var count = 0;
    _tasks = [];
    _items = [];



    // _tasks!.addAll(
    //   DownloadItems.images
    //       .map((image) => TaskInfo(name: image.name, link: image.url)),
    // );
    //
    // _items.add(ItemHolder(name: 'Images'));
    // for (var i = count; i < _tasks!.length; i++) {
    //   _items.add(ItemHolder(name: _tasks![i].name, task: _tasks![i]));
    //   count++;
    // }


    // _tasks!.addAll(
    //   DownloadItems.videos
    //       .map((video) => TaskInfo(name: video.name, link: video.url)),
    // );
    //
    // _items.add(ItemHolder(name: 'Videos'));
    // for (var i = count; i < _tasks!.length; i++) {
    //   _items.add(ItemHolder(name: _tasks![i].name, task: _tasks![i]));
    //   count++;
    // }


    /************************** mine ***************************/
    _tasks!.addAll(
    myList
        .map((item) => TaskInfo(name: item.name, link: item.url)),
    );

    _items.add(ItemHolder(name: 'Videos'));
    for (var i = count; i < _tasks!.length; i++) {
      _items.add(ItemHolder(name: _tasks![i].name, task: _tasks![i]));
      count++;
    }









    // _tasks!.addAll(
    //   DownloadItems.apks
    //       .map((video) => TaskInfo(name: video.name, link: video.url)),
    // );
    //
    // _items.add(ItemHolder(name: 'APKs'));
    // for (var i = count; i < _tasks!.length; i++) {
    //   _items.add(ItemHolder(name: _tasks![i].name, task: _tasks![i]));
    //   count++;
    // }

    for (final task in tasks) {
      for (final info in _tasks!) {
        if (info.link == task.url) {
          info
            ..taskId = task.taskId
            ..status = task.status
            ..progress = task.progress;
        }
      }
    }

    _permissionReady = await _checkPermission();

    if (_permissionReady) {
      await _prepareSaveDir();
    }

    setState(() {
      _loading = false;
    });
  }


  Future<void> _prepareSaveDir() async {
    _localPath = (await _findLocalPath())!;
    final savedDir = Directory(_localPath);
    final hasExisted = savedDir.existsSync();
    if (!hasExisted) {
      await savedDir.create();
    }
  }

  Future<String?> _findLocalPath() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("flutter_downloader"),
        actions: [
          if (Platform.isIOS)
            PopupMenuButton<Function>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              itemBuilder: (context) =>
              [
                PopupMenuItem(
                  onTap: () => exit(0),
                  child: const ListTile(
                    title: Text(
                      'Simulate App Backgrounded',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
      // body: Builder(
      //   builder: (context) {
      //     if (_loading) {
      //       return const Center(child: CircularProgressIndicator());
      //     }
      //
      //     return _permissionReady
      //         ? _buildDownloadList()
      //         : _buildNoPermissionWarning();
      //   },

      body: Center(
        child: ElevatedButton(onPressed: (){

              return _permissionReady
                  ?  downloadFile()
                  : _buildNoPermissionWarning();

        }, child: Text("download"),
      ),

      ),
    );
  }

  downloadFile() async {

    for (var i = 0; i < _items.length; i++) {

      // final success = await _openDownloadedFile(_items[i].task);
      // if(success){
      //   _requestDownload(_items[i].task!);
      // }

      if(_items[i].task != null){
        _requestDownload(_items[i].task!);
      }

    }

    // for (var i = 0; i < myList.length; i++) {
      // final success = await _openDownloadedFile();
      // var taskId = await FlutterDownloader.enqueue(
      //   url: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4",
      //   headers: {'auth': 'test_for_sql_encoding'},
      //   savedDir: _localPath,
      //   saveInPublicStorage: true,
      // );
    // }



    // TaskInfo task = new TaskInfo();
    // _requestDownload(task);
  }



  // Widget _buildDownloadList() =>

      // ListView(
      //   padding: const EdgeInsets.symmetric(vertical: 16),
      //   children: [
      //     for (final item in _items)
      //       item.task == null
      //           ? _buildListSectionHeading(item.name!)
      //           : DownloadListItem(
      //         data: item,
      //         onTap: (task) async {
      //           final success = await _openDownloadedFile(task);
      //           if (!success) {
      //             ScaffoldMessenger.of(context).showSnackBar(
      //               const SnackBar(
      //                 content: Text('Cannot open this file'),
      //               ),
      //             );
      //           }
      //         },
      //         onActionTap: (task) {
      //           if (task.status == DownloadTaskStatus.undefined) {
      //             _requestDownload(task);
      //           } else if (task.status == DownloadTaskStatus.running) {
      //             _pauseDownload(task);
      //           } else if (task.status == DownloadTaskStatus.paused) {
      //             _resumeDownload(task);
      //           } else if (task.status == DownloadTaskStatus.complete ||
      //               task.status == DownloadTaskStatus.canceled) {
      //             _delete(task);
      //           } else if (task.status == DownloadTaskStatus.failed) {
      //             _retryDownload(task);
      //           }
      //         },
      //         onCancel: _delete,
      //       ),
      //   ],
      // );





  void createDownloadList() {

    myList.add(const Model(
      name: 'Big Buck Bunny',
      // url: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      // url: 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4',
      url: 'https://images.template.net/wp-content/uploads/2016/04/27043339/Nature-Wallpaper1.jpg',
    ));
    myList.add(const Model(
      name: 'Elephant Dream',
      // url: 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4',
      url: 'https://www.superiorwallpapers.com/images/lthumbs/2015-11/11290_Golden-leaves-in-this-beautiful-season-Autumn.jpg',
    ));
  }


}







class ItemHolder {
  ItemHolder({this.name, this.task});

  final String? name;
  final TaskInfo? task;
}

class TaskInfo {

  final String? name;
  final String? link;

  TaskInfo({this.name, this.link});


  String? taskId;
  int? progress = 0;
  DownloadTaskStatus? status = DownloadTaskStatus.undefined;
}
