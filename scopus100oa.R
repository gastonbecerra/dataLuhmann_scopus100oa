library(tidyverse)
library(readxl)

# read from scopusOAMostCited.xlsx -----------------------------

scopus100 <- read_excel("../data/scopusOAMostCited.xlsx")
glimpse(scopus100)

# import data from CrossRef using DOI -----------------------------

# install.packages("rcrossref")
# library('rcrossref')
# cr100 <- rcrossref::cr_works(doi = scopus100$DOI)
# saveRDS(cr100, file = "../data/scopus100_cr.RData")

cr100 <- readRDS("../data/scopus100_cr.RData")
glimpse(cr100$data)

# fulltext? -----------------------------

# fulltext está archivado...
# library(fulltext) 
# ft_get(doi = scopus100$DOI[1:5], dir = "../data/scopus100")

# download pdfs -----------------------------

# vamos a hacer una tabla simple con los links para hacerla mas facil
links <- cr100$data %>% select(doi, link, language) %>% 
    unnest(link) %>%
    filter(content.type %in% c("application/pdf","unspecified")) %>%
    mutate(id=1:n()) 
glimpse(links)
links %>% write.csv("../data/scopus100_links.csv", row.names = FALSE)

# download pdfs
download_error_log <- c()
for (i in 1:nrow(links)) {
    tryCatch( {
        download.file(links$URL[i], 
            destfile = file.path("./fulltext/", paste0(links$id[i], ".pdf")), 
            mode = "wb")
            print(i)
            },
        error = function(e) {
            print(i)
            print(e)
            download_error_log <<- c(download_error_log, i)
        }
    )
    Sys.sleep(1)
}
rm(i)

# cuestiones a revisar:
# hay muchas URL que me redirigen a un paywall o html
# hay otras URL que son de un OJS... se tienen que poder tomar directo
# hay otras que son de un repositorio de la universidad... se tienen que poder tomar directo

# read pdfs -----------------------------

library(tesseract)
tesseract_download("spa")
tesseract_download("fra")
tss.spa <- tesseract("spa")
tss.fra <- tesseract("fra")
tss.eng <- tesseract("eng")

# https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html

table(links$language)




# referencias -----------------------------

# las referencias no parecen estar completas
# vamos a tener que parsearlas con anystyle?
cr100$data$reference[1] %>% glimpse()

