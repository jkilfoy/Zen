How to build Zen app. 

In elevated powershell

cd C:\Users\Jordan\Documents\Projects\Zen\packages\zen_app


Release build on windows:

flutter build windows --release

access: 
C:\Users\Jordan\Documents\Projects\Zen\packages\zen_app\build\windows\x64\runner\Release\


Release build on Android:

pair device, then:

flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk

(or)

flutter install --release -d 192.168.0.151:38537    
(device id can change)