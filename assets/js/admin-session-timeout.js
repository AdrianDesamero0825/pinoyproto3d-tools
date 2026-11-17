(() => {
  const IDLE_TIMEOUT_MS = 15 * 60 * 1000;
  const ACTIVITY_KEY = "pinoyproto3d-admin-last-activity";
  const SIGNOUT_LOCK_KEY = "pinoyproto3d-admin-idle-signout";
  const ACTIVITY_EVENTS = ["pointerdown", "keydown", "scroll", "touchstart"];
  const SUPABASE_STORAGE_KEY = "pinoyproto3d-shared-auth-session";

  window.createAdminSupabaseClient = function createAdminSupabaseClient() {
    // Older versions overwrote Supabase's own storage key with a partial token mirror.
    // Remove only that malformed value so Supabase can start with a clean session store.
    try {
      const storedValue = localStorage.getItem(SUPABASE_STORAGE_KEY);
      if (storedValue) {
        let storedSession = null;
        try { storedSession = JSON.parse(storedValue); } catch (_error) {}
        const isSupabaseSession = storedSession
          && typeof storedSession.access_token === "string"
          && typeof storedSession.refresh_token === "string"
          && typeof storedSession.expires_at === "number"
          && storedSession.user
          && typeof storedSession.user === "object";
        if (!isSupabaseSession) localStorage.removeItem(SUPABASE_STORAGE_KEY);
      }
    } catch (_error) { /* Supabase handles unavailable browser storage itself. */ }

    const client = window.supabase.createClient("https://cifxwhhdkmecgomwesnk.supabase.co", "sb_publishable_4-at96mA3nKEH6t2irolAg_20waHMZo", {
      auth: { storageKey: SUPABASE_STORAGE_KEY, persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });
    return client;
  };

  window.installAdminSessionTimeout = function installAdminSessionTimeout(supabaseClient) {
    let sessionActive = false;
    let timerId = null;
    let lastActivityWrite = 0;
    let inMemoryActivity = 0;
    let signingOut = false;

    function readLastActivity() {
      let storedValue = null;
      try {
        storedValue = localStorage.getItem(ACTIVITY_KEY);
      } catch (_error) {
        return inMemoryActivity || null;
      }
      const timestamp = Number(storedValue);
      return Number.isFinite(timestamp) && timestamp > 0 ? timestamp : null;
    }

    function writeLastActivity(timestamp = Date.now()) {
      inMemoryActivity = timestamp;
      try {
        localStorage.setItem(ACTIVITY_KEY, String(timestamp));
      } catch (_error) {
        // Keep the timeout functional for this tab when browser storage is unavailable.
      }
      lastActivityWrite = timestamp;
    }

    function writeSharedActivity(timestamp = Date.now()) {
      writeLastActivity(timestamp);
      try { localStorage.setItem(ACTIVITY_KEY, String(timestamp)); } catch (_error) {}
    }

    function scheduleTimeout() {
      window.clearTimeout(timerId);
      if (!sessionActive || signingOut) return;

      const lastActivity = readLastActivity();
      if (!lastActivity) {
        writeSharedActivity();
        return scheduleTimeout();
      }

      const remaining = IDLE_TIMEOUT_MS - (Date.now() - lastActivity);
      if (remaining <= 0) {
        expireIfStillIdle();
        return;
      }

      timerId = window.setTimeout(expireIfStillIdle, remaining);
    }

    async function expireIfStillIdle() {
      if (!sessionActive || signingOut) return;
      const lastActivity = readLastActivity();
      if (lastActivity && Date.now() - lastActivity < IDLE_TIMEOUT_MS) {
        scheduleTimeout();
        return;
      }

      let previousLock = 0;
      try {
        previousLock = Number(localStorage.getItem(SIGNOUT_LOCK_KEY));
      } catch (_error) {
        previousLock = 0;
      }
      if (previousLock && Date.now() - previousLock < 10000) {
        timerId = window.setTimeout(expireIfStillIdle, 1000);
        return;
      }

      signingOut = true;
      try {
        localStorage.setItem(SIGNOUT_LOCK_KEY, String(Date.now()));
      } catch (_error) {
        // The local sign-out still runs when cross-tab coordination is unavailable.
      }
      try {
        await supabaseClient.auth.signOut({ scope: "local" });
      } catch (_error) {
        // Continue clearing the page's local admin state if the network request fails.
      } finally {
        sessionActive = false;
        window.clearTimeout(timerId);
        try {
          localStorage.removeItem(SIGNOUT_LOCK_KEY);
        } catch (_error) {
          // Ignore unavailable browser storage.
        }
        window.dispatchEvent(new CustomEvent("admin-idle-timeout", { detail: { timeoutMinutes: IDLE_TIMEOUT_MS / 60000 } }));
      }
    }

    function recordActivity() {
      if (!sessionActive || document.visibilityState === "hidden") return;
      const now = Date.now();
      if (now - lastActivityWrite >= 5000) writeSharedActivity(now);
      scheduleTimeout();
    }

    ACTIVITY_EVENTS.forEach((eventName) => {
      window.addEventListener(eventName, recordActivity, { capture: true, passive: true });
    });

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") scheduleTimeout();
    });

    window.addEventListener("storage", (event) => {
      if (event.key === ACTIVITY_KEY && event.newValue && sessionActive) scheduleTimeout();
    });

    const { data: authListener } = supabaseClient.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session) {
        sessionActive = false;
        signingOut = false;
        inMemoryActivity = 0;
        window.clearTimeout(timerId);
        return;
      }

      sessionActive = true;
      if (event === "SIGNED_IN") {
        try {
          localStorage.removeItem(SIGNOUT_LOCK_KEY);
        } catch (_error) {
          // Ignore unavailable browser storage.
        }
        writeSharedActivity();
      } else if (!readLastActivity()) {
        writeSharedActivity();
      }
      scheduleTimeout();
    });

    supabaseClient.auth.getSession().then(({ data, error }) => {
      if (error || !data.session || sessionActive) return;
      sessionActive = true;
      if (!readLastActivity()) writeLastActivity();
      scheduleTimeout();
    }).catch(() => {});

    return () => {
      window.clearTimeout(timerId);
      ACTIVITY_EVENTS.forEach((eventName) => window.removeEventListener(eventName, recordActivity, { capture: true }));
      authListener.subscription.unsubscribe();
    };
  };
})();
