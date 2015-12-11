library(magrittr)
library(stringr)

stan_dev <- "https://raw.githubusercontent.com/stan-dev/stan/develop/"

# Stan Distributions ------------------------------------------------------

stan_dists_url <- paste0(stan_dev, "src/docs/stan-reference/distributions.tex")

stan_dists <- paste(readLines(stan_dists_url), collapse = "\n")

dist <- stan_dists %>%
  str_extract_all("pitem\\{.*") %>% unlist() %>%
  str_replace("pitem\\{.*?\\}\\{", "") %>%
  str_replace("\\}.*", "") %>%
  str_replace_all("\\\\_", "_")

# Remove beta and gamma (for now), as they're commonly used for parameter
# variables
dist <- dist[!dist %in% c("beta", "gamma")]


# Built-ins ---------------------------------------------------------------

stan_builtins_url <- paste0(stan_dev, "src/docs/stan-reference/functions.tex")

stan_builtins <- paste(readLines(stan_builtins_url), collapse = "\n")

builtins <- stan_builtins %>%
  str_extract_all("fitem\\{.*") %>% unlist() %>%
  str_replace("fitem\\{.*?\\{", "") %>%
  str_replace("\\}.*", "") %>%
  str_replace("operator", "") %>%
  str_replace("^\\\\", "") %>%
  str_replace("^[[:punct:]]", "") %>%
  str_replace_all("\\\\_", "_") %>% unique()


# Other Keywords ----------------------------------------------------------

stan_keywords_url <- paste0(stan_dev, "src/docs/stan-reference/language.tex")

stan_keywords <- paste(readLines(stan_keywords_url), collapse = "")

e1 <- "subsubsection\\{Reserved Words from Stan Language\\}"
e2 <- "subsubsection\\{Reserved Names from Stan Implementation\\}"

stan_keywords <- stan_keywords %>% str_extract(paste0(e1, ".*", e2)) %>%
  str_extract_all("begin\\{quote\\}.*?end\\{quote\\}", simplify = TRUE) %>%
  str_replace_all("\\\\_", "_") %>%
  str_extract_all("(?<=code\\{)([[:alnum:]|\\_])*")

keyword <- stan_keywords[[1]]
storage <- stan_keywords[[2]]
blocks  <- stan_keywords[[3]]

# Remove true/false, as these are 'literals'
keyword <- keyword[!keyword %in% c("true", "false")]


# Modify the template -----------------------------------------------------

format_js <- function (x) {
  start <- "            '"
  end1  <- " '"
  end2  <- " +"
  width <- 80
  len   <- width - nchar(start) - nchar(end1) - nchar(end2)
  lines <- strwrap(paste(x, collapse = " "), len)

  out <- paste0(start, lines, end1,
                brocks::rep_char(times = len - nchar(lines)), end2)
  out[length(out)] <- gsub(" '[[:space:]]*\\+$", "',", out[length(out)])
  return(out)
}

splice <- function(flag, replacement) {
  entry <- grepl(flag, template)

  if(sum(entry) != 1)
    stop("'flag' should occour in template exactly once.")

  n <- (1:length(template))[entry]
  template <<- c(template[1:(n - 1)], replacement,
                 template[(n + 1):length(template)])
}

template <- readLines("highlight-stan.template.js")

flags <- c("<INSERT_KEYWORD>", "<INSERT_DIST>", "<INSERT_STORAGE>",
           "<INSERT_BLOCKS>")

reps  <- list(keyword, dist, storage, blocks)

for (i in 1:length(flags)) {
  splice(flags[i], format_js(reps[[i]]))
}

# Write it out
writeLines(template, "highlight.js/src/languages/stan.js")

# Copy over the example code
dir.create("highlight.js/test/detect/stan")
file.copy("default.txt", "highlight.js/test/detect/stan/default.txt",
          overwrite = TRUE)
