// タイマーの状態を、ページ(部品)の外で1つだけ持つ。Turbo で画面が替わっても JS の実行環境は残るので、
// 画面移動しても保たれる。さらに localStorage に保存して、リロード・アプリの再起動からも復元する。
// 複数のタブは localStorage の変更(storage イベント / BroadcastChannel)で同期する。
import * as M from "./timer_math.mjs"
import { notifyFinished } from "./notifier.js"

const LAST_SEEN_WRITE_INTERVAL_MS = 5000
const listeners = new Set()
let channel = null
try { if ("BroadcastChannel" in window) channel = new BroadcastChannel("ohalog-timer") } catch (_error) { channel = null }

// ユーザーごとにキーを分ける(同じブラウザで別アカウントに替えても混ざらない)
const storageKey = () => `ohalog.timer.v1.${document.body?.dataset.userId || "anon"}`

function read({ settle = true } = {}) {
  try { return M.restore(localStorage.getItem(storageKey()), Date.now(), { settle }) } catch (_error) { return null }
}

function write(state) {
  try {
    if (state) localStorage.setItem(storageKey(), JSON.stringify(state))
    else localStorage.removeItem(storageKey())
  } catch (_error) { /* 保存できない環境(プライベートモード等)でも、画面上の動作は続ける */ }
  emit()
  try { channel?.postMessage("changed") } catch (_error) { /* 何もしない */ }
}

function emit() { listeners.forEach((fn) => { try { fn() } catch (error) { console.error(error) } }) }

window.addEventListener("storage", (event) => { if (event.key === storageKey()) emit() })
channel && (channel.onmessage = emit)

class TimerStore {
  // いまの状態(時計の巻き戻しの補正と、終了済みの判定を反映して返す。書き込みはしない)
  current() { return read() }

  // 連打や複数タブでも、タイマーが2つ作られないよう、すでにあれば作らず理由を返す
  start({ activityKey, label, anchor, totalMs }) {
    const existing = read()
    if (existing) return { ok: false, reason: existing.activityKey === activityKey ? "running" : "busy", state: existing }
    const id = (crypto.randomUUID?.() ?? `${Date.now()}-${Math.random()}`)
    const state = M.start({ id, activityKey, label, anchor, totalMs, now: Date.now() })
    write(state)
    return { ok: true, state }
  }

  pause() { return this.#update((s, now) => M.pause(s, now)) }
  resume() { return this.#update((s, now) => M.resume(s, now)) }

  // 「ここまででOK」。1秒未満なら状態を破棄して null を返す
  stop() {
    const s = read()
    if (!s) return null
    const stopped = M.stop(s, Date.now())
    write(stopped)
    return stopped
  }

  // 終了予定を過ぎていれば finished にして保存し、完了通知を(全タブで一度だけ)出す。
  // justFinished は、この呼び出しで終わりに変わったときだけ true
  settle() {
    const raw = read({ settle: false }) // 終わる瞬間を検知するため、完了に直さない状態で読む
    if (!raw) return { state: null, justFinished: false }
    const now = Date.now()
    const { state, justFinished } = M.settle(raw, now)
    if (justFinished) {
      write(state)
      this.#notifyOnce()
    } else if (state.status === "running" && now - state.lastSeenAt > LAST_SEEN_WRITE_INTERVAL_MS) {
      write({ ...state, lastSeenAt: now }) // 時計の巻き戻しを検知するため、最後に観測した時刻を時々残す
    }
    return { state: justFinished ? state : read(), justFinished }
  }

  // 送信中の印(タブをまたいだ二重送信を防ぐ)。送れる状態なら true
  claimSubmit() {
    const s = read()
    if (!s || s.status !== "finished") return null
    const now = Date.now()
    if (s.submittingAt && now - s.submittingAt < 15000) return null
    const next = { ...s, submittingAt: now }
    write(next)
    return next
  }

  // サーバーに記録された(またはもう記録済み)ので、状態を片付ける
  clear(activityKey) {
    const s = read()
    if (s && (!activityKey || s.activityKey === activityKey)) write(null)
  }

  subscribe(fn) {
    listeners.add(fn)
    return () => listeners.delete(fn)
  }

  #update(fn) {
    const s = read()
    if (!s) return null
    const next = fn(s, Date.now())
    write(next)
    return next
  }

  // 通知済みの印を先に保存してから通知する。別のタブが先に印を付けていたら出さない
  #notifyOnce() {
    const s = read()
    if (!s || s.notifiedAt) return
    const marked = { ...s, notifiedAt: Date.now() }
    write(marked)
    notifyFinished(marked)
  }
}

export const timerStore = new TimerStore()
