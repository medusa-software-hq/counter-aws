package software.medusa.counter.handler

// The single shared counter. Each operation returns the value after applying it. Increment on a
// never-touched counter yields 1, decrement yields -1 (the store starts conceptually at 0).
interface CounterStore {
  fun current(): Long

  fun increment(): Long

  fun decrement(): Long
}
