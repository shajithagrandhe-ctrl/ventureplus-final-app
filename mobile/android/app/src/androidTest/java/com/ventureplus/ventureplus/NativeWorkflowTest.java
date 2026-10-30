package com.ventureplus.ventureplus;

import static org.junit.Assert.*;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.content.ContentValues;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.provider.MediaStore;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.By;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject2;
import androidx.test.uiautomator.Until;
import java.io.File;
import java.io.OutputStream;
import org.junit.Test;
import org.junit.runner.RunWith;

/** Native platform checks run only on the explicitly selected disposable emulator. */
@RunWith(AndroidJUnit4.class)
public class NativeWorkflowTest {
    private static final String APP = "com.ventureplus.ventureplus";
    private UiDevice device;
    private Context context;

    private UiObject2 label(String value) {
        UiObject2 node = device.findObject(By.descContains(value));
        return node != null ? node : device.findObject(By.textContains(value));
    }

    private UiObject2 awaitLabel(String value) throws Exception {
        long deadline = android.os.SystemClock.uptimeMillis() + 15000;
        while (android.os.SystemClock.uptimeMillis() < deadline) {
            UiObject2 node = label(value);
            if (node != null) return node;
            android.os.SystemClock.sleep(200);
        }
        capture("timeout-" + value.replaceAll("[^a-zA-Z]", ""));
        fail("Timed out waiting for native control: " + value);
        return null;
    }

    private void tap(String value) throws Exception {
        for (int i = 0; i < 14; i++) {
            UiObject2 node = label(value);
            if (node != null) {
                node.click();
                device.waitForIdle();
                return;
            }
            int from = i < 7 ? device.getDisplayHeight()*3/4 : device.getDisplayHeight()/3;
            int to = i < 7 ? device.getDisplayHeight()/3 : device.getDisplayHeight()*3/4;
            device.swipe(device.getDisplayWidth()/2, from, device.getDisplayWidth()/2, to, 25);
            device.waitForIdle();
        }
        capture("missing-" + value.replaceAll("[^a-zA-Z]", ""));
        fail("Missing native control: " + value);
    }

    private void tapSelector(androidx.test.uiautomator.BySelector selector) throws Exception {
        for (int attempt = 0; attempt < 3; attempt++) {
            device.waitForIdle();
            UiObject2 node = device.wait(Until.findObject(selector), 15000);
            assertNotNull("Native control missing: " + selector, node);
            try { node.click(); device.waitForIdle(); return; }
            catch (androidx.test.uiautomator.StaleObjectException ignored) { }
        }
        fail("Native control kept changing: " + selector);
    }

    private void scrollTop() {
        for (int i = 0; i < 3; i++) {
            device.swipe(device.getDisplayWidth()/2, device.getDisplayHeight()/3,
                device.getDisplayWidth()/2, device.getDisplayHeight()*3/4, 20);
        }
        device.waitForIdle();
    }

    private void capture(String name) throws Exception {
        File evidence = new File(context.getExternalFilesDir(null), "native-evidence");
        assertTrue(evidence.isDirectory() || evidence.mkdirs());
        device.dumpWindowHierarchy(new File(evidence, name + ".xml"));
        assertTrue(device.takeScreenshot(new File(evidence, name + ".png")));
    }

    private void createPhoto() throws Exception {
        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, "ventureplus-native-fixture.png");
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
        values.put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/VenturePlusNativeQA");
        Uri uri = context.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        assertNotNull(uri);
        Bitmap bitmap = Bitmap.createBitmap(120, 80, Bitmap.Config.ARGB_8888);
        bitmap.eraseColor(Color.rgb(90, 125, 110));
        try (OutputStream output = context.getContentResolver().openOutputStream(uri)) {
            assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output));
        } finally { bitmap.recycle(); }
    }

    private void startOfflineAdmin() throws Exception {
        assertTrue("Only the project's Android emulator is permitted",
            Build.HARDWARE.equals("ranchu") || Build.HARDWARE.equals("goldfish"));
        assertEquals("local-demo-emulator", InstrumentationRegistry.getArguments().getString("ventureplusTestDevice"));
        context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
        device.wakeUp();
        device.executeShellCommand("wm dismiss-keyguard");
        if (label("Wait") != null) tap("Wait");
        Intent intent = context.getPackageManager().getLaunchIntentForPackage(APP);
        assertNotNull(intent);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
        boolean opened = device.wait(Until.hasObject(By.pkg(APP)), 30000);
        capture("00-launch-state");
        assertTrue("App did not open", opened);
        device.waitForIdle();
        capture("00-launch");
        if (label("Inventory\n") == null) {
            tap("Offline Demo");
            tap("Explore as Admin");
            awaitLabel("Inventory\n");
        }
        assertNotNull("Native mutations require Offline Demo", label("Changes stay on this device"));
    }

    @Test
    public void nativePickers() throws Exception {
        startOfflineAdmin();
        createPhoto();
        tap("Inventory\n");
        tap("Harbour district");
        tap("Sage Harbour");
        tap("Choose photo");
        tap("Choose from gallery");
        awaitLabel("Photo taken on");
        capture("01-gallery-picker");
        tap("Photo taken on");
        awaitLabel("Selected:");
        capture("02-gallery-selected");
        tap("Upload selected file");
        awaitLabel("Replace venture image?");
        tap("Confirm");
        assertTrue(device.wait(Until.gone(By.descContains("Selected:")), 15000));
        scrollTop();
        capture("03-gallery-uploaded");
        tap("Choose layout");
        tap("Choose a file");
        assertTrue(device.wait(Until.hasObject(By.pkg("com.android.documentsui")), 15000));
        tapSelector(By.desc("Show roots"));
        tapSelector(By.res("android:id/title").text("Recent"));
        assertTrue(device.wait(Until.gone(By.res("com.android.documentsui:id/roots_list")), 10000));
        assertTrue(device.wait(Until.hasObject(By.textContains("ventureplus-native-fixture")), 15000));
        capture("04-file-picker");
        device.findObject(By.textContains("ventureplus-native-fixture")).click();
        awaitLabel("Selected:");
        tap("Upload selected file");
        awaitLabel("Replace venture image?");
        tap("Confirm");
        assertTrue(device.wait(Until.gone(By.descContains("Selected:")), 15000));
        scrollTop();
        capture("05-file-uploaded");
        tap("Choose photo");
        tap("Take a photo");
        assertTrue(device.wait(Until.hasObject(By.pkg("com.android.camera2")), 15000));
        awaitLabel("Shutter");
        capture("06-camera-open");
        tap("Shutter");
        awaitLabel("Done");
        capture("07-camera-preview");
        tap("Done");
        awaitLabel("Selected:");
        tap("Upload selected file");
        awaitLabel("Replace venture image?");
        tap("Confirm");
        assertTrue(device.wait(Until.gone(By.descContains("Selected:")), 15000));
        scrollTop();
        capture("08-camera-uploaded");
        tap("Choose photo");
        tap("Choose from gallery");
        awaitLabel("Photo taken on");
        tapSelector(By.desc("Cancel"));
        awaitLabel("Choose photo");
        assertNull("Cancelled picker must not select another file", label("Selected:"));
        capture("08b-gallery-cancelled");
    }

    @Test
    public void nativeExportsAndKeyboard() throws Exception {
        startOfflineAdmin();
        awaitLabel("Customers\n");
        tap("Customers\n");
        tap("Export filtered customers");
        assertTrue(device.wait(Until.hasObject(By.pkg("com.android.documentsui")), 15000));
        capture("09-csv-save-dialog");
        String csvName = "ventureplus-native-customers-" + System.currentTimeMillis() + ".csv";
        device.findObject(By.res("android:id/title").clazz("android.widget.EditText")).setText(csvName);
        tap("SAVE");
        assertTrue(device.wait(Until.gone(By.pkg("com.android.documentsui")), 15000));
        awaitLabel("Export filtered customers");
        awaitLabel("Customer export saved to your selected location.");
        String csv = device.executeShellCommand("cat /sdcard/Download/" + csvName);
        assertTrue("Saved CSV header missing", csv.contains("Customer Name"));
        assertTrue("Saved CSV fixture missing", csv.contains("Riya Shah"));
        capture("10-csv-saved");
        scrollTop();
        UiObject2 search = device.findObject(By.clazz("android.widget.EditText"));
        assertNotNull("Customer search field is missing", search);
        search.click();
        assertTrue(device.wait(Until.hasObject(By.clazz("android.widget.EditText").focused(true)), 10000));
        device.pressKeyCode(android.view.KeyEvent.KEYCODE_R);
        device.pressKeyCode(android.view.KeyEvent.KEYCODE_I);
        device.pressKeyCode(android.view.KeyEvent.KEYCODE_Y);
        device.pressKeyCode(android.view.KeyEvent.KEYCODE_A);
        assertTrue(device.wait(Until.hasObject(By.text("riya")), 10000));
        capture("11-native-keyboard");
        device.pressBack();
        tap("Riya Shah");
        tap("Save follow-up reminder");
        awaitLabel("Next month");
        capture("12-reminder-date-dialog");
        tap("Next month");
        String nextMonth = java.time.LocalDate.now().plusMonths(1).getMonth()
            .getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.US);
        awaitLabel(nextMonth + " 15,");
        tapSelector(By.descStartsWith("15, "));
        tapSelector(By.desc("OK"));
        awaitLabel("Select time");
        tapSelector(By.desc("OK"));
        assertTrue(device.wait(Until.hasObject(By.pkg("com.android.documentsui")), 15000));
        capture("13-calendar-save-dialog");
        String calendarName = "ventureplus-native-reminder-" + System.currentTimeMillis() + ".ics";
        device.findObject(By.res("android:id/title").clazz("android.widget.EditText")).setText(calendarName);
        tap("SAVE");
        assertTrue(device.wait(Until.gone(By.pkg("com.android.documentsui")), 15000));
        awaitLabel("Reminder file saved.");
        String calendar = device.executeShellCommand("cat /sdcard/Download/" + calendarName);
        assertTrue("Saved calendar is missing its envelope", calendar.contains("BEGIN:VCALENDAR"));
        assertTrue("Saved calendar is missing the selected customer", calendar.contains("SUMMARY:Follow-up: Riya Shah"));
        assertTrue("Saved calendar is missing its alarm", calendar.contains("TRIGGER:-PT15M"));
        capture("14-calendar-saved");
    }
}
