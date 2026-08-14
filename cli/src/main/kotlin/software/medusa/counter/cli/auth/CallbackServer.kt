package software.medusa.counter.cli.auth

import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.time.Duration
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.TimeUnit

/**
 * A one-shot loopback HTTP server for the OAuth redirect. Binds the fixed local [port] + [path] the
 * Cognito app-client registers as its callback, hands the browser a "you can close this tab" page,
 * and exposes the redirect's query parameters to the waiting login flow. Closing it frees the port.
 */
class CallbackServer(port: Int, private val path: String) : AutoCloseable {
  private val server: HttpServer = HttpServer.create(InetSocketAddress("127.0.0.1", port), 0)
  private val received = SynchronousQueue<Map<String, String>>()

  init {
    server.createContext(path) { exchange ->
      val params = parseQuery(exchange.requestURI.rawQuery)
      val message =
          if (params.containsKey("code"))
              "Signed in. You can close this tab and return to the terminal."
          else "Sign-in failed. You can close this tab and return to the terminal."
      val body =
          "<!doctype html><meta charset=utf-8><title>ms-counter</title><p>$message</p>"
              .toByteArray()
      exchange.responseHeaders.add("Content-Type", "text/html; charset=utf-8")
      exchange.sendResponseHeaders(200, body.size.toLong())
      exchange.responseBody.use { it.write(body) }
      received.put(params)
    }
    server.start()
  }

  /** Blocks until the browser hits [path], or throws [LoginException] once [timeout] elapses. */
  fun awaitCallback(timeout: Duration): Map<String, String> =
      received.poll(timeout.toMillis(), TimeUnit.MILLISECONDS)
          ?: throw LoginException("Timed out waiting for the browser sign-in to complete.")

  override fun close() = server.stop(0)

  private fun parseQuery(rawQuery: String?): Map<String, String> {
    if (rawQuery.isNullOrEmpty()) return emptyMap()
    return rawQuery
        .split("&")
        .mapNotNull { pair ->
          val index = pair.indexOf('=')
          if (index < 0) null
          else decode(pair.substring(0, index)) to decode(pair.substring(index + 1))
        }
        .toMap()
  }

  private fun decode(value: String): String = URLDecoder.decode(value, StandardCharsets.UTF_8)
}
