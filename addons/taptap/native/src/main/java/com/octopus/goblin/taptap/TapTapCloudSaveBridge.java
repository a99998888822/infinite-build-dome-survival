package com.octopus.goblin.taptap;

import android.app.Activity;
import com.taptap.sdk.cloudsave.ArchiveData;
import com.taptap.sdk.cloudsave.ArchiveMetadata;
import com.taptap.sdk.cloudsave.TapTapCloudSave;
import com.taptap.sdk.cloudsave.internal.TapCloudSaveCallback;
import com.taptap.sdk.cloudsave.internal.TapCloudSaveRequestCallback;
import com.taptap.sdk.login.TapTapAccount;
import com.taptap.sdk.login.TapTapLogin;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** Credentials stay inside TapSDK. Each installation writes only its own slot. */
final class TapTapCloudSaveBridge {
    interface Sink { void send(String signal, Object... args); }
    private static final int MAX_BYTES = 10 * 1024 * 1024;
    private final Sink sink;
    private final AtomicBoolean writing = new AtomicBoolean();
    private volatile int generation;
    private volatile boolean ready;
    private final TapCloudSaveCallback status;

    TapTapCloudSaveBridge(Sink sink) {
        this.sink = sink;
        status = code -> sink.send("cloudStatus", code);
    }

    void initialize() {
        ready = true;
        TapTapCloudSave.registerCloudSaveCallback(status);
    }

    void invalidate() { generation++; }

    void destroy() {
        boolean wasReady = ready;
        ready = false;
        invalidate();
        if (wasReady) TapTapCloudSave.unregisterCloudSaveCallback(status);
    }

    private boolean valid(String owner) {
        if (!ready) return false;
        TapTapAccount account = TapTapLogin.getCurrentTapAccount();
        return account != null && !owner.isEmpty() && owner.equals(account.getOpenId());
    }

    private boolean check(String owner, int id) {
        if (valid(owner)) return true;
        sink.send("cloudFailed", id, 300001);
        return false;
    }

    void list(String owner, int id) {
        if (!check(owner, id)) return;
        try { TapTapCloudSave.getArchiveList(new Request(owner, id) {
            @Override public void onArchiveListResult(List<ArchiveData> archives) {
                JSONArray result = new JSONArray();
                for (ArchiveData archive : archives) result.put(metadata(archive));
                complete("list", result.toString());
            }
        }); } catch (Exception error) { sink.send("cloudFailed", id, -1); }
    }

    void download(String owner, int id, String uuid, String fileId) {
        if (!check(owner, id)) return;
        try { TapTapCloudSave.getArchiveData(uuid, fileId, new Request(owner, id) {
            @Override public void onArchiveDataResult(byte[] bytes) {
                if (bytes.length == 0 || bytes.length > MAX_BYTES) {
                    onRequestError(400000, "");
                } else {
                    complete("download", new String(bytes, StandardCharsets.UTF_8));
                }
            }
        }); } catch (Exception error) { sink.send("cloudFailed", id, -1); }
    }

    void upload(Activity activity, String owner, int id, String uuid,
            String name, String payload, String extra) {
        if (!check(owner, id)) return;
        if (activity == null || activity.isFinishing()) {
            sink.send("cloudFailed", id, -1);
            return;
        }
        byte[] bytes = payload.getBytes(StandardCharsets.UTF_8);
        if (bytes.length == 0 || bytes.length > MAX_BYTES) {
            sink.send("cloudFailed", id, 400000);
            return;
        }
        if (!writing.compareAndSet(false, true)) {
            sink.send("cloudFailed", id, 400007);
            return;
        }
        File snapshot = null;
        try {
            // Never hand the mutable game save to an asynchronous uploader.
            snapshot = File.createTempFile("tap-cloud-", ".json", activity.getCacheDir());
            try (FileOutputStream stream = new FileOutputStream(snapshot)) { stream.write(bytes); }
            final File upload = snapshot;
            Request callback = new Request(owner, id) {
                @Override void release() { upload.delete(); writing.set(false); }
                @Override public void onArchiveCreated(ArchiveData archive) {
                    complete("upload", metadata(archive).toString());
                }
                @Override public void onArchiveUpdated(ArchiveData archive) {
                    complete("upload", metadata(archive).toString());
                }
            };
            ArchiveMetadata info = new ArchiveMetadata.Builder().setName(name)
                .setSummary("Camp progression").setExtra(extra).setPlaytime(0).build();
            if (uuid.isEmpty()) {
                TapTapCloudSave.createArchive(info, snapshot.getAbsolutePath(), null, callback);
            } else {
                TapTapCloudSave.updateArchive(uuid, info, snapshot.getAbsolutePath(), null, callback);
            }
        } catch (Exception error) {
            if (snapshot != null) snapshot.delete();
            writing.set(false);
            sink.send("cloudFailed", id, -1);
        }
    }

    private static JSONObject metadata(ArchiveData archive) {
        JSONObject result = new JSONObject();
        try {
            result.put("uuid", archive.getUuid());
            result.put("file_id", archive.getFileId());
            result.put("name", archive.getName());
            result.put("extra", archive.getExtra());
            result.put("modified_time", archive.getModifiedTime());
        } catch (JSONException ignored) { /* All keys are constants. */ }
        return result;
    }

    // The Kotlin interface has abstract Java methods, including unused results.
    private class Request implements TapCloudSaveRequestCallback {
        private final String owner;
        private final int id;
        private final int epoch = generation;
        private final AtomicBoolean finished = new AtomicBoolean();
        Request(String owner, int id) { this.owner = owner; this.id = id; }
        void release() {}
        void complete(String operation, String payload) {
            if (!finished.compareAndSet(false, true)) return;
            release();
            if (epoch == generation && valid(owner)) sink.send("cloudCompleted", id, operation, payload);
        }
        @Override public void onRequestError(int code, String message) {
            if (!finished.compareAndSet(false, true)) return;
            release();
            if (epoch == generation && valid(owner)) sink.send("cloudFailed", id, code);
        }
        @Override public void onArchiveCreated(ArchiveData archive) {}
        @Override public void onArchiveUpdated(ArchiveData archive) {}
        @Override public void onArchiveDeleted(ArchiveData archive) {}
        @Override public void onArchiveListResult(List<ArchiveData> archives) {}
        @Override public void onArchiveDataResult(byte[] bytes) {}
        @Override public void onArchiveCoverResult(byte[] bytes) {}
    }
}
