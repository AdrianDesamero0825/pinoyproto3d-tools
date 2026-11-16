(() => {
  const IDLE_TIMEOUT_MS = 15 * 60 * 1000;
  const ACTIVITY_KEY = "pinoyproto3d-admin-last-activity";
  const SIGNOUT_LOCK_KEY = "pinoyproto3d-admin-idle-signout";
  const ACTIVITY_EVENTS = ["pointerdown", "keydown", "scroll", "touchstart"];

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

    function scheduleTimeout() {
      window.clearTimeout(timerId);
      if (!sessionActive || signingOut) return;

      const lastActivity = readLastActivity();
      if (!lastActivity) {
        writeLastActivity();
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
      if (now - lastActivityWrite >= 5000) writeLastActivity(now);
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
        writeLastActivity();
      } else if (!readLastActivity()) {
        writeLastActivity();
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
