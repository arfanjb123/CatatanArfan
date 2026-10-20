import re
p = "android/app/src/main/AndroidManifest.xml"
s = open(p, encoding="utf-8").read()
s = re.sub(r'android:label="[^"]*"', 'android:label="Catatan Arfan"', s, count=1)
perm = ('<uses-permission android:name="android.permission.INTERNET"/>\n    '
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    ')
s = s.replace("<application", perm + "<application", 1)
svc = ('<service android:name="im.zoe.labs.flutter_notification_listener.NotificationsHandlerService" '
       'android:label="Catatan Arfan" '
       'android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" '
       'android:exported="true"><intent-filter>'
       '<action android:name="android.service.notification.NotificationListenerService"/>'
       '</intent-filter></service>\n    ')
s = s.replace("</application>", svc + "</application>", 1)
open(p, "w", encoding="utf-8").write(s)
print("manifest ok")
