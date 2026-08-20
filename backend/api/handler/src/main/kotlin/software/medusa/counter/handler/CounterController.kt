package software.medusa.counter.handler

import io.micronaut.http.HttpResponse
import io.micronaut.http.annotation.Controller
import software.medusa.counter.api.controllers.CounterDecrementController
import software.medusa.counter.api.controllers.CounterGetController
import software.medusa.counter.api.controllers.CounterIncrementController
import software.medusa.counter.api.models.CountReply

/** The HTTP mapping comes from the generated controller interfaces, not from annotations here. */
@Controller
open class CounterController(private val store: CounterStore) :
    CounterGetController, CounterIncrementController, CounterDecrementController {

  override fun getCount(): HttpResponse<CountReply> = HttpResponse.ok(CountReply(store.current()))

  override fun incrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(store.increment()))

  override fun decrementCount(): HttpResponse<CountReply> =
      HttpResponse.ok(CountReply(store.decrement()))
}
