(() => {
  const IDLE_TIMEOUT_MS = 15 * 60 * 1000;
  const ACTIVITY_KEY = "pinoyproto3d-admin-last-activity";
  const SIGNOUT_LOCK_KEY = "pinoyproto3d-admin-idle-signout";
  const SESSION_KEY = "pinoyproto3d-shared-auth-session";
  const ACTIVITY_EVENTS = ["pointerdown", "keydown", "scroll", "touchstart"];

  window.createAdminSupabaseClient = function createAdminSupabaseClient() {
    const client = window.supabase.createClient("https://cifxwhhdkmecgomwesnk.supabase.co", "sb_publishable_4-at96mA3nKEH6t2irolAg_20waHMZo", {
      auth: { storageKey: "pinoyproto3d-shared-auth-session", persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });
    const originalSetSession = client.auth.setSession.bind(client.auth);
    let applyingSharedSession = false;
    client.auth.setSession = async (tokens) => {
      applyingSharedSession = true;
      try { return await originalSetSession(tokens); }
      finally { applyingSharedSession = false; }
    };
    const { data: listener } = client.auth.onAuthStateChange((event, session) => {
      if (applyingSharedSession) return;
      try {
        if (session && ["SIGNED_IN", "TOKEN_REFRESHED", "USER_UPDATED"].includes(event)) {
          localStorage.setItem(SESSION_KEY, JSON.stringify({ access_token:session.access_token, refresh_token:session.refresh_token, event:Date.now() }));
        } else if (event === "SIGNED_OUT" || !session) {
          localStorage.removeItem(SESSION_KEY);
        }
      } catch (_error) { /* The in-tab Supabase session continues to work without browser storage. */ }
    });
    client.auth.getSession().then(({ data, error }) => {
      if (error || !data.session) return;
      try {
        if (!localStorage.getItem(SESSION_KEY)) {
          localStorage.setItem(SESSION_KEY, JSON.stringify({ access_token:data.session.access_token, refresh_token:data.session.refresh_token, event:Date.now() }));
        }
      } catch (_error) { /* The in-tab Supabase session continues to work without browser storage. */ }
    });
    window.addEventListener("storage", async (event) => {
      if (event.key !== SESSION_KEY) return;
      let currentSession = null;
      try { currentSession = (await client.auth.getSession()).data.session; } catch (_error) {}
      if (!event.newValue) {
        if (currentSession) await client.auth.signOut({ scope:"local" });
        return;
      }
      try {
        const shared = JSON.parse(event.newValue);
        if (shared.access_token && shared.refresh_token && shared.access_token !== currentSession?.access_token) {
          await client.auth.setSession({ access_token:shared.access_token, refresh_token:shared.refresh_token });
        }
      } catch (_error) { /* Ignore malformed or expired shared session data. */ }
    });
    window.addEventListener("beforeunload", () => listener.subscription.unsubscribe(), { once:true });
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
