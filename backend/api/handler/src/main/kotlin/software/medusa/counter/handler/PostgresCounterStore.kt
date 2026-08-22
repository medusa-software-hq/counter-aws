package software.medusa.counter.handler

import app.cash.sqldelight.driver.jdbc.asJdbcDriver
import org.postgresql.ds.PGSimpleDataSource
import software.medusa.counter.db.CounterDatabase

private const val counterId = "main"

/**
 * The counter persisted in one Postgres row. The driver is deliberately non-pooling: a fresh
 * connection per query suits serial, infrequent invocations, and avoids handing out one the
 * serverless database already closed after an idle scale-to-zero.
 */
class PostgresCounterStore private constructor(private val database: CounterDatabase) :
    CounterStore {

  override fun current(): Long =
      database.counterQueries.selectValue(id = counterId).executeAsOneOrNull() ?: 0L

  override fun increment(): Long = adjust(1)

  override fun decrement(): Long = adjust(-1)

  private fun adjust(delta: Long): Long =
      database.counterQueries
          .adjustValue(
              id = counterId,
              value_ = delta,
          )
          .executeAsOne()

  companion object {
    /**
     * Builds a store over [jdbcUrl] (a full pgjdbc URL, credentials as query params), applying the
     * schema first. Schema creation is idempotent, so there is no separate migration step.
     */
    fun build(jdbcUrl: String): PostgresCounterStore {
      val driver = PGSimpleDataSource().apply { setUrl(jdbcUrl) }.asJdbcDriver()
      CounterDatabase.Schema.create(driver)
      return PostgresCounterStore(database = CounterDatabase(driver))
    }
  }
}
