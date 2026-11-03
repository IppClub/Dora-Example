package org.dora.godotrc1;

import android.app.Activity;
import android.app.Instrumentation;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES30;
import android.os.Bundle;
import java.io.File;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.IntBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.json.JSONArray;
import org.json.JSONObject;

/** Independent GLES API probe. Does not start Dora or LibGodot. */
public final class ShaderBinaryProbe extends Instrumentation {
    private static final String VERTEX = "#version 300 es\nvoid main(){const vec2 p[3]=vec2[3](vec2(-1.,-1.),vec2(3.,-1.),vec2(-1.,3.));gl_Position=vec4(p[gl_VertexID],0.,1.);}";
    private static final String FRAGMENT = "#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(.125,.375,.75,1.);}";
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    private static int shader(int type, String code) {
        int shader = GLES30.glCreateShader(type);
        GLES30.glShaderSource(shader, code); GLES30.glCompileShader(shader);
        int[] status = new int[1]; GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0);
        if (status[0] != 1) throw new IllegalStateException(GLES30.glGetShaderInfoLog(shader));
        return shader;
    }
    private static int sourceProgram() {
        int v = shader(GLES30.GL_VERTEX_SHADER, VERTEX), f = shader(GLES30.GL_FRAGMENT_SHADER, FRAGMENT);
        int p = GLES30.glCreateProgram();
        GLES30.glProgramParameteri(p, GLES30.GL_PROGRAM_BINARY_RETRIEVABLE_HINT, 1);
        GLES30.glAttachShader(p, v); GLES30.glAttachShader(p, f); GLES30.glLinkProgram(p);
        GLES30.glDeleteShader(v); GLES30.glDeleteShader(f);
        int[] status = new int[1]; GLES30.glGetProgramiv(p, GLES30.GL_LINK_STATUS, status, 0);
        if (status[0] != 1) throw new IllegalStateException(GLES30.glGetProgramInfoLog(p));
        return p;
    }
    private static JSONArray pixels(int program) {
        GLES30.glViewport(0, 0, 2, 2); GLES30.glUseProgram(program);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);
        ByteBuffer pixel = ByteBuffer.allocateDirect(4);
        GLES30.glReadPixels(0, 0, 1, 1, GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, pixel);
        if (GLES30.glGetError() != GLES30.GL_NO_ERROR) throw new IllegalStateException("Source pixel GL error");
        JSONArray result = new JSONArray();
        int[] expected = {32, 96, 191, 255};
        for (int i = 0; i < 4; ++i) {
            int value = pixel.get(i) & 255;
            if (Math.abs(value - expected[i]) > 1) throw new IllegalStateException("Unexpected source pixel");
            result.put(value);
        }
        return result;
    }
    private static JSONObject restore(ByteBuffer binary, int length, int format) throws Exception {
        int p = GLES30.glCreateProgram(); binary.rewind();
        GLES30.glProgramBinary(p, format, binary, length);
        int error = GLES30.glGetError();
        int[] status = new int[1]; GLES30.glGetProgramiv(p, GLES30.GL_LINK_STATUS, status, 0);
        JSONObject result = new JSONObject().put("linked", status[0] == 1).put("gl_error", error)
            .put("info_log", GLES30.glGetProgramInfoLog(p));
        if (status[0] == 1 && error == GLES30.GL_NO_ERROR) result.put("pixels", pixels(p));
        GLES30.glDeleteProgram(p);
        return result;
    }
    @Override public void onStart() {
        Bundle answer = new Bundle(); JSONObject result = new JSONObject();
        EGLDisplay display = EGL14.EGL_NO_DISPLAY;
        EGLContext context = EGL14.EGL_NO_CONTEXT;
        EGLSurface surface = EGL14.EGL_NO_SURFACE;
        try {
            display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
            if (!EGL14.eglInitialize(display, new int[2], 0, new int[2], 0)) throw new IllegalStateException("eglInitialize failed");
            EGLConfig[] config = new EGLConfig[1]; int[] count = new int[1];
            int[] attributes = {EGL14.EGL_RENDERABLE_TYPE, 0x40, EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_NONE};
            if (!EGL14.eglChooseConfig(display, attributes, 0, config, 0, 1, count, 0) || count[0] != 1) throw new IllegalStateException("No GLES3 pbuffer config");
            surface = EGL14.eglCreatePbufferSurface(display, config[0], new int[]{EGL14.EGL_WIDTH,2,EGL14.EGL_HEIGHT,2,EGL14.EGL_NONE}, 0);
            context = EGL14.eglCreateContext(display, config[0], EGL14.EGL_NO_CONTEXT, new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION,3,EGL14.EGL_NONE}, 0);
            if (!EGL14.eglMakeCurrent(display, surface, surface, context)) throw new IllegalStateException("eglMakeCurrent failed");
            result.put("renderer", GLES30.glGetString(GLES30.GL_RENDERER)).put("version", GLES30.glGetString(GLES30.GL_VERSION));
            int[] formats = new int[1]; GLES30.glGetIntegerv(GLES30.GL_NUM_PROGRAM_BINARY_FORMATS, formats, 0);
            result.put("reported_binary_formats", formats[0]);
            int program = sourceProgram(); result.put("source_pixels", pixels(program));
            int[] capacity = new int[1]; GLES30.glGetProgramiv(program, GLES30.GL_PROGRAM_BINARY_LENGTH, capacity, 0);
            if (capacity[0] <= 0) throw new IllegalStateException("No program binary bytes");
            ByteBuffer binary = ByteBuffer.allocateDirect(capacity[0]);
            IntBuffer length = ByteBuffer.allocateDirect(4).order(ByteOrder.nativeOrder()).asIntBuffer();
            IntBuffer format = ByteBuffer.allocateDirect(4).order(ByteOrder.nativeOrder()).asIntBuffer();
            GLES30.glGetProgramBinary(program, capacity[0], length, format, binary);
            int captureError = GLES30.glGetError();
            result.put("queried_bytes", capacity[0]).put("returned_bytes", length.get(0)).put("format", format.get(0)).put("capture_error", captureError);
            StringBuilder prefix = new StringBuilder();
            for (int i = 0; i < Math.min(64, length.get(0)); ++i) prefix.append(String.format("%02x", binary.get(i) & 255));
            result.put("binary_prefix_hex", prefix.toString());
            if (captureError != 0 || length.get(0) <= 0 || length.get(0) > capacity[0]) throw new IllegalStateException("Program capture failed");
            result.put("same_context", restore(binary, length.get(0), format.get(0)));
            GLES30.glDeleteProgram(program);
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            EGL14.eglDestroyContext(display, context);
            context = EGL14.eglCreateContext(display, config[0], EGL14.EGL_NO_CONTEXT, new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION,3,EGL14.EGL_NONE}, 0);
            if (!EGL14.eglMakeCurrent(display, surface, surface, context)) throw new IllegalStateException("New context failed");
            result.put("new_context", restore(binary, length.get(0), format.get(0)));
            int fallback = sourceProgram(); result.put("source_recompile_pixels", pixels(fallback)); GLES30.glDeleteProgram(fallback);
            boolean engineMapped = new String(Files.readAllBytes(new File("/proc/self/maps").toPath()), StandardCharsets.UTF_8).contains("libgodot_android.so");
            if (engineMapped) throw new IllegalStateException("LibGodot unexpectedly mapped in independent probe");
            result.put("complete", true).put("libgodot_started", false).put("libgodot_mapped", false);
            answer.putString("result", "Independent GLES binary probe complete");
        } catch (Exception error) {
            try { result.put("complete", false).put("error", error.toString()); } catch (Exception ignored) { }
            answer.putString("error", error.toString());
        } finally {
            if (display != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
                if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context);
                if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface);
                EGL14.eglTerminate(display);
            }
            try {
                File output = new File(getTargetContext().getExternalMediaDirs()[0], "dora-shader-binary-probe.json");
                Files.write(output.toPath(), result.toString().getBytes(StandardCharsets.UTF_8));
            } catch (Exception error) { answer.putString("export_error", error.toString()); }
            finish(answer.containsKey("error") || answer.containsKey("export_error") ? Activity.RESULT_CANCELED : Activity.RESULT_OK, answer);
        }
    }
}
