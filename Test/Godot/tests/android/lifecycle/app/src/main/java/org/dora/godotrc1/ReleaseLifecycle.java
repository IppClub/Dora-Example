package org.dora.godotrc1;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.Instrumentation;
import android.app.UiAutomation;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import android.util.Log;
import android.view.InputDevice;
import android.view.MotionEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import java.io.File;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import org.json.JSONObject;

/** Separate controller APK; the target stays an ordinary nondebuggable release.
 * Uses only Android framework APIs and the public Lua fixture's result file.
 * The controller must share the local QA signing certificate with the target.
 */
public final class ReleaseLifecycle extends Instrumentation {
    private static void hashProject(File root, File directory, JSONObject result) throws Exception {
        File[] files = directory.listFiles();
        if (files == null) throw new IllegalStateException("Cannot inspect " + directory);
        for (File file : files) {
            if (file.getName().equals(".godot")) continue;
            if (file.isDirectory()) hashProject(root, file, result);
            else {
                byte[] digest = MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(file.toPath()));
                StringBuilder hex = new StringBuilder();
                for (byte value : digest) hex.append(String.format("%02x", value & 255));
                result.put(root.toPath().relativize(file.toPath()).toString().replace(File.separatorChar, '/'), hex.toString());
            }
        }
    }
    private Bundle arguments;
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        this.arguments = arguments == null ? new Bundle() : arguments;
        start();
    }
    private static void deleteTree(File file) throws Exception {
        if (!file.exists()) return;
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) for (File child : children) deleteTree(child);
        }
        if (!file.delete()) throw new IllegalStateException("Cannot delete " + file);
    }
    private static void write(File file, String value) throws Exception {
        Files.write(file.toPath(), value.getBytes(StandardCharsets.UTF_8));
    }
    private static void waitFor(File file, long deadline, String label) throws Exception {
        while (!file.isFile()) {
            if (System.nanoTime() > deadline) throw new IllegalStateException("Timed out waiting for " + label);
            Thread.sleep(50);
        }
    }
    private int targetPid() {
        ActivityManager manager = (ActivityManager)getTargetContext().getSystemService(Context.ACTIVITY_SERVICE);
        for (ActivityManager.RunningAppProcessInfo process : manager.getRunningAppProcesses())
            if ("org.ippclub.dorassr".equals(process.processName)) return process.pid;
        return -1;
    }
    private void shell(String command) throws Exception {
        UiAutomation automation = getUiAutomation();
        try (ParcelFileDescriptor descriptor = automation.executeShellCommand(command);
             FileInputStream input = new FileInputStream(descriptor.getFileDescriptor())) {
            byte[] buffer = new byte[1024];
            while (input.read(buffer) >= 0) { }
        }
    }
    private void tap(int x, int y) {
        long now = SystemClock.uptimeMillis();
        MotionEvent down = MotionEvent.obtain(now, now, MotionEvent.ACTION_DOWN, x, y, 0);
        down.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        if (!getUiAutomation().injectInputEvent(down, true)) throw new IllegalStateException("Touch down rejected");
        down.recycle();
        MotionEvent up = MotionEvent.obtain(now, now + 60, MotionEvent.ACTION_UP, x, y, 0);
        up.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        if (!getUiAutomation().injectInputEvent(up, true)) throw new IllegalStateException("Touch up rejected");
        up.recycle();
    }
    private static AccessibilityNodeInfo findViewId(AccessibilityNodeInfo node, String id) {
        if (node == null) return null;
        if (id.equals(node.getViewIdResourceName())) return node;
        for (int index = 0; index < node.getChildCount(); ++index) {
            AccessibilityNodeInfo found = findViewId(node.getChild(index), id);
            if (found != null) return found;
        }
        return null;
    }
    private boolean dismissImmersiveConfirmation() throws Exception {
        long deadline = System.nanoTime() + 2_000_000_000L;
        do {
            AccessibilityNodeInfo button = findViewId(getUiAutomation().getRootInActiveWindow(), "android:id/ok");
            if (button != null && button.isClickable()) {
                if (!button.performAction(AccessibilityNodeInfo.ACTION_CLICK))
                    throw new IllegalStateException("Immersive confirmation click rejected");
                Thread.sleep(300);
                return true;
            }
            Thread.sleep(100);
        } while (System.nanoTime() < deadline);
        return false;
    }
    private static void exportEvidence(File source, File destination) throws Exception {
        deleteTree(destination);
        if (!destination.mkdirs()) throw new IllegalStateException("Cannot create " + destination);
        File[] files = source.listFiles();
        if (files == null) throw new IllegalStateException("Cannot list " + source);
        for (File file : files) {
            String name = file.getName();
            if (file.isFile() && (name.endsWith(".png") || name.equals("result.json") || name.equals("player.json") || name.equals("failure.txt")))
                Files.copy(file.toPath(), new File(destination, name).toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
    }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            int buffers = Integer.parseInt(arguments.getString("buffers", "3"));
            if (buffers < 2 || buffers > 4) throw new IllegalArgumentException("Invalid buffers");
            boolean direct = "1".equals(arguments.getString("direct", "0"));
            boolean blit = "1".equals(arguments.getString("blit", "0"));
            if (direct && blit) throw new IllegalArgumentException("Direct and blit are mutually exclusive");
            boolean directTarget = !blit;
            String glPolicy = direct ? "forced-direct" : (blit ? "forced-blit" : "default-direct");
            boolean missing = "1".equals(arguments.getString("missing", "0"));
            boolean full = "1".equals(arguments.getString("full", "0"));
            boolean dodge = "1".equals(arguments.getString("dodge", "0"));
            boolean projectSwitch = "1".equals(arguments.getString("project_switch", "0"));
            if (projectSwitch && (full || dodge || missing || blit || buffers != 3))
                throw new IllegalArgumentException("Project switching requires ordinary default-direct mode");
            boolean cacheAudit = "1".equals(arguments.getString("cache_audit", "0"));
            File shaderCache = new File(getTargetContext().getFilesDir(), "shader_cache");
            JSONObject shaderCacheBefore = new JSONObject();
            if (cacheAudit && shaderCache.isDirectory()) hashProject(shaderCache, shaderCache, shaderCacheBefore);
            if (dodge && (full || missing || blit || buffers != 3))
                throw new IllegalArgumentException("Dodge requires ordinary direct 3-buffer mode");
            if (full && missing) throw new IllegalArgumentException("Full acceptance cannot use a missing runtime");
            File fixture = new File(getTargetContext().getFilesDir(), "godot-release");
            deleteTree(fixture);
            if (!fixture.mkdirs()) throw new IllegalStateException("Cannot create " + fixture);
            File[] mediaRoots = getTargetContext().getExternalMediaDirs();
            if (mediaRoots.length == 0 || mediaRoots[0] == null)
                throw new IllegalStateException("Target external media directory unavailable");
            File external = new File(mediaRoots[0], "dora-godot-evidence");
            deleteTree(external);
            write(new File(fixture, "buffers.txt"), Integer.toString(buffers));
            if (missing) write(new File(fixture, "expect-missing"), "1");
            if (full) write(new File(fixture, "full-acceptance"), "1");
            if (dodge) write(new File(fixture, "dodge-acceptance"), "1");
            Intent intent = getTargetContext().getPackageManager()
                .getLaunchIntentForPackage("org.ippclub.dorassr");
            if (intent == null) throw new IllegalStateException("Missing target activity");
            if (direct) intent.putExtra("DORA_GODOT_GL_DIRECT", "1");
            else if (blit) intent.putExtra("DORA_GODOT_GL_DIRECT", "0");
            Activity activity = startActivitySync(intent);
            int initialPid = targetPid();
            if (initialPid <= 0) throw new IllegalStateException("Target process not found");
            boolean immersiveConfirmationDismissed = full && dismissImmersiveConfirmation();
            File complete = new File(fixture, "result.json");
            long deadline = System.nanoTime() + (projectSwitch ? 180_000_000_000L : (full ? 150_000_000_000L : 90_000_000_000L));
            if (full) {
                File exercise = new File(fixture, "exercise.json");
                waitFor(exercise, deadline, "Lua exercise readiness");
                JSONObject coordinates = new JSONObject(new String(Files.readAllBytes(exercise.toPath()), StandardCharsets.UTF_8));
                tap(coordinates.getInt("x"), coordinates.getInt("y"));
                File project = new File(fixture, "project");
                waitFor(new File(project, "touch-accepted"), deadline, "Godot touch acceptance");
                tap(coordinates.getInt("ime_x"), coordinates.getInt("ime_y"));
                Thread.sleep(500);
                shell("input text IME42");
                waitFor(new File(project, "ime-accepted"), deadline, "Godot IME acceptance");
                shell("input keyevent KEYCODE_HOME");
                waitFor(new File(fixture, "background-seen"), deadline, "Dora background event");
                Thread.sleep(2000);
                Intent resume = getTargetContext().getPackageManager().getLaunchIntentForPackage("org.ippclub.dorassr");
                if (resume == null) throw new IllegalStateException("Missing target resume intent");
                if (direct) resume.putExtra("DORA_GODOT_GL_DIRECT", "1");
                else if (blit) resume.putExtra("DORA_GODOT_GL_DIRECT", "0");
                getTargetContext().startActivity(resume);
                waitFor(new File(fixture, "foreground-seen"), deadline, "Dora foreground event");
                if (targetPid() != initialPid) throw new IllegalStateException("Target process changed across Home/resume");
            }
            waitFor(complete, deadline, "Lua completion");
            JSONObject json = new JSONObject(new String(Files.readAllBytes(complete.toPath()), StandardCharsets.UTF_8));
            if (!json.getBoolean("complete")) throw new IllegalStateException("Incomplete Lua result");
            if (json.optBoolean("full", false) != full) throw new IllegalStateException("Lua full-mode mismatch");
            Log.i("DoraReleaseLifecycle", "QA_ACTIVITY_FINISH_REQUESTED");
            Activity finalActivity = activity;
            runOnMainSync(finalActivity::finish);
            while (!finalActivity.isDestroyed()) {
                if (System.nanoTime() > deadline) throw new IllegalStateException("Activity destruction timed out");
                Thread.sleep(50);
            }
            // Queue behind onDestroy: SDL joins the native thread before its
            // callback returns. isDestroyed alone becomes true too early.
            runOnMainSync(() -> Log.i("DoraReleaseLifecycle", "QA_ACTIVITY_DESTROYED"));
            exportEvidence(fixture, external);
            JSONObject projectHashes = new JSONObject();
            if (dodge) hashProject(new File(fixture, "project"), new File(fixture, "project"), projectHashes);
            if (projectSwitch) {
                if (!json.optBoolean("project_switch", false)) throw new IllegalStateException("Wrong Lua fixture");
                JSONObject source = new JSONObject(), packed = new JSONObject();
                hashProject(new File(fixture, "dodge"), new File(fixture, "dodge"), source);
                hashProject(new File(fixture, "squash"), new File(fixture, "squash"), packed);
                projectHashes.put("dodge", source).put("squash", packed);
            }
            JSONObject shaderCacheAfter = new JSONObject();
            if (cacheAudit && shaderCache.isDirectory()) hashProject(shaderCache, shaderCache, shaderCacheAfter);
            write(new File(external, "controller.json"), new JSONObject()
                .put("buffers", buffers).put("direct", directTarget).put("gl_policy", glPolicy)
                .put("missing", missing).put("full", full)
                .put("dodge", dodge).put("project_switch", projectSwitch).put("project_sha256", projectHashes)
                .put("shader_cache_audited", cacheAudit)
                .put("shader_cache_before", shaderCacheBefore).put("shader_cache_after", shaderCacheAfter)
                .put("initial_pid", initialPid).put("final_pid", targetPid())
                .put("immersive_confirmation_dismissed", immersiveConfirmationDismissed).toString());
            Log.i("DoraReleaseLifecycle", "QA_EVIDENCE_EXPORTED " + external);
            result.putString("result", "Activity finished after public Lua completion");
            finish(Activity.RESULT_OK, result);
        } catch (Exception error) {
            Log.e("DoraReleaseLifecycle", "QA_ACTIVITY_FAILURE", error);
            result.putString("error", error.toString());
            finish(Activity.RESULT_CANCELED, result);
        }
    }
}
