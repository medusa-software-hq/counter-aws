package software.medusa.counter.handler

import io.micronaut.serde.annotation.SerdeImport
import software.medusa.counter.api.models.CountReply
import software.medusa.counter.api.models.Error
import software.medusa.counter.api.models.Unauthorized

/**
 * Serde is locked down by default, so each externally-defined model is registered here rather than
 * by editing generated code.
 */
@SerdeImport(CountReply::class)
@SerdeImport(Error::class)
@SerdeImport(Unauthorized::class)
class SerdeConfig
