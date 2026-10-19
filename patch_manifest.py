import sys
import os

manifest_path = 'android/app/src/main/AndroidManifest.xml'
if not os.path.exists(manifest_path):
    print(f"❌ {manifest_path} не найден")
    sys.exit(1)

with open(manifest_path, 'r') as f:
    content = f.read()

# Разрешения
permissions = '''    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
'''

if 'android.permission.FOREGROUND_SERVICE' not in content:
    content = content.replace('<application', permissions + '\n    <application')

# Сервис
service = '''        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="dataSync"
            android:exported="false"
            android:stopWithTask="false" />

        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false" />
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
'''

if 'com.pravera.flutter_foreground_task.service.ForegroundService' not in content:
    content = content.replace('</application>', service + '    </application>')

with open(manifest_path, 'w') as f:
    f.write(content)
print("✅ AndroidManifest.xml пропатчен")
