import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:ext_storage/ext_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:galileov3/googleDrive.dart';
import 'package:galileov3/main.dart';
import 'dart:ui' as ui;
import 'package:zoom_widget/zoom_widget.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:dropbox_client/dropbox_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String dropbox_clientId = DotEnv().env['APP_KEY'];
String dropbox_key = DotEnv().env['APP_KEY'];
String dropbox_secret = DotEnv().env['APP_SECRET'];

class Edit extends StatefulWidget {
  final File image;

  const Edit({Key key, this.image}) : super(key: key);

  @override
  _EditState createState() => _EditState();
}

class _EditState extends State<Edit> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _zoomWidget = GlobalKey();
  ui.Image _image;
  //touch positions on screen
  double xPos = 0.0;
  double yPos = 0.0;
  double temp, humidity;
  double _width = 10;
  double _height = 10;
  int selectedIndex = -1;
  String fileName = "";
  String editText = "";
  bool editMode = false;
  Color pickerColor = Color(0xff443a49);
  Color currentColor = Color(0xff443a49);
  LongPressStartDetails _tapPosition;
  String accessToken = "";
  double x;
  List<Oval> objects = new List();
  final drive = GoogleDrive();
  final storage = FlutterSecureStorage();

  @override
  void initState() {
    _loadImage();
    initDropbox();
  }

  //intialize dropBox
  Future initDropbox() async {
    await Dropbox.init(dropbox_clientId, dropbox_key, dropbox_secret);

    accessToken = await storage.read(key: "dropboxAccessToken");
  }

  _loadImage() async {
    try {
      final Uint8List bytes = await widget.image.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.Image image = (await codec.getNextFrame()).image;
      setState(() {
        _image = image;
      });
    } catch (e) {
      print(e);
    }
  }

  void showInSnackBar(String value) {
    _scaffoldKey.currentState.showSnackBar(new SnackBar(
        content: new Text(value),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5)))));
  }

  Future<bool> checkAuthorized(bool authorize) async {
    final token = await Dropbox.getAccessToken();

    if (token != null) {
      if (accessToken == null || accessToken.isEmpty) {
        setState(() {
          accessToken = token;
        });
        storage.write(key: 'dropboxAccessToken', value: accessToken);
      }
      return true;
    }
    if (authorize) {
      if (accessToken != null && accessToken.isNotEmpty) {
        await Dropbox.authorizeWithAccessToken(accessToken);
        final token = await Dropbox.getAccessToken();
        if (token != null) {
          return true;
        }
      } else {
        await Dropbox.authorize();
      }
    }
    return false;
  }

  Future uploadDropBox() async {
    if (await checkAuthorized(true)) {
      String directory = await ExtStorage.getExternalStoragePublicDirectory(
          ExtStorage.DIRECTORY_DOCUMENTS);
      String path = directory + "/galileo1" + '/${fileName}.png';

      if (FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound) {
        final result = await Dropbox.upload(path, '/' + '${fileName}.png',
            (uploaded, total) {
          print('progress $uploaded / $total');
        });
        print("test");
        print(result);
        showInSnackBar("File uploaded to dropbox");
      } else {
        showInSnackBar("File not found..please save locally first");
      }
    }
  }

  uploadDrive() async {
    String directory = await ExtStorage.getExternalStoragePublicDirectory(
        ExtStorage.DIRECTORY_DOCUMENTS);
    String path = directory + "/galileo1" + '/${fileName}.png';
    File upload = new File(path);
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound) {
      showInSnackBar("Uploading please wait...");
      var res = await drive.upload(upload);
      if (res != null)
        showInSnackBar("File uploaded to drive ");
      else {
        showInSnackBar("Failed to upload");
      }
    } else {
      showInSnackBar("File not found..please save locally first");
    }
  }

  //saving canvas to PNG file
  void saveImage() async {
    showInSnackBar("Saving image...");
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    ImageEditor painter = ImageEditor(this._image, objects);
    Size s = new Size(_image.width.toDouble(), _image.height.toDouble());
    painter.paint(canvas, s);
    ui.Image img =
        await recorder.endRecording().toImage(_image.width, _image.height);

    final pngBytes = await img.toByteData(format: ImageByteFormat.png);
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    try {
      if (status.isGranted) {
        print("check saving");
        String directory = await ExtStorage.getExternalStoragePublicDirectory(
            ExtStorage.DIRECTORY_DOCUMENTS);
        String path = directory + "/galileo1";

        await Directory('$path').create(recursive: true);

        File upload = await File('$path/${fileName}.png')
            .writeAsBytes(pngBytes.buffer.asInt8List());
        showInSnackBar("Saved at " + upload.path);
      }
    } catch (e) {
      print(e);
      showInSnackBar("Failed to get documents directory");
    }
  }

  showBackAlertDialog(BuildContext context) {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MyApp()));
      },
    );

    Widget closeButton = FlatButton(
      child: Text("NO"),
      onPressed: () async {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Are you sure ?"),
      actions: [closeButton, okButton],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  showColorPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color!'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: currentColor,
              onColorChanged: changeColor,
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: const Text('Got it'),
              onPressed: () {
                setState(() => currentColor = pickerColor);
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
          ],
        );
      },
    );
  }

  showCircleRadiusAlertDialog() {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("Done"),
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    Widget field = SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FlatButton(
                child: Text("Choose color"),
                color: Colors.red,
                onPressed: () {
                  showColorPickerDialog();
                }),
          ),
          Text("Width"),
          Container(
            height: 50,
            width: 300,
            child: FlutterSlider(
              values: [_width],
              max: 300,
              min: 10,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                setState(() {
                  _width = lowerValue;
                });
              },
              jump: true,
            ),
          ),
          Text("Height"),
          Container(
            height: 50,
            width: 300,
            child: FlutterSlider(
              values: [_height],
              max: 300,
              min: 10,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                setState(() {
                  _height = lowerValue;
                });
              },
              jump: true,
            ),
          ),
        ],
      ),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Circle radius And Color"),
      actions: [okButton],
      content: field,
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  showEditAlertDialog() {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("Save Changes"),
      onPressed: () {
        var obj = objects.elementAt(selectedIndex);
        setState(() {
          if (editText != "") {
            obj.text = editText;
          }
          if (pickerColor != null) {
            obj.color = pickerColor;
          }
        });
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    Widget field = SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FlatButton(
                child: Text("edit color"),
                color: Colors.red,
                onPressed: () {
                  showColorPickerDialog();
                }),
          ),
          Text("Enter text"),
          TextField(
            onChanged: (text) {
              setState(() {
                editText = text;
              });
            },
          )
        ],
      ),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Edit color and text"),
      actions: [okButton],
      content: field,
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  showTextAlertDialog() {
    // set up the button
    Widget okButton = FlatButton(
      child: Text("Ok"),
      onPressed: () {
        double xPosUpdated = xPos + _image.height.toDouble() * 0.025;
        double yPosUpdated = yPos + _image.height.toDouble() * 0.045;
        int angle = 0;
        if (_height > _width) angle = 90;
        if (editText != "" && pickerColor != null) {
          Oval o = new Oval(pickerColor, xPosUpdated, yPosUpdated, _width,
              _height, editText, angle);
          setState(() {
            objects.add(o);
            editText = "";
          });
        } else {
          if (editText == null || editText == "") {
            showInSnackBar("Text cannot be empty");
          } else {
            showInSnackBar("Please select a color");
          }
        }

        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    Widget field = SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Text("Enter text"),
          TextField(
            onChanged: (text) {
              setState(() {
                editText = text;
              });
            },
          )
        ],
      ),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Text value"),
      actions: [okButton],
      content: field,
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  showSaveFileAlertDialog() {
    Widget uploadGdrive = FlatButton(
        color: Colors.green,
        child: Text("Upload to drive"),
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          if (fileName != "") {
            await uploadDrive();
          } else {
            showInSnackBar("Invalid file name");
          }
        });
    Widget logoutDrive = FlatButton(
        color: Colors.blueGrey,
        child: Text("Logout drive"),
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          await storage.delete(key: "type");
          await storage.delete(key: "data");
          await storage.delete(key: "expiry");
          await storage.delete(key: "refreshToken");
          showInSnackBar("Logged out from drive");
        });
    Widget logoutDropbox = FlatButton(
        color: Colors.blueGrey,
        child: Text("Logout dropbox"),
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            accessToken = null;
          });
          await storage.delete(key: "dropboxAccessToken");
          showInSnackBar("Logged out from dropbox");
          await Dropbox.unlink();
        });
    Widget saveLocal = FlatButton(
        color: Colors.teal,
        child: Text("Save Locally"),
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          if (fileName != "") {
            saveImage();
          } else {
            showInSnackBar("Invalid file name");
          }
        });
    Widget uploadBox = FlatButton(
        color: Colors.blueAccent,
        child: Text("Upload to dropbox"),
        onPressed: () async {
          Navigator.of(context, rootNavigator: true).pop();
          if (fileName != "") {
            uploadDropBox();
          } else {
            showInSnackBar("Invalid file name");
          }
        });
    Widget cancelButton = FlatButton(
      color: Colors.red,
      child: Text("Cancel"),
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    Widget field = SingleChildScrollView(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("File Name"),
            TextFormField(
              initialValue: fileName,
              onChanged: (text) {
                setState(() {
                  fileName = text;
                });
              },
            ),
            saveLocal,
            uploadBox,
            uploadGdrive,
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: logoutDropbox,
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: logoutDrive,
                )
              ],
            )
          ]),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("File options"),
      actions: [
        cancelButton,
      ],
      content: field,
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  //change picked color
  void changeColor(Color color) {
    setState(() => pickerColor = color);
  }

  @override
  dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      resizeToAvoidBottomPadding: false,
      body: Container(
          child: _image != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ButtonBar(
                        alignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          FlatButton(
                            color: Colors.black,
                            child: Text("Back",
                                style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              showBackAlertDialog(context);
                            },
                          ),
                          FlatButton(
                            color: Colors.amber,
                            child: Text(!editMode ? "Edit Mode" : "close",
                                style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              setState(() {
                                editMode = !editMode;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Zoom(
                          key: _zoomWidget,
                          doubleTapZoom: true,
                          initZoom: 0.0,
                          zoomSensibility: 8,
                          backgroundColor: Colors.transparent,
                          width: _image.width.toDouble(),
                          height: _image.height.toDouble(),
                          child: GestureDetector(
                            onLongPressStart: (details) {
                              setState(() {
                                _tapPosition = details;
                              });
                            },
                            onLongPress: () {
                              xPos = _tapPosition.localPosition.dx -
                                  _image.height.toDouble() * 0.03;
                              yPos = _tapPosition.localPosition.dy -
                                  _image.height.toDouble() * 0.05;
                            },
                            onTapDown: (details) {
                              if (editMode) {
                                if (objects.length > 0) {
                                  final index = objects.lastIndexWhere((obj) {
                                    final rect = Rect.fromCenter(
                                        center: Offset(obj.x, obj.y),
                                        height: obj.height,
                                        width: obj.width);
                                    return rect.contains(Offset(
                                        details.localPosition.dx,
                                        details.localPosition.dy));
                                  });
                                  setState(() {
                                    selectedIndex = index;
                                  });
                                } else {
                                  selectedIndex = -1;
                                  showInSnackBar("No points available");
                                }
                              }
                            },
                            onTap: () {
                              if (editMode) {
                                setState(() {
                                  editText = "";
                                  pickerColor = null;
                                });
                                if (selectedIndex != -1) showEditAlertDialog();
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand, // add this
                              overflow: Overflow.visible,
                              children: <Widget>[
                                SizedBox(
                                  width: _image.width.toDouble(),
                                  height: _image.height.toDouble(),
                                  child: CustomPaint(
                                    size: Size(_image.width.toDouble(),
                                        _image.height.toDouble()),
                                    painter: ImageEditor(_image, objects),
                                    child: Container(),
                                  ),
                                ),
                                !editMode
                                    ? Positioned(
                                        top: yPos,
                                        left: xPos,
                                        child: Icon(Icons.location_on,
                                            color: Colors.red,
                                            size: _image.height.toDouble() *
                                                0.05),
                                      )
                                    : SizedBox.shrink()
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    !editMode
                        ? ButtonBar(
                            buttonTextTheme: ButtonTextTheme.accent,
                            alignment: MainAxisAlignment.center,
                            children: <Widget>[
                              FlatButton(
                                child: Icon(Icons.undo),
                                onPressed: () {
                                  setState(() {
                                    if (objects.length >= 1)
                                      objects.removeLast();
                                    else {
                                      showInSnackBar("Points are empty");
                                    }
                                  });
                                },
                              ),
                              FlatButton(
                                child: Icon(Icons.adjust),
                                onPressed: () {
                                  showCircleRadiusAlertDialog();
                                },
                              ),
                              FlatButton(
                                child: Icon(Icons.add_location),
                                onPressed: () {
                                  showTextAlertDialog();
                                },
                              ),
                              FlatButton(
                                child: Icon(Icons.save),
                                onPressed: () async {
                                  showSaveFileAlertDialog();
                                },
                              )
                            ],
                          )
                        : SizedBox.shrink()
                  ],
                )
              : Center(
                  child: Container(
                    color: Colors.lightBlue,
                    child: Center(child: Text("Loading...")),
                  ),
                )),
    );
  }
}

class Oval {
  Color color;
  double x;
  double y;
  double width;
  double height;
  String text;
  Rect rect;
  int angle;
  Oval(color, x, y, width, height, text, angle) {
    this.color = color;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.text = text;
    this.angle = angle;
  }
}

//canvas
class ImageEditor extends CustomPainter {
  ui.Image image;
  List<Oval> objects = new List();
  Picture picture;
  int currTouch;
  ImageEditor(this.image, this.objects) : super();

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint

    Paint paint = new Paint()..color = Colors.yellow;
    canvas.drawImage(image, Offset.zero, paint);

    for (var item in objects) {
      paint = new Paint()..color = item.color;
      final rect = Rect.fromCenter(
          center: Offset(item.x, item.y),
          height: item.height,
          width: item.width);

      canvas.drawOval(rect, paint);
      drawText(canvas, item.text, item.x, item.y, item.angle.toDouble(),
          item.width, item.height);
    }
  }

  void drawText(Canvas context, String name, double x, double y,
      double angleRotationInRadians, double width, double height) {
    double fontSize = 0;
    double maxWidth = 0;
    if (width > height) {
      fontSize = width * 0.1;
      maxWidth = width;
    } else {
      fontSize = height * 0.1;
      maxWidth = height;
    }
    TextSpan span = new TextSpan(
        style: new TextStyle(
            color: Colors.white, fontSize: fontSize, fontFamily: 'Roboto'),
        text: name);
    TextPainter tp = new TextPainter(
        textScaleFactor: 1,
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);

    tp.layout(maxWidth: maxWidth);

    context.save();

    const double pi = 3.1415926535897932;
    if (height > width) {
      context.translate(x + tp.width * 0.1, y - tp.height);
    } else {
      context.translate(x - (tp.width * 0.5), y - (tp.height * 0.5));
    }

    context.rotate(angleRotationInRadians * (pi / 180));

    tp.paint(context, new Offset(0.0, 0.0));

    context.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
