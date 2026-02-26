// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Presence, Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/rumbl"
import topbar from "../vendor/topbar"

let youtubeIframeApiPromise

function loadYoutubeIframeApi() {
  if (window.YT?.Player) {
    return Promise.resolve(window.YT)
  }

  if (youtubeIframeApiPromise) {
    return youtubeIframeApiPromise
  }

  youtubeIframeApiPromise = new Promise(resolve => {
    const existing = document.querySelector("script[data-youtube-iframe-api]")
    if (!existing) {
      const script = document.createElement("script")
      script.src = "https://www.youtube.com/iframe_api"
      script.async = true
      script.dataset.youtubeIframeApi = "true"
      document.head.appendChild(script)
    }

    const prev = window.onYouTubeIframeAPIReady
    window.onYouTubeIframeAPIReady = () => {
      if (typeof prev === "function") {
        prev()
      }
      resolve(window.YT)
    }
  })

  return youtubeIframeApiPromise
}

function setTheme(theme) {
  if (theme === "system") {
    localStorage.removeItem("phx:theme")
    document.documentElement.removeAttribute("data-theme")
    return
  }

  localStorage.setItem("phx:theme", theme)
  document.documentElement.setAttribute("data-theme", theme)
}

const ThemeSwitch = {
  mounted() {
    const storedTheme = localStorage.getItem("phx:theme")
    const currentTheme = document.documentElement.getAttribute("data-theme")
    this.el.checked = (currentTheme || storedTheme) === "dark"

    this.handleChange = () => {
      setTheme(this.el.checked ? "dark" : "light")
    }

    this.el.addEventListener("change", this.handleChange)
  },

  destroyed() {
    if (this.handleChange) {
      this.el.removeEventListener("change", this.handleChange)
    }
  }
}

const VideoWatch = {
  mounted() {
    const token = this.el.dataset.userToken
    const videoId = this.el.dataset.id
    this.roomCode = this.el.dataset.roomCode
    this.roomHostId = Number.parseInt(this.el.dataset.roomHostId || "", 10)
    this.initialRoomPlaying = this.el.dataset.roomPlaying === "true"
    this.initialRoomCurrentMs = Number.parseInt(this.el.dataset.roomCurrentMs || "0", 10) || 0
    this.currentUserId = Number.parseInt(this.el.dataset.currentUserId || "", 10)
    this.isRoomHost =
      Number.isInteger(this.currentUserId) &&
      Number.isInteger(this.roomHostId) &&
      this.currentUserId === this.roomHostId
    this.roomSyncSuppressed = false

    if (!token || !videoId) {
      return
    }

    this.videoSocket = new Socket("/socket", {params: {token}})
    this.videoSocket.connect()

    this.channel = this.videoSocket.channel(`video:${videoId}`, {})
    this.channel.on("new_annotation", annotation => this.renderAnnotation(annotation))
    this.channel.on("annotation_updated", annotation => this.updateAnnotation(annotation))
    this.channel.on("annotation_deleted", payload => this.removeAnnotation(payload.id))
    this.channel
      .join()
      .receive("error", reason => console.error("Video channel join failed", reason))

    if (this.roomCode) {
      this.setupRoomSync()
    } else {
      this.setupLocalPlayerForAnnotations()
    }

    this.form = this.el.querySelector("#annotation-form")
    if (this.form) {
      this.handleSubmit = event => {
        event.preventDefault()

        const bodyEl = this.el.querySelector("#annotation-body")
        const body = (bodyEl?.value || "").trim()
        const at = this.currentAnnotationMs()

        if (!body) {
          return
        }

        this.channel
          .push("new_annotation", {body, at})
          .receive("ok", () => {
            if (bodyEl) {
              bodyEl.value = ""
            }
          })
          .receive("error", error => console.error("Failed to post annotation", error))
      }

      this.form.addEventListener("submit", this.handleSubmit)
    }

    this.annotationsContainer = this.el.querySelector("#annotations")
    if (this.annotationsContainer) {
      this.handleAnnotationAction = event => {
        const toggleButton = event.target.closest("[data-menu-toggle][data-id]")
        if (toggleButton) {
          event.preventDefault()
          event.stopPropagation()
          this.toggleMenu(toggleButton.dataset.id)
          return
        }

        const actionButton = event.target.closest("[data-action][data-id]")
        if (!actionButton) {
          return
        }

        const annotationId = actionButton.dataset.id
        if (!annotationId) {
          return
        }

        if (actionButton.dataset.action === "edit") {
          this.closeAllMenus()
          this.requestEdit(annotationId)
          return
        }

        if (actionButton.dataset.action === "delete") {
          this.closeAllMenus()
          this.requestDelete(annotationId)
        }
      }

      this.annotationsContainer.addEventListener("click", this.handleAnnotationAction)
    }

    this.handleDocumentClick = event => {
      if (!event.target.closest("[data-menu-toggle]") && !event.target.closest("[id^='annotation-menu-']")) {
        this.closeAllMenus()
      }
    }

    document.addEventListener("click", this.handleDocumentClick)
  },

  destroyed() {
    if (this.form && this.handleSubmit) {
      this.form.removeEventListener("submit", this.handleSubmit)
    }

    if (this.annotationsContainer && this.handleAnnotationAction) {
      this.annotationsContainer.removeEventListener("click", this.handleAnnotationAction)
    }

    if (this.handleDocumentClick) {
      document.removeEventListener("click", this.handleDocumentClick)
    }

    if (this.channel) {
      this.channel.leave()
    }

    if (this.roomChannel) {
      this.roomChannel.leave()
    }

    if (this.videoSocket) {
      this.videoSocket.disconnect()
    }

    if (this.roomHeartbeat) {
      window.clearInterval(this.roomHeartbeat)
    }
  },

  setupRoomSync() {
    this.roomChannel = this.videoSocket.channel(`watch_room:${this.roomCode}`, {})
    this.roomChannel.on("playback_synced", payload => this.applyRoomSync(payload))

    this.roomChannel
      .join()
      .receive("ok", payload => {
        this.roomState = payload?.room || {}
        this.initRoomPlayer()
      })
      .receive("error", reason => {
        console.error("Watch room sync join failed", reason)
      })
  },

  async setupLocalPlayerForAnnotations() {
    try {
      await loadYoutubeIframeApi()
    } catch (_error) {
      return
    }

    if (!window.YT?.Player) {
      return
    }

    this.annotationPlayer = new window.YT.Player("video-player")
  },

  async initRoomPlayer() {
    try {
      await loadYoutubeIframeApi()
    } catch (_error) {
      return
    }

    if (!window.YT?.Player) {
      return
    }

    this.roomPlayer = new window.YT.Player("video-player", {
      events: {
        onReady: () => this.onRoomPlayerReady(),
        onStateChange: event => this.onRoomPlayerStateChange(event),
      },
    })
  },

  onRoomPlayerReady() {
    const roomCurrentMs = this.roomState?.current_ms ?? this.initialRoomCurrentMs
    const roomPlaying =
      typeof this.roomState?.playing === "boolean" ? this.roomState.playing : this.initialRoomPlaying

    this.applyPlaybackState(roomCurrentMs, roomPlaying)

    if (this.isRoomHost) {
      this.roomHeartbeat = window.setInterval(() => {
        if (!this.roomPlayer || this.roomSyncSuppressed) {
          return
        }

        const state = this.roomPlayer.getPlayerState()
        if (state === window.YT.PlayerState.PLAYING) {
          this.pushRoomSync("state", this.currentPlaybackMs(), true)
        }
      }, 3000)
    }
  },

  onRoomPlayerStateChange(event) {
    if (!this.isRoomHost || this.roomSyncSuppressed) {
      return
    }

    const state = event.data
    if (state === window.YT.PlayerState.PLAYING) {
      this.pushRoomSync("play", this.currentPlaybackMs(), true)
      return
    }

    if (state === window.YT.PlayerState.PAUSED) {
      this.pushRoomSync("pause", this.currentPlaybackMs(), false)
    }
  },

  currentPlaybackMs() {
    if (!this.roomPlayer || typeof this.roomPlayer.getCurrentTime !== "function") {
      return 0
    }

    return Math.max(0, Math.floor(this.roomPlayer.getCurrentTime() * 1000))
  },

  currentAnnotationMs() {
    const player = this.roomPlayer || this.annotationPlayer
    if (!player || typeof player.getCurrentTime !== "function") {
      return 0
    }

    return Math.max(0, Math.floor(player.getCurrentTime() * 1000))
  },

  pushRoomSync(action, currentMs, playing) {
    if (!this.roomChannel) {
      return
    }

    this.roomChannel.push("sync_playback", {
      action,
      current_ms: currentMs,
      playing,
    }).receive("error", reason => {
      console.error("Room playback sync failed", reason)
    })
  },

  applyRoomSync(payload) {
    if (!payload) {
      return
    }

    if (Number.isInteger(this.currentUserId) && payload.user_id === this.currentUserId) {
      return
    }

    this.applyPlaybackState(payload.current_ms, payload.playing)
  },

  applyPlaybackState(currentMs, playing) {
    if (!this.roomPlayer) {
      return
    }

    this.roomSyncSuppressed = true

    if (typeof currentMs === "number" && currentMs >= 0) {
      this.roomPlayer.seekTo(currentMs / 1000, true)
    }

    if (playing) {
      this.roomPlayer.playVideo()
    } else {
      this.roomPlayer.pauseVideo()
    }

    window.setTimeout(() => {
      this.roomSyncSuppressed = false
    }, 250)
  },

  renderAnnotation(annotation) {
    const container = this.el.querySelector("#annotations")
    if (!container) {
      return
    }

    const noAnnotations = this.el.querySelector("#no-annotations")
    if (noAnnotations) {
      noAnnotations.remove()
    }

    const wrapper = this.buildAnnotationElement(annotation)
    container.appendChild(wrapper)
    wrapper.scrollIntoView({behavior: "smooth", block: "nearest"})
  },

  updateAnnotation(annotation) {
    const existing = document.getElementById(`annotation-${annotation.id}`)
    if (!existing) {
      this.renderAnnotation(annotation)
      return
    }

    const updated = this.buildAnnotationElement(annotation)
    existing.replaceWith(updated)
  },

  removeAnnotation(annotationId) {
    const existing = document.getElementById(`annotation-${annotationId}`)
    if (existing) {
      existing.remove()
    }

    const container = this.el.querySelector("#annotations")
    if (container && container.children.length === 0 && !this.el.querySelector("#no-annotations")) {
      const noAnnotations = document.createElement("p")
      noAnnotations.id = "no-annotations"
      noAnnotations.className = "mt-4 text-center text-base-content/70"
      noAnnotations.textContent = "No annotations yet. Be the first to comment!"
      container.insertAdjacentElement("afterend", noAnnotations)
    }
  },

  requestEdit(annotationId) {
    const existing = document.getElementById(`annotation-${annotationId}`)
    const currentBody = existing?.querySelector(".annotation-body")?.textContent?.trim() || ""
    const nextBody = window.prompt("Edit annotation", currentBody)

    if (nextBody === null) {
      return
    }

    const body = nextBody.trim()
    if (!body) {
      return
    }

    this.channel
      .push("update_annotation", {id: annotationId, body})
      .receive("error", error => console.error("Failed to edit annotation", error))
  },

  requestDelete(annotationId) {
    if (!window.confirm("Delete this annotation?")) {
      return
    }

    this.channel
      .push("delete_annotation", {id: annotationId})
      .receive("error", error => console.error("Failed to delete annotation", error))
  },

  toggleMenu(annotationId) {
    const menu = this.el.querySelector(`#annotation-menu-${annotationId}`)
    if (!menu) {
      return
    }

    const isHidden = menu.classList.contains("hidden")
    this.closeAllMenus()

    if (isHidden) {
      menu.classList.remove("hidden")
    }
  },

  closeAllMenus() {
    this.el.querySelectorAll("[id^='annotation-menu-']").forEach(menu => {
      menu.classList.add("hidden")
    })
  },

  buildAnnotationElement(annotation) {
    const wrapper = document.createElement("div")
    wrapper.id = `annotation-${annotation.id}`
    wrapper.className = "annotation rounded-lg border border-base-300 bg-base-200 p-3 shadow-sm"
    wrapper.dataset.id = annotation.id
    wrapper.dataset.at = annotation.at

    const header = document.createElement("div")
    header.className = "flex items-center justify-between gap-2"

    const meta = document.createElement("div")
    meta.className = "flex items-center gap-2"

    const time = document.createElement("span")
    time.className = "rounded bg-base-300 px-2 py-1 text-xs font-mono text-base-content"
    time.textContent = this.formatTime(annotation.at)

    const user = document.createElement("span")
    user.className = "font-semibold text-base-content"
    user.textContent = annotation.user.username

    meta.append(time, user)
    header.appendChild(meta)

    if (annotation.user?.id === this.currentUserId) {
      const actions = document.createElement("div")
      actions.className = "relative"

      const menuToggle = document.createElement("button")
      menuToggle.type = "button"
      menuToggle.className = "btn btn-ghost btn-xs btn-square"
      menuToggle.dataset.menuToggle = "true"
      menuToggle.dataset.id = annotation.id
      menuToggle.setAttribute("aria-label", "Annotation actions")
      menuToggle.textContent = "..."

      const menu = document.createElement("div")
      menu.id = `annotation-menu-${annotation.id}`
      menu.className = "hidden absolute right-0 top-7 z-10 w-28 overflow-hidden rounded-md border border-base-300 bg-base-100 shadow-lg"

      const edit = document.createElement("button")
      edit.type = "button"
      edit.className = "block w-full px-3 py-2 text-left text-sm hover:bg-base-200"
      edit.dataset.action = "edit"
      edit.dataset.id = annotation.id
      edit.textContent = "Edit"

      const del = document.createElement("button")
      del.type = "button"
      del.className = "block w-full px-3 py-2 text-left text-sm text-error hover:bg-base-200"
      del.dataset.action = "delete"
      del.dataset.id = annotation.id
      del.textContent = "Delete"

      menu.append(edit, del)
      actions.append(menuToggle, menu)
      header.appendChild(actions)
    }

    const body = document.createElement("p")
    body.className = "annotation-body mt-1 text-base-content/80"
    body.textContent = annotation.body

    wrapper.append(header, body)
    return wrapper
  },

  formatTime(ms) {
    const totalSeconds = Math.floor(ms / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `${minutes}:${seconds.toString().padStart(2, "0")}`
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {VideoWatch, ThemeSwitch, ...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
