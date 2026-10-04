# Contributing

Use Python 3.11+, install with `pip install -e .`, and run
`python -m unittest discover -s tests -v`. These tests do not require FEKO.
`python -m feko_mcp.verify_native` requires FEKO and a licence.

Keep machine paths, licences, credentials, vendor docs, private models, and
solver outputs out of commits. Report FEKO/Python/OS versions and a minimal
Lua script for native failures. State which versions you tested; CI alone
does not establish FEKO compatibility.

Keep example assumptions visible and don't present an unverified
reconstruction as a validated antenna design.
