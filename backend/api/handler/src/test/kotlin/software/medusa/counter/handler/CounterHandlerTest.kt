package software.medusa.counter.handler

import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent
import io.micronaut.function.aws.proxy.MockLambdaContext
import io.micronaut.function.aws.proxy.payload2.APIGatewayV2HTTPEventFunction
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class CounterHandlerTest {
  private fun event(method: String, path: String): APIGatewayV2HTTPEvent =
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
    val handler = APIGatewayV2HTTPEventFunction()
    try {
      val ctx = MockLambdaContext()

      val get = handler.handleRequest(event("GET", "/counter/get"), ctx)
      assertEquals(200, get.statusCode)
      assertEquals("""{"count":0}""", get.body)

      val incremented = handler.handleRequest(event("POST", "/counter/increment"), ctx)
      assertEquals(200, incremented.statusCode)
      assertEquals("""{"count":1}""", incremented.body)

      val decremented = handler.handleRequest(event("POST", "/counter/decrement"), ctx)
      assertEquals(200, decremented.statusCode)
      assertEquals("""{"count":0}""", decremented.body)
    } finally {
      handler.applicationContext.close()
    }
  }
}
