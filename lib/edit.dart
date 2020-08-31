import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:ext_storage/ext_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:galileov3/googleDrive.dart';
import 'package:galileov3/main.dart';
import 'package:googleapis/cloudsearch/v1.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zoom_widget/zoom_widget.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:math';

const directoryName = 'Galileo';

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
  double x;
  List<Oval> objects = new List();
  final drive = GoogleDrive();
  final _random = new Random();

  @override
  void initState() {
    _loadImage();
  }

  int next(int min, int max) => min + _random.nextInt(max - min);

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
        String path = directory + "/Galileo";

        await Directory('$path').create(recursive: true);

        File upload = await File('$path/${fileName}.png')
            .writeAsBytes(pngBytes.buffer.asInt8List());
        showInSnackBar("Saved at " + upload.path);
        showInSnackBar("Uploading please wait...");
        var res = await drive.upload(upload);
        if (res != null)
          showInSnackBar("File uploaded to drive ");
        else {
          showInSnackBar("Failed to upload");
        }
      }
    } catch (e) {
      print(e);
      showInSnackBar("Failed to get downloads directory");
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

  void changeColor(Color color) {
    setState(() => pickerColor = color);
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
          });
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
    Widget okButton = FlatButton(
        child: Text("Upload"),
        onPressed: () async {
          if (fileName != "") {
            Navigator.of(context, rootNavigator: true).pop();
            saveImage();
          } else {
            showInSnackBar("Invalid file name");
          }
        });
    Widget cancelButton = FlatButton(
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
            TextField(
              onChanged: (text) {
                setState(() {
                  fileName = text;
                });
              },
            )
          ]),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Enter File Name"),
      actions: [cancelButton, okButton],
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

  @override
  dispose() {
    // you need this
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
                              }
                            },
                            onTap: () {
                              if (editMode) {
                                setState(() {
                                  editText = "";
                                  pickerColor = null;
                                });
                                showEditAlertDialog();
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
    if (angleRotationInRadians == 0) {
      fontSize = width * 0.2;
    } else {
      fontSize = height * 0.2;
    }
    TextSpan span = new TextSpan(
        style: new TextStyle(
            color: Colors.white, fontSize: fontSize, fontFamily: 'Roboto'),
        text: name);
    TextPainter tp = new TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();

    context.save();
    const double pi = 3.1415926535897932;
    if (height > width) {
      context.translate(x + span.style.fontSize * 0.5, y - span.style.fontSize);
    } else {
      context.translate(
          x - (span.style.fontSize), y - (span.style.fontSize * 0.5));
    }

    context.rotate(angleRotationInRadians * (pi / 180));
    tp.paint(context, new Offset(0.0, 0.0));

    context.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
