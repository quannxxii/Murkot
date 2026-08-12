/* Murkot Web Push service worker — works when the tab is closed/backgrounded. */

self.addEventListener('push', (event) => {
  event.waitUntil(handlePush(event));
});

async function handlePush(event) {
  let payload = { title: 'Murkot', body: 'Новое сообщение', conversationId: '' };
  try {
    if (event.data) {
      payload = { ...payload, ...event.data.json() };
    }
  } catch (_) {
    try {
      payload.body = event.data ? event.data.text() : payload.body;
    } catch (_) {}
  }

  // App focused in a tab: realtime + local Notification handle it.
  // Backgrounded / other windows only: still show OS notification.
  const clientsList = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });
  if (clientsList.some((c) => c.focused)) return;

  await self.registration.showNotification(payload.title || 'Murkot', {
    body: payload.body || '',
    tag: payload.conversationId || 'murkot',
    data: { conversationId: payload.conversationId || '' },
    renotify: true,
  });
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const conversationId = event.notification.data?.conversationId || '';
  const targetUrl = conversationId
    ? `/?chat=${encodeURIComponent(conversationId)}`
    : '/';

  event.waitUntil(
    (async () => {
      const clientsList = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      for (const client of clientsList) {
        if ('focus' in client) {
          await client.focus();
          client.postMessage({ type: 'open_chat', conversationId });
          return;
        }
      }
      await self.clients.openWindow(targetUrl);
    })(),
  );
});
