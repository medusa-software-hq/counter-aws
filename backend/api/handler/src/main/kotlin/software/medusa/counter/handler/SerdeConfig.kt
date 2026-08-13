package software.medusa.counter.handler

import io.micronaut.serde.annotation.SerdeImport
import software.medusa.counter.api.models.CountReply
import software.medusa.counter.api.models.Error
import software.medusa.counter.api.models.Unauthorized

// The models are generated (@Introspected) but Micronaut Serde is locked down by default, so each
// externally-defined type is registered here rather than by editing generated code.
@SerdeImport(CountReply::class)
@SerdeImport(Error::class)
@SerdeImport(Unauthorized::class)
class SerdeConfig
