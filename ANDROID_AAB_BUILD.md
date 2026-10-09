# Build an Android App Bundle

This guide creates a signed `.aab` for Google Play. Do not send your keystore,
passwords, or `android/key.properties` to anyone. Keep a secure backup of the
keystore: future app updates depend on the same upload key unless you request a
reset through Play Console.

## 1. Open the project in VS Code

Open the `devine_word_app` folder, then choose **Terminal → New Terminal**.
Run commands from this project folder:

```sh
cd /Users/masum/Documents/Devine-Word-HTML-CSS/devine_word_app
```

You need Flutter and Java `keytool` available in the terminal. Check them with:

```sh
flutter --version
keytool -help
```

## 2. Create the upload keystore once

If `android/upload-keystore.jks` does not already exist, run:

```sh
keytool -genkeypair -v -keystore android/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` prompts for keystore and key passwords, then certificate details.
Type the passwords directly into the terminal and store them securely. They
will not appear while typed. Do not create a new key if you already uploaded
this app to Play using a different upload key.

## 3. Configure local signing

Copy the example file:

```sh
cp android/key.properties.example android/key.properties
```

In VS Code Explorer, open `android/key.properties` and replace the two
password placeholders with the passwords entered in step 2. Keep these values
unless you chose a different alias or keystore filename:

```properties
keyAlias=upload
storeFile=upload-keystore.jks
```

Save the file. The matching keystore should be at
`android/upload-keystore.jks`. Both files are ignored by Git; never remove
them from `.gitignore` or commit them.

## 4. Build the AAB

Run the provided script from any directory inside the repository:

```sh
bash scripts/build_android_aab.sh
```

The script checks that the signing file and keystore exist, then runs the
release build. On success, the bundle is:

```text
build/app/outputs/bundle/release/app-release.aab
```

The script does not upload the bundle. If it reports a missing key, password,
alias, or keystore path, correct `android/key.properties` or put the keystore
at the path specified by `storeFile`, then run the script again.

## 5. Upload through Play Console

1. Open the app in Google Play Console and enroll in **Play App Signing** if
   prompted. Google manages the app-signing key; your local keystore is the
   upload key.
2. Start with **Testing → Internal testing** and create a release.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Review Play Console's validation messages and complete the requested app
   listing, privacy, Data safety, audience, and content-rating information.
5. Save the release and follow Play Console's instructions to make the test
   available to your testers.

Before each later upload, increment the build number after `+` in `pubspec.yaml`
(for example, change `1.0.0+1` to `1.0.0+2`) and run the script again. Do not
upload the `.jks` or `key.properties` file to Play Console or GitHub.