process NOISE_SCHEDULE {
    tag "$meta.id"
    label "process_single"

    conda "${moduleDir}/environment.yml"
    container "docker.io/samirelanduk/pydiffuse:0.4.0"

    input:
    tuple val(meta), val(steps)

    output:
    tuple val(meta), path("${meta.id}_schedule.txt"), emit: schedule
    tuple val("${task.process}"), val('python'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('pydiffuse'), eval('python3 -c "import pydiffuse; print(pydiffuse.__version__)"'), topic: versions, emit: versions_pydiffuse

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    """
    pydiffuse noise schedule \
      $steps \
      --output ${meta.id}_schedule.txt \
      $args
    """
}
