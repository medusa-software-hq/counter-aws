package software.medusa.counter.handler

import java.util.concurrent.atomic.AtomicLong

/** Stands in for the persistent store, so the handler test needs no database. */
class InMemoryCounterStore : CounterStore {
  private val value = AtomicLong(0)

  override fun current(): Long = value.get()

  override fun increment(): Long = value.incrementAndGet()

  override fun decrement(): Long = value.decrementAndGet()
}
