//
// Read and validate the input samplesheet.
//
// Read paths may be absolute, a URL, or relative. A relative path is resolved against the
// directory holding the samplesheet -- not against the launch directory -- so that a
// samplesheet shipped next to its FASTQ files stays valid no matter where the pipeline is
// launched from.
//
def resolve_read(String path, sheet_dir) {
    if (!path) {
        return false
    }
    def is_absolute = path.startsWith('/') || path ==~ /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/.*/
    return is_absolute ? file(path, checkIfExists: true)
                       : file("${sheet_dir}/${path}", checkIfExists: true)
}

workflow INPUT_CHECK {
    take:
    ch_input

    main:
    def sheet_dir = file(params.input).parent

    ch_input_rows = Channel
        .from(ch_input)
        .splitCsv(header: true)
        .map { row ->
                if (row.size() == 3) {
                    def meta = [:]
                    meta.id = row.sample
                    meta.single_end = params.single_end
                    def r1 = resolve_read(row.fastq_1, sheet_dir)
                    def r2 = resolve_read(row.fastq_2, sheet_dir)
                    // Check if given combination is valid
                    if (!r1) exit 1, "Invalid input samplesheet: reads_1 can not be empty."
                    if (!r2 && !params.single_end) exit 1, "Invalid input samplesheet: single-end short reads provided, but command line parameter `--single_end` is false. Note that either only single-end or only paired-end reads must provided."
                    if (r2 && params.single_end) exit 1, "Invalid input samplesheet: paired-end short reads provided, but command line parameter `--single_end` is true. Note that either only single-end or only paired-end reads must provided."
                    if (params.single_end)
                        return [ meta, [ r1 ]]
                    else
                        return [ meta, [ r1, r2 ]]
                } else {
                    exit 1, "Input samplesheet contains row with ${row.size()} column(s). Expects 3."
                }
            }


    // Ensure sample IDs are unique
    ch_input_rows
        .map { id, reads -> id }
        .toList()
        .map { ids -> if( ids.size() != ids.unique().size() ) {exit 1, "ERROR: input samplesheet contains duplicated sample IDs!" } }

    emit:
    reads = ch_input_rows
}
