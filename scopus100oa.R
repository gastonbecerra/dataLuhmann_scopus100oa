#2do: corregir las rutas para distinguir fulltext y data (productos)

library(tidyverse)
library(readxl)

# read from scopusOAMostCited.xlsx -----------------------------

scopus100 <- read_excel("../data/scopusOAMostCited.xlsx")
glimpse(scopus100)

# import data from CrossRef using DOI -----------------------------

# install.packages("rcrossref")git 
# library('rcrossref')
# cr100 <- rcrossref::cr_works(doi = scopus100$DOI)
# saveRDS(cr100, file = "./scopus100_cr.RData")

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
links %>% write.csv("./scopus100_links.csv", row.names = FALSE)

links <- read.csv("./scopus100_links.csv")

# download pdfs
download_error_log <- c()
#2do: que pancho... mas que el error, habia que registrar los uqe sí bajaron
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

links %>% left_join( cr100$data , by = "doi") %>% glimpse()

# list downloaded files in directory "./fulltext/"
library(fs)
downloaded_pdf <- dir_ls("./fulltext/") %>%
        as.character() %>% as_tibble() %>% 
        rename(filename = value) %>%
        mutate(id = str_extract(filename, "[0-9]+")) %>%
        mutate(id = as.numeric(id)) %>% 
        select(id, filename) %>%
        left_join(links, by = "id") %>%
        glimpse()

# read pdfs -----------------------------


# primero tengo que bajar los lenguajes que necesito

table(links$language) 
table(downloaded_pdf$language)

# https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-versions.html
library(tesseract)
tesseract_download("spa")
tesseract_download("fra")
tss.spa <- tesseract("spa")
tss.fra <- tesseract("fra")
tss.eng <- tesseract("eng")


# read pdfs listed in downloaded_pdf
pdf_text <- c()
for (i in 1:nrow(downloaded_pdf)) {
    tryCatch( {
        ocr <- tesseract::ocr(
            downloaded_pdf$filename[i], 
            tss.eng) %>% paste(collapse = " **pagebreak** ")
        pdf_text <<- c(pdf_text, ocr) 
        print(i)
        },
    error = function(e) {
        print(i)
        print(e)
        pdf_text <<- c(pdf_text, NA)
    }
    )
    Sys.sleep(1)
}

downloaded_pdf$text <- pdf_text

sum(is.na(downloaded_pdf$text))

saveRDS(downloaded_pdf, file = "./scopus100_fulltext.RData")

rm(ocr,i,pdf_text)



glimpse(downloaded_pdf)
glimpse(scopus100)

# merge data -----------------------------
scopus100 %>% 
    left_join(
        downloaded_pdf %>% 
        filter(!is.na(text)) %>% 
        filter(intended.application == "similarity-checking") %>%
        rename(DOI=doi)
        , by = "DOI") %>% 
    select(-c("id", "filename", "URL", "content.type", "language")) %>% 
    write.csv("./scopus100_fulltext.csv", row.names = FALSE)


# referencias -----------------------------

# las referencias no parecen estar completas
# vamos a tener que parsearlas con anystyle?
cr100$data$reference[1] %>% glimpse()

