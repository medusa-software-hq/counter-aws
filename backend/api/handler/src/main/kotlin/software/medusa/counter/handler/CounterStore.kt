package software.medusa.counter.handler

/**
 * The single shared counter. Each operation returns the value after applying it; a never-touched
 * counter behaves as though it started at 0.
 */
interface CounterStore {
  fun current(): Long

  fun increment(): Long

  fun decrement(): Long
}
