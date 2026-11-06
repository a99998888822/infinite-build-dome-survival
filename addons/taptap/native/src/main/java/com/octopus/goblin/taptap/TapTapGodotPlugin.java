package com.octopus.goblin.taptap;

import android.app.Activity;
import android.util.Log;
import com.taptap.sdk.compliance.TapTapCompliance;
import com.taptap.sdk.compliance.TapTapComplianceCallback;
import com.taptap.sdk.compliance.option.TapTapComplianceOptions;
import com.taptap.sdk.core.TapTapRegion;
import com.taptap.sdk.core.TapTapSdk;
import com.taptap.sdk.core.TapTapSdkOptions;
import com.taptap.sdk.initializer.api.TapInitCallback;
import com.taptap.sdk.initializer.api.model.ScreenOrientation;
import com.taptap.sdk.kit.internal.callback.TapTapCallback;
import com.taptap.sdk.kit.internal.exception.TapTapException;
import com.taptap.sdk.login.Scopes;
import com.taptap.sdk.login.TapTapAccount;
import com.taptap.sdk.login.TapTapLogin;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONException;
import org.json.JSONObject;

/** No SDK initialization or account lookup occurs before explicit privacy consent. */
public final class TapTapGodotPlugin extends GodotPlugin {
    private static final String AUDIT_TAG = "TapTapComplianceBridge";
    private static final String BRIDGE_REVISION = "compliance-v2";
    private boolean initialized;
    private boolean initializing;
    private boolean loginInProgress;
    private volatile boolean destroyed;
    private TapInitCallback initCallback;
    private TapTapComplianceCallback complianceCallback;
    private int complianceGeneration;
    private boolean complianceInProgress;

    public TapTapGodotPlugin(Godot godot) { super(godot); }

    @Override public String getPluginName() { return "TapTapGodot"; }

    @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
            new SignalInfo("initializationCompleted", Boolean.class, Integer.class, String.class),
            new SignalInfo("accountRestored", String.class),
            new SignalInfo("loginCompleted", String.class),
            new SignalInfo("loginFailed", Integer.class, String.class),
            new SignalInfo("loginCancelled"),
            new SignalInfo("logoutCompleted"),
            new SignalInfo("logoutFailed", Integer.class, String.class),
            new SignalInfo("complianceResult", Integer.class, Integer.class)
        ));
    }

    private void deliver(String name, Object... args) {
        runOnRenderThread(() -> { if (!destroyed) emitSignal(name, args); });
    }

    @UsedByGodot public void initialize(String clientId, String clientToken) {
        runOnUiThread(() -> {
            if (destroyed || initializing) return;
            if (initialized) {
                deliver("initializationCompleted", true, 0, "");
                return;
            }
            Activity activity = getActivity();
            if (activity == null || activity.isFinishing()) {
                deliver("initializationCompleted", false, -1, "Activity unavailable");
                return;
            }
            if (clientId.isEmpty() || clientToken.isEmpty()) {
                deliver("initializationCompleted", false, -1000, "Missing SDK configuration");
                return;
            }
            initializing = true;
            initCallback = new TapInitCallback() {
                @Override public void onInitSuccess() {
                    initializing = false;
                    initialized = true;
                    TapTapSdk.removeInitCallback(this);
                    audit("initialized", 0, 0);
                    deliver("initializationCompleted", true, 0, "");
                }
                @Override public void onInitFail(int code, String message) {
                    initializing = false;
                    TapTapSdk.removeInitCallback(this);
                    audit("initialization_failed", 0, code);
                    // Do not send SDK internals or credentials to application logs.
                    deliver("initializationCompleted", false, code, "TapSDK initialization failed");
                }
            };
            try {
                TapTapSdkOptions options = new TapTapSdkOptions(clientId, clientToken, TapTapRegion.CN);
                options.setScreenOrientation(ScreenOrientation.LANDSCAPE);
                options.setEnableLog(false);
                TapTapSdk.addInitCallback(initCallback);
                TapTapSdk.init(activity.getApplicationContext(), options,
                    new TapTapComplianceOptions(true, false));
            } catch (Exception error) {
                initializing = false;
                TapTapSdk.removeInitCallback(initCallback);
                deliver("initializationCompleted", false, -1, "TapSDK initialization exception");
            }
        });
    }

    @UsedByGodot public void restoreAccount() {
        runOnUiThread(() -> {
            if (!initialized || destroyed) return;
            try {
                deliver("accountRestored", profile(TapTapLogin.getCurrentTapAccount()));
            } catch (Exception error) {
                deliver("accountRestored", "{}");
            }
        });
    }

    @UsedByGodot public void login() {
        runOnUiThread(() -> {
            if (destroyed || loginInProgress) return;
            Activity activity = getActivity();
            if (!initialized || activity == null || activity.isFinishing()) {
                deliver("loginFailed", -1, "SDK or Activity unavailable");
                return;
            }
            loginInProgress = true;
            try {
                TapTapLogin.loginWithScopes(activity, new String[]{Scopes.SCOPE_BASIC_INFO},
                    new TapTapCallback<TapTapAccount>() {
                        @Override public void onSuccess(TapTapAccount account) {
                            loginInProgress = false;
                            deliver("loginCompleted", profile(account));
                        }
                        @Override public void onCancel() {
                            loginInProgress = false;
                            deliver("loginCancelled");
                        }
                        @Override public void onFail(TapTapException error) {
                            loginInProgress = false;
                            deliver("loginFailed", -1, "TapTap authorization failed");
                        }
                    });
            } catch (Exception error) {
                loginInProgress = false;
                deliver("loginFailed", -1, "Unable to start TapTap authorization");
            }
        });
    }

    @UsedByGodot public void startCompliance(String openId, int requestId) {
        runOnUiThread(() -> {
            if (destroyed || complianceInProgress) return;
            Activity activity = getActivity();
            try {
                TapTapAccount account = initialized ? TapTapLogin.getCurrentTapAccount() : null;
                if (account == null || openId.isEmpty() || !openId.equals(account.getOpenId())
                        || activity == null || activity.isFinishing()) {
                    deliver("complianceResult", requestId, 1200);
                    return;
                }
                clearComplianceCallback();
                final int generation = complianceGeneration;
                complianceInProgress = true;
                complianceCallback = (code, extra) -> runOnUiThread(() -> {
                    if (destroyed || generation != complianceGeneration) return;
                    complianceInProgress = false;
                    audit("result", requestId, code);
                    // Keep listening after startup: time limits and account switching
                    // can arrive while playing or from the SDK's restriction dialog.
                    deliver("complianceResult", requestId, code);
                });
                TapTapCompliance.registerComplianceCallback(complianceCallback);
                audit("startup", requestId, 0);
                TapTapCompliance.startup(activity, account.getOpenId());
            } catch (Exception error) {
                clearComplianceCallback();
                audit("startup_failed", requestId, 1200);
                deliver("complianceResult", requestId, 1200);
            }
        });
    }

    private static void audit(String event, int requestId, int code) {
        // Only bridge events and result codes: no account, credential or SDK extras.
        Log.i(AUDIT_TAG, "revision=" + BRIDGE_REVISION + " event=" + event
            + " request=" + requestId + " code=" + code);
    }

    private void clearComplianceCallback() {
        complianceGeneration++;
        complianceInProgress = false;
        if (complianceCallback != null) {
            TapTapCompliance.unregisterComplianceCallback(complianceCallback);
            complianceCallback = null;
        }
    }

    @UsedByGodot public void logout() {
        runOnUiThread(() -> {
            if (destroyed) return;
            if (loginInProgress || !initialized) {
                deliver("logoutFailed", -1, "SDK busy or unavailable");
                return;
            }
            try {
                // Invalidate callbacks before exit(), which can itself emit 1000.
                clearComplianceCallback();
                TapTapCompliance.exit();
                TapTapLogin.logout();
                deliver("logoutCompleted");
            } catch (Exception error) {
                deliver("logoutFailed", -1, "Unable to clear TapTap session");
            }
        });
    }

    private static String profile(TapTapAccount account) {
        if (account == null) return "{}";
        JSONObject result = new JSONObject();
        try {
            result.put("open_id", account.getOpenId());
            result.put("union_id", account.getUnionId());
            // Tokens remain owned by TapSDK. Never serialize TapTapAccount itself.
        } catch (JSONException ignored) { return "{}"; }
        return result.toString();
    }

    @Override public void onMainDestroy() {
        destroyed = true;
        clearComplianceCallback();
        if (initCallback != null) TapTapSdk.removeInitCallback(initCallback);
        super.onMainDestroy();
    }
}
