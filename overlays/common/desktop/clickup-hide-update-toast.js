
// lastRefreshTimeInMs at Date's max (8.64e15) passes the web app's "refreshed under 25 min ago" skip, so the update toast never starts.
;try {
  sessionStorage.setItem(
    "DESKTOP_APP_VERSION_REFRESH_@version@",
    JSON.stringify({ lastRefreshTimeInMs: 8.64e15, userSnoozeCount: 0 }),
  );
} catch (error) {
  console.error("clickup-hide-update-toast: could not pre-fill the force-refresh session key", error);
}
