process IMAGEQC_GALLERY {
    tag "$meta.id"
    label "process_single"

    conda "${moduleDir}/environment.yml"
    container "docker.io/samirelanduk/pydiffuse:0.4.1"

    input:
    tuple val(meta), val(samples), path(images, stageAs: "images/*")

    output:
    tuple val(meta), path("${meta.id}.html"), emit: html
    tuple val("${task.process}"), val('python'), eval('python3 --version | cut -d" " -f2'), topic: versions, emit: versions_python
    tuple val("${task.process}"), val('pillow'), eval('python3 -c "import PIL; print(PIL.__version__)"'), topic: versions, emit: versions_pillow

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def samples_json = groovy.json.JsonOutput.toJson(samples.collect { sample -> sample + [image: "images/${sample.image}"] })
    """
    cat <<'END_OF_SAMPLES' > samples.json
    ${samples_json}
    END_OF_SAMPLES

    imageqc_gallery.py \\
      samples.json \\
      --output ${meta.id}.html \\
      $args
    """
}
