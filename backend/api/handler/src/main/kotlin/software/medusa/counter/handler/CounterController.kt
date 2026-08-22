package software.medusa.counter.handler

import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Controller
import software.medusa.counter.api.controllers.CounterDecrementController
import software.medusa.counter.api.controllers.CounterGetController
import software.medusa.counter.api.controllers.CounterIncrementController
import software.medusa.counter.api.models.CountReply

/** Serves the counter routes, implementing the interfaces generated from the API contract. */
@Controller
class CounterController(private val store: CounterStore) :
    CounterGetController, CounterIncrementController, CounterDecrementController {

  override fun getCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(count = store.current()))

  override fun incrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(count = store.increment()))

  override fun decrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(count = store.decrement()))
}
