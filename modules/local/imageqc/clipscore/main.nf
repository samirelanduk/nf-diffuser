process IMAGEQC_CLIPSCORE {
    tag "$meta.id"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "docker.io/samirelanduk/pydiffuse:0.4.1"

    input:
    tuple val(meta), path(image)
    path(model, stageAs: "model/*")

    output:
    tuple val(meta), path("*.tsv"), emit: scores
    tuple val("${task.process}"), val('python'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('torch'), eval('python3 -c "import torch; print(torch.__version__)"'), topic: versions, emit: versions_torch
    tuple val("${task.process}"), val('transformers'), eval('python3 -c "import transformers; print(transformers.__version__)"'), topic: versions, emit: versions_transformers

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}_clipscore"
    def prompt = "'" + (meta.prompt ?: "").replace("'", "'\\''") + "'"
    def negative_prompt = "'" + (meta.negative_prompt ?: "").replace("'", "'\\''") + "'"
    """
    imageqc_clipscore.py \\
      $image \\
      model \\
      --sample ${meta.id} \\
      --prompt ${prompt} \\
      --negative-prompt ${negative_prompt} \\
      --threads ${task.cpus} \\
      --output ${prefix}.tsv \\
      $args
    """
}
