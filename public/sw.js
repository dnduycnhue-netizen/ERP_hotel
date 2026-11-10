/* Service worker (T-046) — viet tay, khong them thu vien.
 *
 * Ly do khong dung @serwist/next: Next 16 dung Turbopack mac dinh, con
 * Serwist chen code qua webpack plugin (chua kiem chung duoi Turbopack
 * trong repo nay); nhu cau chi la precache app shell + cache dieu huong
 * cho 4 man offline + hien thong bao push — viet tay ~200 dong la du,
 * khong them dependency, khong sua lockfile.
 *
 * Nguyen tac an toan:
 * - CHI cache tai nguyen tinh (/_next/static, /icons, manifest) va HTML
 *   dieu huong cua /, /login, /offline, /m/* (4 man offline).
 * - KHONG cache /api/*, khong cache RSC payload hay bat ky fetch nao
 *   khac (du lieu dong). Khong cham IndexedDB — queue offline Dexie
 *   (T-025/T-033) hoat dong doc lap, khong phu thuoc service worker.
 * - Tang CACHE_VERSION moi khi doi app shell/manifest de client cu
 *   khong dung cache cu.
 */

const CACHE_VERSION = "v1";
const SHELL_CACHE = `erp-shell-${CACHE_VERSION}`;
const PAGES_CACHE = `erp-pages-${CACHE_VERSION}`;
const STATIC_CACHE = `erp-static-${CACHE_VERSION}`;

const PRECACHE_URLS = [
  "/login",
  "/offline",
  "/icons/icon-192.png",
  "/icons/apple-touch-icon.png",
  "/manifest.webmanifest",
];

/**
 * Duong dieu huong duoc cache de mo offline: trang chu, login, trang
 * offline, va moi man hien truong /m/* (nhan hang, kiem ke, xe day
 * buong phong, kiem minibar). Cac duong desktop khac chi qua mang;
 * mat mang thi ve trang /offline.
 */
function isOfflineRoute(pathname) {
  return (
    pathname === "/" ||
    pathname === "/login" ||
    pathname === "/offline" ||
    pathname.startsWith("/m/")
  );
}

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter(
              (key) =>
                key.startsWith("erp-") &&
                key !== SHELL_CACHE &&
                key !== PAGES_CACHE &&
                key !== STATIC_CACHE,
            )
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

async function cacheFirst(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) {
    return cached;
  }
  const response = await fetch(request);
  if (response.ok) {
    await cache.put(request, response.clone());
  }
  return response;
}

async function networkFirstNavigation(request) {
  const url = new URL(request.url);
  const cacheable = isOfflineRoute(url.pathname);
  try {
    const response = await fetch(request);
    if (cacheable && response.ok) {
      const cache = await caches.open(PAGES_CACHE);
      await cache.put(request, response.clone());
    }
    return response;
  } catch {
    if (cacheable) {
      const cached = await caches.match(request, { ignoreVary: true });
      if (cached) {
        return cached;
      }
    }
    const offline = await caches.match("/offline", { ignoreVary: true });
    if (offline) {
      return offline;
    }
    return new Response("Bạn đang ngoại tuyến.", {
      status: 503,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") {
    return;
  }
  const url = new URL(request.url);
  // Tai nguyen ngoai origin (Supabase, storage): khong cache.
  if (url.origin !== self.location.origin) {
    return;
  }
  // Du lieu dong: chi qua mang, khong bao gio cache.
  if (url.pathname.startsWith("/api/")) {
    return;
  }
  if (
    url.pathname.startsWith("/_next/static/") ||
    url.pathname.startsWith("/icons/") ||
    url.pathname === "/manifest.webmanifest"
  ) {
    event.respondWith(cacheFirst(request, STATIC_CACHE));
    return;
  }
  if (request.mode === "navigate") {
    event.respondWith(networkFirstNavigation(request));
    return;
  }
  // RSC payload, anh, fetch khac: chi qua mang.
});

/**
 * Web push (T-045): Edge Function gui payload { title, body } (khong
 * kem link — xem Q103). Bam vao thong bao mo app (uu tien tab dang mo).
 */
self.addEventListener("push", (event) => {
  let title = "Mini-ERP";
  let body = "";
  try {
    if (event.data) {
      const data = event.data.json();
      if (data && typeof data.title === "string" && data.title !== "") {
        title = data.title;
      }
      if (data && typeof data.body === "string") {
        body = data.body;
      }
    }
  } catch {
    // Payload khong phai JSON — giu tieu de mac dinh.
  }
  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: "/icons/icon-192.png",
      badge: "/icons/icon-192.png",
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((clients) => {
        for (const client of clients) {
          if ("focus" in client) {
            return client.focus();
          }
        }
        return self.clients.openWindow("/");
      }),
  );
});

self.addEventListener("message", (event) => {
  if (!event.data || typeof event.data.type !== "string") {
    return;
  }
  if (event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
    return;
  }
  if (event.data.type === "CLEAR_CACHES") {
    event.waitUntil(
      caches
        .keys()
        .then((keys) => Promise.all(keys.map((key) => caches.delete(key)))),
    );
  }
});
