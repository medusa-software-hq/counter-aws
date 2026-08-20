package software.medusa.counter.handler

/** Stores a single, global counter. */
interface CounterStore {
  /** @return The current value of the counter (initially: 0). */
  fun current(): Long

  /**
   * Increments the counter.
   *
   * @return The incremented value.
   */
  fun increment(): Long

  /**
   * Decrements the counter.
   *
   * @return The decremented value.
   */
  fun decrement(): Long
}
