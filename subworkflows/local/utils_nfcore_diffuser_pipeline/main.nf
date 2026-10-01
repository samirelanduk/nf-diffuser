//
// Subworkflow with functionality specific to the samirelanduk/nf-diffuser pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { paramsHelp                } from 'plugin/nf-schema'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet
    prompt            //  string: Prompt to use instead of a samplesheet
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //

    def before_text = ""
    def after_text = ""
    if (monochrome_logs) {
        before_text = before_text.replaceAll(/\033\[[0-9;]*m/, '')
    }

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()

    //
    // Create channel from input file provided through params.input, or from params.prompt
    //

    channel
        .fromList(prompt ? promptToSamplesheetList(prompt) : samplesheetToList(input, "${projectDir}/assets/schema_input.json"))
        .map { samplesheet ->
            validateInputSamplesheet(samplesheet)
        }
        .set { ch_samplesheet }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    multiqc_report  //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)

    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs for common issues: https://nf-co.re/docs/running/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Check and validate pipeline parameters
//
def validateInputParameters() {
    if ([params.input, params.prompt].count { it } != 1) {
        error("Provide exactly one of '--input samplesheet.csv' or '--prompt \"Some description\"'.")
    }
    modelExistsError()
    if (!params.model && !getModelAttribute('model')) {
        error("Model weights not specified with e.g. '--model_name SD1.5' or '--model model.safetensors'.")
    }
    if (!params.skip_qc && !params.skip_clipscore && !getQcModelFiles('CLIPScore', params.clipscore_model)) {
        error("CLIPScore model not found. Provide it with '--clipscore_model <directory>', or skip it with '--skip_clipscore'.")
    }
    if (!params.skip_qc && params.run_pickscore && !getQcModelFiles('PickScore', params.pickscore_model)) {
        error("PickScore model not found. Provide it with '--pickscore_model <directory>'.")
    }
}

//
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    return input
}

//
// Create the same structure samplesheetToList returns for a single-row samplesheet
//
def promptToSamplesheetList(prompt) {
    def schema = new groovy.json.JsonSlurper().parse(file("${projectDir}/assets/schema_input.json"))
    def row = [ sample: 'prompt', prompt: prompt ]
    def meta = schema.items.properties.collectEntries { column, property ->
        [ property.meta[0], row.containsKey(column) ? row[column] : property.default ]
    }
    return [ [ meta ] ]
}

//
// Get attribute from model catalogue config file e.g. model
//
def getModelAttribute(attribute) {
    if (params.models && params.model_name && params.models.containsKey(params.model_name)) {
        if (params.models[ params.model_name ].containsKey(attribute)) {
            return params.models[ params.model_name ][ attribute ]
        }
    }
    return null
}

//
// Get the files of an image QC model, from a local directory or the model catalogue
//
def getQcModelFiles(name, directory) {
    if (directory) {
        return file(directory, checkIfExists: true).listFiles().toList()
    }
    return (params.qc_models?.get(name)?.files ?: []).collect { url -> file(url) }
}

//
// Exit pipeline if incorrect --model_name key provided
//
def modelExistsError() {
    if (params.models && params.model_name && !params.models.containsKey(params.model_name)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  Model '${params.model_name}' not found in any config files provided to the pipeline.\n" +
            "  Currently, the available model keys are:\n" +
            "  ${params.models.keySet().join(", ")}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    def citation_text = [
            "Images were generated with latent diffusion (Rombach et al. 2022),",
            "using CLIP text conditioning (Radford et al. 2021),",
            "classifier-free guidance (Ho & Salimans 2022)",
            "and noise schedules and samplers from Karras et al. (2022).",
            params.skip_qc ? "" : "Image quality was assessed with the variance of the Laplacian (Pech-Pacheco et al. 2000), noise estimation (Immerkær 1996) and colourfulness (Hasler & Süsstrunk 2003)" + (params.skip_clipscore ? "." : ", and prompt adherence with CLIPScore (Hessel et al. 2021)."),
            !params.skip_qc && params.run_pickscore ? "Human preference was estimated with PickScore (Kirstain et al. 2023)." : "",
            "Tools used in the workflow included:",
            "pydiffuse,",
            params.skip_qc || (params.skip_clipscore && !params.run_pickscore) ? "" : "Transformers (Wolf et al. 2020),",
            "MultiQC (Ewels et al. 2016)."
        ].findAll { text -> text }.join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    def reference_text = [
            "<li>Rombach, R., Blattmann, A., Lorenz, D., Esser, P., & Ommer, B. (2022). High-resolution image synthesis with latent diffusion models. 2022 IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR), 10674–10685. doi: <a href=\"https://doi.org/10.1109/CVPR52688.2022.01042\">10.1109/CVPR52688.2022.01042</a></li>",
            "<li>Radford, A., Kim, J. W., Hallacy, C., Ramesh, A., Goh, G., Agarwal, S., Sastry, G., Askell, A., Mishkin, P., Clark, J., Krueger, G., & Sutskever, I. (2021). Learning transferable visual models from natural language supervision. Proceedings of the 38th International Conference on Machine Learning, PMLR 139, 8748–8763.</li>",
            "<li>Ho, J., & Salimans, T. (2022). Classifier-free diffusion guidance. arXiv. doi: <a href=\"https://doi.org/10.48550/arXiv.2207.12598\">10.48550/arXiv.2207.12598</a></li>",
            "<li>Karras, T., Aittala, M., Aila, T., & Laine, S. (2022). Elucidating the design space of diffusion-based generative models. Advances in Neural Information Processing Systems, 35, 26565–26577.</li>",
            params.skip_qc ? "" : "<li>Pech-Pacheco, J. L., Cristóbal, G., Chamorro-Martínez, J., & Fernández-Valdivia, J. (2000). Diatom autofocusing in brightfield microscopy: a comparative study. Proceedings 15th International Conference on Pattern Recognition, 3, 314–317. doi: <a href=\"https://doi.org/10.1109/ICPR.2000.903548\">10.1109/ICPR.2000.903548</a></li>",
            params.skip_qc ? "" : "<li>Immerkær, J. (1996). Fast noise variance estimation. Computer Vision and Image Understanding, 64(2), 300–302. doi: <a href=\"https://doi.org/10.1006/cviu.1996.0060\">10.1006/cviu.1996.0060</a></li>",
            params.skip_qc ? "" : "<li>Hasler, D., & Suesstrunk, S. E. (2003). Measuring colorfulness in natural images. Proceedings of SPIE, 5007, 87–95. doi: <a href=\"https://doi.org/10.1117/12.477378\">10.1117/12.477378</a></li>",
            params.skip_qc || params.skip_clipscore ? "" : "<li>Hessel, J., Holtzman, A., Forbes, M., Le Bras, R., & Choi, Y. (2021). CLIPScore: A reference-free evaluation metric for image captioning. Proceedings of the 2021 Conference on Empirical Methods in Natural Language Processing, 7514–7528. doi: <a href=\"https://doi.org/10.18653/v1/2021.emnlp-main.595\">10.18653/v1/2021.emnlp-main.595</a></li>",
            !params.skip_qc && params.run_pickscore ? "<li>Kirstain, Y., Polyak, A., Singer, U., Matiana, S., Penna, J., & Levy, O. (2023). Pick-a-Pic: An open dataset of user preferences for text-to-image generation. Advances in Neural Information Processing Systems, 36. doi: <a href=\"https://doi.org/10.48550/arXiv.2305.01569\">10.48550/arXiv.2305.01569</a></li>" : "",
            params.skip_qc || (params.skip_clipscore && !params.run_pickscore) ? "" : "<li>Wolf, T., et al. (2020). Transformers: State-of-the-art natural language processing. Proceedings of the 2020 Conference on Empirical Methods in Natural Language Processing: System Demonstrations, 38–45. doi: <a href=\"https://doi.org/10.18653/v1/2020.emnlp-demos.6\">10.18653/v1/2020.emnlp-demos.6</a></li>",
            "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics, 32(19), 3047–3048. doi: <a href=\"https://doi.org/10.1093/bioinformatics/btw354\">10.1093/bioinformatics/btw354</a></li>"
        ].findAll { text -> text }.join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    } else meta["doi_text"] = ""
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()

    def methods_text = mqc_methods_yaml.text

    def engine =  new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}
