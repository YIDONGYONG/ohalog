// 完了通知。ページが開いている間(別タブ・バックグラウンドを含む)に出せる通知だけを扱う。
// ブラウザを完全に閉じている間の通知は、Web Push(サーバーからの送信)が必要で、ここでは対応しない。

// 許可のお願いは、必ずユーザーのタップの中(「はじめる」を押した直後)で行う
export function ensurePermission() {
  try {
    if ("Notification" in window && Notification.permission === "default") Notification.requestPermission()
  } catch (_error) { /* 未対応のブラウザでは何もしない */ }
}

// 完了を知らせる。tag を固定して、複数のタブから呼ばれても1件にまとめる
export async function notifyFinished(state) {
  try {
    if (!("Notification" in window) || Notification.permission !== "granted") return
    const title = "おはログ"
    const options = {
      body: `${state.label || "タイマー"}、できました。おつかれさまでした。`,
      tag: "ohalog-timer", icon: "/icon.png", data: { path: "/routines" }
    }
    // 登録済みの Service Worker があればそちらで通知する(スマホのブラウザはこちらが必要)。
    // ready は登録がないと永遠に終わらないので、getRegistration で「あるか」だけを確認する
    const registration = await navigator.serviceWorker?.getRegistration()
    if (registration?.active) return registration.showNotification(title, options)
    new Notification(title, options)
  } catch (_error) { /* 通知できなくても完了処理は止めない */ }
}
