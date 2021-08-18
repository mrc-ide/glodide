
<!-- README.md is generated from README.Rmd. Please edit that file -->

[![minimal R
version](https://img.shields.io/badge/R%3E%3D-4.0.2-brightgreen.svg)](https://cran.r-project.org/)
[![Licence](https://img.shields.io/github/license/mashape/apistatus.svg)](http://choosealicense.com/licenses/mit/)
[![Travis-CI Build
Status](https://travis-ci.org/mrc-ide/glodide.png?branch=master)](https://travis-ci.org/mrc-ide/glodide)

## Submission of Global Lmic Reports via Orderly To DIDE

This is a working R package for submitting global fits to DIDE cluster.

## Installation

    git clone https://github.com/mrc-ide/glodide.git
    cd glodide
    open glodide.Rproj
    devtools::install_deps()

## Overview

The structure within analysis is as follows:

    analysis/
        |
        ├── 01_submission /       # submission scripts 
        |
        ├── data/
        │   ├── DO-NOT-EDIT-ANY-FILES-IN-HERE-BY-HAND
        │   ├── raw_data/       # orderly bundles provided from bundling in global-lmic-reports-orderly
        │   └── derived_data/   # orderly outputs produced from running reports in raw_data

## Process for submitting Jobs

This repository is used for submitting orderly reports to the DIDE
cluster. Outline of steps:

> Run in `global-lmic-reports-orderly`

1.  Execute bundle script in `global-lmic-reports-orderly` repository to
    produce orderly bundles in `analysis/data/raw_data` in `glodide`

> Run in `glodide`

2.  Submit bundles to the DIDE HPC cluster using
    `analysis/01_submission.R` that uses \`d

> Run in `global-lmic-reports-orderly`

3.  Check fits are correct using code in `global-lmic-reports-orderly`
    and resubmit any countries that need to be rerun/run for longer
4.  Pull correctly run orderly bundles from `analysis/data/derived_data`
    into `global-lmic-reports-orderly`
5.  Compile `gh-pages` and push to `mrc-ide/global-lmic-reports`

------------------------------------------------------------------------

The rationale for separating these steps between the two repositories is
to ensure that the `global-lmic-reports-orderly` location is not on the
network share, which has file backups set that can cause issues with
file locking etc related to the orderly database. In addition, the use
of `didehpc` (currently) requires the working directory when submitting
jobs to be on the network share and so this separation currently seems
the best approach.

## Troubleshooting

[1. LaTeX and PDF Compile Issues?](#latex-and-pdf-compile-issues)

------------------------------------------------------------------------

#### 1. LaTeX and PDF Compile Issues?

PDF compilation was initially tricky with the default setup not having
pandoc on a network share nor being able to correctly compile the PDF
document from orderly runs. As a result, both
[TinyTex](https://yihui.org/tinytex/) and pandoc were installed onto the
network share at `L:/OJ` (pandoc was then copied over to its location on
the netwosk share):

    tinytex::install_tinytex(dir = "L:/OJ/TinyTex")
    installr::install.pandoc()

In the `global-lmic-reports-orderly` `lmic_reports_vaccine` run script,
we then had to specify the following to get Rmd to compile PDF documents
correctly.

    # pandoc linking
    if (file.exists("L:\\OJ\\pandoc")) {
      rmarkdown:::set_pandoc_info("L:\\OJ\\pandoc")
      Sys.setenv(RSTUDIO_PANDOC="L:\\OJ\\pandoc")
      tinytex::use_tinytex("L:\\OJ\\TinyTex")
    }

<br>

------------------------------------------------------------------------

## The R package

This repository is organized as an R package. There are a few R
functions exported in this package - the majority of the R code is in
the analysis directory. The R package structure is here to help manage
dependencies, to take advantage of continuous integration, and so we can
keep file and data management simple.

To download the package source as you see it on GitHub, for offline
browsing, use this line at the shell prompt (assuming you have Git
installed on your computer):

``` r
git clone https://github.com/mrc-ide/glodide.git
```

Once the download is complete, open the `glodide.Rproj` in RStudio to
begin working with the package and compendium files. We will endeavor to
keep all package dependencies required listed in the DESCRIPTION. This
has the advantage of allowing `devtools::install_dev_deps()` to install
the required R packages needed to run the code in this repository

## Licenses

Code: [MIT](http://opensource.org/licenses/MIT) year: 2021, copyright
holder: OJ Watson

Data: [CC-0](http://creativecommons.org/publicdomain/zero/1.0/)
attribution requested in reuse
