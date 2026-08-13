package software.medusa.counter.handler

import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Controller
import java.util.concurrent.atomic.AtomicLong
import software.medusa.counter.api.controllers.CounterDecrementController
import software.medusa.counter.api.controllers.CounterGetController
import software.medusa.counter.api.controllers.CounterIncrementController
import software.medusa.counter.api.models.CountReply

// A single shared counter, held in memory. Persistence (Neon Postgres) is a later slice; until then
// the value resets when Lambda recycles the execution environment. The route metadata (paths,
// verbs) is inherited from the generated controller interfaces.
@Controller
open class CounterController :
    CounterGetController, CounterIncrementController, CounterDecrementController {
  private val count = AtomicLong(0)

  override fun getCount(): HttpResponse<CountReply> = HttpResponse.ok(CountReply(count.get()))

  override fun incrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(count.incrementAndGet()))

  override fun decrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(count.decrementAndGet()))
}
