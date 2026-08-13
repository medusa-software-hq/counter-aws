package software.medusa.counter.handler

import io.micronaut.context.annotation.Replaces
import jakarta.inject.Singleton
import java.util.concurrent.atomic.AtomicLong

// Replaces the Postgres-backed store in the handler test so it exercises routing and serialization
// without a database. The factory's store is what runs in the deployed function.
@Singleton
@Replaces(CounterStore::class)
class InMemoryCounterStore : CounterStore {
  private val value = AtomicLong(0)

  override fun current(): Long = value.get()

  override fun increment(): Long = value.incrementAndGet()

  override fun decrement(): Long = value.decrementAndGet()
}
