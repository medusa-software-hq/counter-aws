package software.medusa.counter.server

import com.linecorp.armeria.common.HttpHeaderNames
import com.linecorp.armeria.common.HttpMethod
import com.linecorp.armeria.server.DecoratingHttpServiceFunction
import com.linecorp.armeria.server.Server
import com.linecorp.armeria.server.cors.CorsService
import com.linecorp.armeria.server.grpc.GrpcService
import com.linecorp.armeria.server.healthcheck.HealthCheckService
import io.netty.handler.logging.LogLevel
import io.netty.handler.logging.LoggingHandler

fun buildServer(
    originRegex: String,
    port: Int,
    auth: DecoratingHttpServiceFunction,
    counterStore: CounterStore,
): Server {
  val cors =
      CorsService.builderForOriginRegex(originRegex)
          .apply {
            allowRequestMethods(HttpMethod.POST, HttpMethod.OPTIONS)
            allowRequestHeaders(
                HttpHeaderNames.AUTHORIZATION,
                HttpHeaderNames.CONTENT_TYPE,
                GrpcHeaderNames.X_GRPC_WEB,
                GrpcHeaderNames.X_USER_AGENT,
                GrpcHeaderNames.GRPC_TIMEOUT,
                GrpcHeaderNames.CONNECT_PROTOCOL_VERSION,
                GrpcHeaderNames.CONNECT_TIMEOUT_MS,
            )
            exposeHeaders(
                GrpcHeaderNames.GRPC_STATUS,
                GrpcHeaderNames.GRPC_MESSAGE,
                HttpHeaderNames.CONTENT_TYPE,
            )
          }
          .newDecorator()

  val grpcService =
      GrpcService.builder()
          .apply {
            addService(CounterServiceImpl(counterStore))
            enableUnframedRequests(true)
          }
          .build()

  return Server.builder()
      .apply {
        http(port)

        // TEMPORARY DIAGNOSTIC: dump raw inbound/outbound bytes at the head of every connection so
        // we
        // can see exactly what the Lambda Web Adapter puts on the wire (HTTP version, Upgrade
        // headers, h2 preface). Remove once the LWA serving issue is fixed.
        childChannelPipelineCustomizer {
          it.addFirst("wiredump", LoggingHandler("WIREDUMP", LogLevel.INFO))
        }

        // Health check is unauthenticated (used by platform health probes).
        service("/health", HealthCheckService.of())

        serviceUnder("/", grpcService.decorate(auth).decorate(cors))
      }
      .build()
}
