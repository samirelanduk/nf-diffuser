include { CLIP_TOKENIZE } from '../../../modules/local/pydiffuse/clip/tokenize/main'
include { CLIP_EMBED    } from '../../../modules/local/pydiffuse/clip/embed/main'
include { CLIP_ENCODE   } from '../../../modules/local/pydiffuse/clip/encode/main'

workflow ENCODE_PROMPT {

    take:
    ch_prompt // channel: [mandatory] [ val(meta), val(prompt) ]
    tokenizer // channel: [optional]  [ path(tokenizer) ] or []
    model     // channel: [mandatory] [ path(model) ]

    main:
    CLIP_TOKENIZE ( ch_prompt, tokenizer )
    CLIP_EMBED ( CLIP_TOKENIZE.out.tokens, model )
    CLIP_ENCODE ( CLIP_EMBED.out.embedding, model )

    emit:
    conditioning = CLIP_ENCODE.out.conditioning // channel: [ val(meta), path(conditioning) ]
}
