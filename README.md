Audienzz SDK Flutter
========

Flutter wrapper for Audienzz Mobile SDK

Getting started
=======

Installation
-------

In your terminal run command: 
```
flutter pub add audienzz_sdk_flutter
```

OR add directly to pubspec.yaml
```yaml
    audienzz_sdk_flutter: latest
```

and run command:
```
flutter pub get
```

Setup Android
-------

Add your AdMob app ID, to your app's `AndroidManifest.xml` file. 
To do so, add a <meta-data> tag with android:name="com.google.android.gms.ads.APPLICATION_ID". 
You can find your app ID in the AdMob web interface. 
For android:value, insert your own AdMob app ID, surrounded by quotation marks.

```xml
<manifest>
  <application>
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
  </application>
</manifest>
```

Setup IOS
-------

Update your app's `Info.plist` file with your AdMob app ID:

```
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

Initialize SDK
-------
First of all, SDK needs to be initialized. It's done asynchronously, so after callback
is triggered with `InitializationStatus.success`, SDK is ready to be used.

```dart
 final status = await AudienzzSdkFlutter.instance.initialize(companyId: 'Your company id provided by Audienzz');

 if (status == InitializationStatus.success) {
   // SDK is ready to be used
 }
```

The Audienzz SDK Flutter allows you to display three types Ads - `BannerAd`, `InterstitialAd` and `RewardedAd`.

Examples
========
You can find examples of practical implementation here:

[Examples](example/lib/pages)

License
========

    Copyright 2025 Audienzz AG.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
       http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
