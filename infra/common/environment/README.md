# Environment resolution

Resolves one environment from the Terraform workspace, strictly — an unrecognised workspace fails
the plan rather than falling back.

A root with no environment dimension imports the shared declarations instead, so it cannot read
another environment's values by accident.
