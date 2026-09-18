process DENOISE {
    tag "$meta.id"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "docker.io/samirelanduk/pydiffuse:0.4.0"

    input:
    tuple val(meta), path(latent), path(positive, stageAs: "positive/*"), path(negative, stageAs: "negative/*"), path(schedule)
    path model

    output:
    tuple val(meta), path("${meta.id}_denoised.pt"), emit: denoised
    tuple val("${task.process}"), val('python'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('pydiffuse'), eval('python3 -c "import pydiffuse; print(pydiffuse.__version__)"'), topic: versions, emit: versions_pydiffuse

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    """
    pydiffuse sample denoise \
      $latent \
      $positive \
      $negative \
      $schedule \
      $model \
      --output ${meta.id}_denoised.pt \
      $args
    """
}
