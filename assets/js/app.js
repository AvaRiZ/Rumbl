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
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/rumbl"
import topbar from "../vendor/topbar"

const VideoWatch = {
  mounted() {
    const token = this.el.dataset.userToken
    const videoId = this.el.dataset.id

    if (!token || !videoId) {
      return
    }

    this.videoSocket = new Socket("/socket", {params: {token}})
    this.videoSocket.connect()

    this.channel = this.videoSocket.channel(`video:${videoId}`, {})
    this.channel.on("new_annotation", annotation => this.renderAnnotation(annotation))
    this.channel
      .join()
      .receive("error", reason => console.error("Video channel join failed", reason))

    this.form = this.el.querySelector("#annotation-form")
    if (this.form) {
      this.handleSubmit = event => {
        event.preventDefault()

        const bodyEl = this.el.querySelector("#annotation-body")
        const atEl = this.el.querySelector("#annotation-at")
        const body = (bodyEl?.value || "").trim()
        const at = parseInt(atEl?.value || "0", 10) || 0

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
  },

  destroyed() {
    if (this.form && this.handleSubmit) {
      this.form.removeEventListener("submit", this.handleSubmit)
    }

    if (this.channel) {
      this.channel.leave()
    }

    if (this.videoSocket) {
      this.videoSocket.disconnect()
    }
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

    const wrapper = document.createElement("div")
    wrapper.className = "annotation p-3 bg-gray-50 rounded-lg"
    wrapper.dataset.at = annotation.at

    const meta = document.createElement("div")
    meta.className = "flex items-center gap-2"

    const time = document.createElement("span")
    time.className = "text-xs font-mono text-brand bg-brand/10 px-2 py-1 rounded"
    time.textContent = this.formatTime(annotation.at)

    const user = document.createElement("span")
    user.className = "font-semibold text-gray-800"
    user.textContent = annotation.user.username

    const body = document.createElement("p")
    body.className = "mt-1 text-gray-600"
    body.textContent = annotation.body

    meta.append(time, user)
    wrapper.append(meta, body)
    container.appendChild(wrapper)
    wrapper.scrollIntoView({behavior: "smooth", block: "nearest"})
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
  hooks: {VideoWatch, ...colocatedHooks},
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
