package software.medusa.counter.handler

import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent
import io.micronaut.context.ApplicationContext
import io.micronaut.function.aws.proxy.MockLambdaContext
import io.micronaut.function.aws.proxy.payload2.APIGatewayV2HTTPEventFunction
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class CounterHandlerTest {
  private fun event(
      method: String,
      path: String,
  ): APIGatewayV2HTTPEvent =
      APIGatewayV2HTTPEvent.builder()
          .withRawPath(path)
          .withRequestContext(
              APIGatewayV2HTTPEvent.RequestContext.builder()
                  .withHttp(
                      APIGatewayV2HTTPEvent.RequestContext.Http.builder()
                          .withMethod(method)
                          .withPath(path)
                          .build()
                  )
                  .build()
          )
          .build()

  @Test
  fun `get, increment and decrement round-trip through the payload-v2 handler`() {
    // Built the way the runtime builds it. Nothing registers a store, so a discovered controller
    // could not be constructed — a passing round-trip can only be reaching the instance built here.
    val context =
        ApplicationContext.builder()
            .singletons(CounterController(InMemoryCounterStore()))
            .eagerInitSingletons(true)
            .start()
    val handler = APIGatewayV2HTTPEventFunction(context)
    try {
      val ctx = MockLambdaContext()

      val get =
          handler.handleRequest(
              event(
                  method = "GET",
                  path = "/counter/get",
              ),
              ctx,
          )
      assertEquals(
          200,
          get.statusCode,
      )
      assertEquals(
          """{"count":0}""",
          get.body,
      )

      val incremented =
          handler.handleRequest(
              event(
                  method = "POST",
                  path = "/counter/increment",
              ),
              ctx,
          )
      assertEquals(
          200,
          incremented.statusCode,
      )
      assertEquals(
          """{"count":1}""",
          incremented.body,
      )

      val decremented =
          handler.handleRequest(
              event(
                  method = "POST",
                  path = "/counter/decrement",
              ),
              ctx,
          )
      assertEquals(
          200,
          decremented.statusCode,
      )
      assertEquals(
          """{"count":0}""",
          decremented.body,
      )
    } finally {
      context.close()
    }
  }
}
