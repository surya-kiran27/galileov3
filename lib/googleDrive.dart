import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:galileov3/secureStorage.dart';
import 'package:googleapis/drive/v3.dart' as ga;

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

var id = new ClientId(DotEnv().env['CLIENT_ID'], "");

const _scopes = [ga.DriveApi.DriveFileScope];

class GoogleDrive {
  final storage = SecureStorage();

  //Get Authenticated Http Client
  Future<http.Client> getHttpClient() async {
    var credentials = await storage.getCredentials();
    if (credentials == null) {
      //Needs user authentication
      //Save Credentials
      var authClient = await clientViaUserConsent(id, _scopes, (url) {
        //Open Url in Browser
        launch(url);
      });

      await storage.saveCredentials(authClient.credentials.accessToken,
          authClient.credentials.refreshToken);
      return authClient;
    } else {
      //Already authenticated
      return authenticatedClient(
          http.Client(),
          AccessCredentials(
              AccessToken(credentials["type"], credentials["data"],
                  DateTime.tryParse(credentials["expiry"])),
              credentials["refreshToken"],
              _scopes));
    }
  }

  //Upload File
  Future upload(File file) async {
    var client = await getHttpClient();
    var drive = ga.DriveApi(client);

    try {
      String pageToken = null;
      bool found = false;
      String folderID = "";
      do {
        ga.FileList result = await drive.files.list(
            q: "mimeType='application/vnd.google-apps.folder' and name='Galileo' and trashed=false",
            $fields: "nextPageToken, files(id, name)",
            pageToken: pageToken,
            spaces: "drive");

        result.files.forEach((f) {
          if (f.name == "Galileo") {
            found = true;
            folderID = f.id;
          }
        });
        pageToken = result.nextPageToken;
      } while (pageToken != null);
      if (!found) {
        var _createFolder = await drive.files.create(
          ga.File()
            ..name = 'Galileo'
            ..mimeType = 'application/vnd.google-apps.folder',
        );
        folderID = _createFolder.id;
      }
      var response = await drive.files.create(
          ga.File()
            ..name = p.basename(file.absolute.path)
            ..parents = [folderID],
          uploadMedia: ga.Media(file.openRead(), file.lengthSync()));
      print(response);
      return response;
    } catch (e) {
      print(e);
      return null;
    }
  }
}
