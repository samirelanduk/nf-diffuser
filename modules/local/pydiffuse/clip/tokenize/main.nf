process CLIP_TOKENIZE {
    tag "$meta.id"
    label "process_single"

    conda "${moduleDir}/environment.yml"
    container "docker.io/samirelanduk/pydiffuse:0.4.0"

    input:
    tuple val(meta), val(prompt)
    path tokenizer

    output:
    tuple val(meta), path("${meta.id}_tokens.json"), emit: tokens
    tuple val(meta), path("${meta.id}_mappings.json"), emit: mappings
    tuple val("${task.process}"), val('python'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('pydiffuse'), eval('python3 -c "import pydiffuse; print(pydiffuse.__version__)"'), topic: versions, emit: versions_pydiffuse

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def tokenizerArg = tokenizer ? "--tokenizer $tokenizer" : ""
    def promptArg = prompt
        .replace('\\', '\\\\')
        .replace('"', '\\"')
        .replace('$', '\\$')
        .replace('`', '\\`')
    """
    pydiffuse clip tokenize \
      "$promptArg" \
      --tokens ${meta.id}_tokens.json \
      --mappings ${meta.id}_mappings.json \
      $tokenizerArg \
      $args
    """
}
