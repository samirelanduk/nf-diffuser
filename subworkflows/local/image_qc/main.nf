include { IMAGEQC_STATS                         } from '../../../modules/local/imageqc/stats/main'
include { IMAGEQC_CLIPSCORE                     } from '../../../modules/local/imageqc/clipscore/main'
include { IMAGEQC_CLIPSCORE as IMAGEQC_PICKSCORE } from '../../../modules/local/imageqc/clipscore/main'
include { IMAGEQC_GALLERY                       } from '../../../modules/local/imageqc/gallery/main'

workflow IMAGE_QC {

    take:
    ch_images       // channel: [mandatory] [ val(meta), path(image) ]
    clipscore_model // list:    [optional]  [ path(file), ... ] or []
    pickscore_model // list:    [optional]  [ path(file), ... ] or []

    main:
    IMAGEQC_STATS ( ch_images )
    def ch_multiqc_files = IMAGEQC_STATS.out.stats.map { _meta, tsv -> tsv }

    if (clipscore_model) {
        IMAGEQC_CLIPSCORE ( ch_images, clipscore_model )
        ch_multiqc_files = ch_multiqc_files.mix(IMAGEQC_CLIPSCORE.out.scores.map { _meta, tsv -> tsv })
    }

    if (pickscore_model) {
        IMAGEQC_PICKSCORE ( ch_images, pickscore_model )
        ch_multiqc_files = ch_multiqc_files.mix(IMAGEQC_PICKSCORE.out.scores.map { _meta, tsv -> tsv })
    }

    IMAGEQC_GALLERY (
        ch_images
            .toList()
            .filter { items -> items }
            .map { items ->
                [
                    [id: 'all-images'],
                    items.collect { meta, image -> meta + [image: image.name] },
                    items.collect { _meta, image -> image },
                ]
            }
    )
    ch_multiqc_files = ch_multiqc_files.mix(IMAGEQC_GALLERY.out.html.map { _meta, html -> html })

    emit:
    multiqc_files = ch_multiqc_files // channel: [ path(tsv or html) ]
}
