# Shared declarations

Everything this project declares that no environment varies, and the source `config.json` is emitted
from — a deliberately narrow subset, so that what the published artifacts carry stays a decision
rather than an accident.

Terraform reads these declarations directly; only consumers that cannot run Terraform read the
emitted file.
