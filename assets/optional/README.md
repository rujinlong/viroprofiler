# Placeholders for optional RESULTS_TSE inputs

A Nextflow process input has to be satisfied on every invocation, so a tool that a
`--use_*` flag can switch off still needs *something* on its channel. These empty files
fill that slot, and `RESULTS_TSE` omits the corresponding `create_tse.r` argument when it
sees one.

They are separate files, one per slot, rather than a single shared placeholder: Nextflow
stages inputs by file name, and two channels carrying the same file would collide in the
task directory.

Adding an optional input means adding a file here whose name matches the pattern the
process tests for, `no_*`.
