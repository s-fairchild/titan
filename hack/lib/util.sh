#!/bin/bash
# Utilies to be sourced for use in other scripts

# log()
# log is a wrapper for echo that includes the function name
# Args
# 1) msg - string
# 2) stack_level - int; optional, defaults to calling function
log() {
    local -r msg="${1:-"log message is empty"}"
    local -r stack_level="${2:-1}"
    echo "${FUNCNAME[${stack_level}]}: ${msg}"
}

# abort()
# abort is a wrapper for log that exits with an error code
abort() {
    local -ri origin_stacklevel=2
    log "${1}" "$origin_stacklevel"
    log "Exiting"
    exit 1
}

# yq()
# yq is a portable command-line data file processor (https://github.com/mikefarah/yq/) 
# See https://mikefarah.gitbook.io/yq/ for detailed documentation and examples.
#
# Usage:
  # yq [flags]
  # yq [command]
#
# Examples:
#
# # yq tries to auto-detect the file format based off the extension, and defaults to YAML if it's unknown (or piping through STDIN)
# # Use the '-p/--input-format' flag to specify a format type.
# cat file.xml | yq -p xml
#
# # read the "stuff" node from "myfile.yml"
# yq '.stuff' < myfile.yml
#
# # update myfile.yml in place
# yq -i '.stuff = "foo"' myfile.yml
#
# # print contents of sample.json as idiomatic YAML
# yq -P -oy sample.json
#
#
# Available Commands:
  # completion  Generate the autocompletion script for the specified shell
  # eval        (default) Apply the expression to each document in each yaml file in sequence
  # eval-all    Loads _all_ yaml documents of _all_ yaml files and runs expression once
  # help        Help about any command
#
# Flags:
  # -C, --colors                        force print with colors
      # --csv-auto-parse                parse CSV YAML/JSON values (default true)
      # --csv-separator char            CSV Separator character (default ,)
  # -e, --exit-status                   set exit status if there are no matches or null or false is returned
      # --expression string             forcibly set the expression argument. Useful when yq argument detection thinks your expression is a file.
      # --from-file string              Load expression from specified file.
  # -f, --front-matter string           (extract|process) first input as yaml front-matter. Extract will pull out the yaml content, process will run the expression against the yaml content, leaving the remaining data intact
      # --header-preprocess             Slurp any header comments and separators before processing expression. (default true)
  # -h, --help                          help for yq
  # -I, --indent int                    sets indent level for output (default 2)
  # -i, --inplace                       update the file in place of first file given.
  # -p, --input-format string           [auto|a|yaml|y|json|j|props|p|csv|c|tsv|t|xml|x|base64|uri|toml|lua|l] parse format for input. (default "auto")
      # --lua-globals                   output keys as top-level global variables
      # --lua-prefix string             prefix (default "return ")
      # --lua-suffix string             suffix (default ";\n")
      # --lua-unquoted                  output unquoted string keys (e.g. {foo="bar"})
  # -M, --no-colors                     force print with no colors
  # -N, --no-doc                        Don't print document separators (---)
  # -0, --nul-output                    Use NUL char to separate values. If unwrap scalar is also set, fail if unwrapped scalar contains NUL char.
  # -n, --null-input                    Don't read input, simply evaluate the expression given. Useful for creating docs from scratch.
  # -o, --output-format string          [auto|a|yaml|y|json|j|props|p|csv|c|tsv|t|xml|x|base64|uri|toml|shell|s|lua|l] output format type. (default "auto")
  # -P, --prettyPrint                   pretty print, shorthand for '... style = ""'
      # --properties-array-brackets     use [x] in array paths (e.g. for SpringBoot)
      # --properties-separator string   separator to use between keys and values (default " = ")
  # -s, --split-exp string              print each result (or doc) into a file named (exp). [exp] argument must return a string. You can use $index in the expression as the result counter.
      # --split-exp-file string         Use a file to specify the split-exp expression.
      # --string-interpolation          Toggles strings interpolation of \(exp) (default true)
      # --tsv-auto-parse                parse TSV YAML/JSON values (default true)
  # -r, --unwrapScalar                  unwrap scalar, print the value with no quotes, colors or comments. Defaults to true for yaml (default true)
  # -v, --verbose                       verbose mode
  # -V, --version                       Print version information and quit
      # --xml-attribute-prefix string   prefix for xml attributes (default "+@")
      # --xml-content-name string       name for xml content (if no attribute name is present). (default "+content")
      # --xml-directive-name string     name for xml directives (e.g. <!DOCTYPE thing cat>) (default "+directive")
      # --xml-keep-namespace            enables keeping namespace after parsing attributes (default true)
      # --xml-proc-inst-prefix string   prefix for xml processing instructions (e.g. <?xml version="1"?>) (default "+p_")
      # --xml-raw-token                 enables using RawToken method instead Token. Commonly disables namespace translations. See https://pkg.go.dev/encoding/xml#Decoder.RawToken for details. (default true)
      # --xml-skip-directives           skip over directives (e.g. <!DOCTYPE thing cat>)
      # --xml-skip-proc-inst            skip over process instructions (e.g. <?xml version="1"?>)
      # --xml-strict-mode               enables strict parsing of XML. See https://pkg.go.dev/encoding/xml for more details.
#
# Use "yq [command] --help" for more information about a command.
yq() {
    image="docker.io/mikefarah/yq:latest"

    podman run \
           --rm \
           --name yq \
           -i \
           -v "${PWD}":/workdir:z \
           "$image" \
           "$@"
}
