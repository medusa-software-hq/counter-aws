package software.medusa.counter.handler

import app.cash.sqldelight.driver.jdbc.asJdbcDriver
import org.postgresql.ds.PGSimpleDataSource
import software.medusa.counter.db.CounterDatabase

private const val counterId = "main"

// The shared counter, persisted in one Postgres row (Neon) through SQLDelight's generated,
// type-safe query layer. The driver is backed by pgjdbc's own non-pooling DataSource: it opens a
// fresh connection per query, which suits serial, infrequent Lambda invocations and avoids handing
// out a connection the serverless database closed after an idle scale-to-zero.
class PostgresCounterStore private constructor(private val database: CounterDatabase) :
    CounterStore {

  override fun current(): Long =
      database.counterQueries.selectValue(counterId).executeAsOneOrNull() ?: 0L

  override fun increment(): Long = adjust(1)

  override fun decrement(): Long = adjust(-1)

  private fun adjust(delta: Long): Long =
      database.counterQueries.adjustValue(counterId, delta).executeAsOne()

  companion object {
    /**
     * Builds a store over [jdbcUrl] (a full pgjdbc URL, credentials as query params), applying the
     * schema first. Schema creation is idempotent, so there is no separate migration step.
     */
    fun build(jdbcUrl: String): PostgresCounterStore {
      val driver = PGSimpleDataSource().apply { setUrl(jdbcUrl) }.asJdbcDriver()
      CounterDatabase.Schema.create(driver)
      return PostgresCounterStore(CounterDatabase(driver))
    }
  }
}
