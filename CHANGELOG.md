# samirelanduk/nf-diffuser: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.0dev - [date]

### `Added`

### `Fixed`

### `Dependencies`

### `Deprecated`

## v1.0.0 - [2026-10-07]

Initial release of samirelanduk/nf-diffuser, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- Text-to-image generation with Stable Diffusion 1.5 ([pydiffuse](https://github.com/samirelanduk/pydiffuse)), from a samplesheet of prompts or a single `--prompt`
- Optional negative prompt, and per-image settings for size, steps, CFG scale, sampler and noise schedule
- Use of a local `.safetensors` checkpoint, or download of one of several popular checkpoints from Hugging Face by name
- Image QC: image statistics, CLIPScore, and optionally PickScore
- MultiQC report with image QC metrics, a thumbnail gallery and software versions
