process IMAGEQC_STATS {
    tag "$meta.id"
    label "process_single"

    conda "${moduleDir}/environment.yml"
    container "docker.io/samirelanduk/pydiffuse:0.4.1"

    input:
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("${meta.id}_imageqc_stats.tsv"), emit: stats
    tuple val("${task.process}"), val('python'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('numpy'), eval('python3 -c "import numpy; print(numpy.__version__)"'), topic: versions, emit: versions_numpy
    tuple val("${task.process}"), val('pillow'), eval('python3 -c "import PIL; print(PIL.__version__)"'), topic: versions, emit: versions_pillow

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    """
    imageqc_stats.py \\
      $image \\
      --sample ${meta.id} \\
      --output ${meta.id}_imageqc_stats.tsv \\
      $args
    """
}
