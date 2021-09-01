
<!-- README.md is generated from README.Rmd. Please edit that file -->

[![minimal R
version](https://img.shields.io/badge/R%3E%3D-4.1.0-brightgreen.svg)](https://cran.r-project.org/)
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

[1. LaTeX and PDF Compile Issues](#1-latex-and-pdf-compile-issues)

[2. Google Tag Pandoc Issues](#2-google-tag-pandoc-issues)

[3. Context 24 Core Template](#3-context-24-core-template)

[4. Didehpc Errors](#4-didehpc-errors)

[5. Reconcile Errors](#5-reconcile-errors)

[6. Mapping Network Drives](#6-mapping-network-drives)

[7. Updating packages in context](#7-updating-packages-in-context)

[8. Peculiar didehpc failed jobs](#8-peculiar-didehpc-failed-jobs)

------------------------------------------------------------------------

#### 1. LaTeX and PDF Compile Issues

PDF compilation was initially tricky with the default setup not having
pandoc on a network share nor being able to correctly compile the PDF
document from orderly runs. As a result, both
[TinyTex](https://yihui.org/tinytex/) and pandoc were installed onto the
network share at `L:/OJ` (pandoc was then copied over to its location on
the network share):

    tinytex::install_tinytex(dir = "L:/OJ/TinyTex")
    installr::install.pandoc()

In the `global-lmic-reports-orderly` `lmic_reports_vaccine` run script,
we then had to specify the following to get Rmd to compile PDF documents
correctly, with much of the guidance for the last 2 lines below coming
from the TinyTex [debugging
guide](https://yihui.org/tinytex/r/#debugging)

    # pandoc linking
    if(file.exists("L:\\OJ\\pandoc")) {
      rmarkdown:::set_pandoc_info("L:\\OJ\\pandoc")
      Sys.setenv(RSTUDIO_PANDOC="L:\\OJ\\pandoc")
      tinytex::use_tinytex("L:\\OJ\\TinyTex")
      tinytex::tlmgr_update()
    }

<br>

#### 2. Google Tag Pandoc Issues

Each page of the compiled website has a header of html with Google
Analytics set up. This was originally included as an html file that was
specified to appear before the body in the compiled html files. On the
previous Azure server this worked fine, however, after switching to the
DIDE cluster, on occasion there would be 404 errors on rendering the
html page due to a network error related to fetching the Analytics code.
As a result, we swapped to including as plain text the html that the
Google Analytics html file was fetching instead. Hopefully, this fixes
this issues but if any jobs fail on rendering the html with similar
errors then check whether this text has changed or is wrong etc.

#### 3. Context 24 Core Template

When we moved from running the `squire` model to the `nimue` model we
ran out of RAM when running the model. 50 draws from the mcmc chain
appears to be fine on the DIDE cluster but only through specifying the
24 Core template in the setup of the didhpc context in the cluster
submit script. If there any errors are returned suggesting the there is
insufficient memory, e.g. “Can’t allocate vector of xB…”, then recommend
either changing the number of trajectories drawn.

#### 4. Didehpc Errors

There are many types of didehpc error that may appear. First steps
should be to head to
<https://mrc-ide.github.io/didehpc/articles/troubleshooting.html> to
read through all the guidance there, which should help identify specific
errors.

#### 5. Reconcile Errors

The troubleshoot guide above contains information on how to reconcile
job statuses, i.e. checking to see if the job status given by
`grp$status()` is correct and matches what is shown at the DIDE cluster
end. However, to see the status of all jobs from the DIDE cluster, the
following will help (and is similar to what is internally run when
reconciling errors using `obj$reconcile(grp$ids)`):

    dat <- obj$client$status_user("*", obj$config$cluster)
    # dat <- dat[which(dat$name %in% grp$ids),] # this shows you all the tasks
    dat <- dat[match(grp$ids, dat$name),] # it uses a match call to get the most recent task running with that id

#### 6. Mapping Network Drives

To run the cluster submit script, two network drives need to be mapped:

-   T: //fi–didef3.dide.ic.ac.uk/tmp
-   L: //fi–didenas5/malaria

If these are not mapped when starting the machine (in particular the tmp
drive is often not mapped), then see
<https://support.microsoft.com/en-us/windows/map-a-network-drive-in-windows-10-29ce55d1-34e3-a7e2-4801-131475f9557d>
for instructions. In overview:

File Explorer &gt; This PC &gt; Map Network Drive (in Tabs) &gt; Map
using mappings in list above

#### 7. Updating packages in context

If you need to update any packages that are in the context, e.g. if you
make changes to `squire` and `nimue` that you pushed to their Github
repositories, then to update these in the context use the following in
the cluster\_submit script:

    obj <- didehpc::queue_didehpc(ctx, config = config, provision = "lazy")

### 8. Peculiar didehpc failed jobs

If there is a string of jobs that fail in a row, i.e. say jobs 80 - 100
all error, and the error is not one that is a clear R error, i.e. the
jobs just seem to stop, this is likely a problem with the specific node
the jobs are being run on. In which case, rerunning them should work.
This error could be due to the node not behaving or because other jobs
being run on that node by other users are maybe taking too much memory
and causing something strange. If it continues to be an issue, work out
the dide\_id of the failed task and ask Wes to see if there is something
strange with that specific node.

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
