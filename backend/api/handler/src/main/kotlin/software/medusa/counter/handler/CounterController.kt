package software.medusa.counter.handler

import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Controller
import software.medusa.counter.api.controllers.CounterDecrementController
import software.medusa.counter.api.controllers.CounterGetController
import software.medusa.counter.api.controllers.CounterIncrementController
import software.medusa.counter.api.models.CountReply

// Route metadata (paths, verbs) comes from the generated interfaces; the value lives in the
// injected store.
@Controller
open class CounterController(private val store: CounterStore) :
    CounterGetController, CounterIncrementController, CounterDecrementController {

  override fun getCount(): HttpResponse<CountReply> = HttpResponse.ok(CountReply(store.current()))

  override fun incrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(store.increment()))

  override fun decrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(store.decrement()))
}
