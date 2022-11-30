##################### Voting intention MRP #####################################

# libraries --------------------------------------------------------------------
library(haven)
library(sf)
library(curl)
library(tidyverse)
library(brms)
library(bayesplot)
library(doParallel)
options(scipen = 999)
setwd("voting_intention")

# import british election study data -------------------------------------------

# this is Wave 23 of the British Election Study panel available to download here: 
# https://www.britishelectionstudy.com/data-objects/panel-study-data/ 

bes_location <- "~/Data/BES2019_W23_v23.0.dta"
bes <- haven::read_dta(bes_location)

# import constituency level predictors from BES
temp <- tempfile()
source <- "https://www.britishelectionstudy.com/wp-content/uploads/2022/01/BES-2019-General-Election-results-file-v1.1.xlsx"
temp <- curl::curl_download(url=source, destfile=temp, quiet=FALSE, mode="wb")
aux <- readxl::read_excel(temp) %>%
  select(
    ConstituencyName,
    pano,
    ONSConstID,
    Country,
    Region,
    Winner19,
    Con19,
    Lab19,
    LD19,
    Green19,
    SNP19,
    PC19,
    leaveHanretty,
    Turnout19) %>%
  replace(is.na(.), 0)

# import poststratification frame ----------------------------------------------

# this frame was created by Professor Chris Hanretty and is available to download here: 
# "https://journals.sagepub.com/doi/suppl/10.1177/1478929919864773/suppl_file/hlv_psw.csv"

psf_location <- "~/Data/hlv_psw.csv"
psf <- read.csv(psf_location, stringsAsFactors = FALSE)

# clean data to match psf ------------------------------------------------------

bes_clean <- bes %>%
  select(turnoutUKGeneral, generalElectionVote, gor,pano,pcon,gender,age,p_housing,p_education,p_socgrade) %>%
  mutate(turnoutUKGeneral = as.integer(turnoutUKGeneral)) %>%
  na_if(9999) %>%
  as_factor()

bes_clean <- bes_clean %>%
  mutate(
    housing = ifelse(p_housing == "Own â€“ outright" | p_housing == "Own â€“ with a mortgage", "Owns", "Rents"),
    sex = gender,
    hrsocgrd = case_when(
      p_socgrade == "A" | p_socgrade == "B" ~ "AB",
      p_socgrade == "C1" ~ "C1",
      p_socgrade == "C2" ~ "C2",
      p_socgrade == "D" | p_socgrade == "E" ~ "DE",
      TRUE ~ NA_character_),
    education = case_when(
      p_education == "City & Guilds certificate" ~ "Level 1",
      p_education == "City & Guilds certificate - advanced" ~ "Level 2",
      p_education == "Clerical and commercial" ~ "Level 1",
      p_education == "CSE grade 1, GCE O level, GCSE, School Certificate" ~ "Level 2",
      p_education == "CSE grades 2-5" ~ "Level 1",
      p_education == "GCE A level or Higher Certificate" ~ "Level 3",
      p_education == "No formal qualifications" ~ "No qualifications",
      p_education == "Nursing qualification (e.g. SEN, SRN, SCM, RGN)" ~ "Level 4/5",
      p_education == "ONC" ~ "Level 2",
      p_education == "Other technical, professional or higher qualification" ~ "Other",
      p_education == "Recognised trade apprenticeship completed" ~ "Level 2",
      p_education == "Scottish Higher Certificate" ~ "Level 3",
      p_education == "Scottish Ordinary/ Lower Certificate" ~ "Level 2",
      p_education == "Teaching qualification (not degree)" ~ "Level 4/5",
      p_education == "University diploma" ~ "Level 4/5",
      p_education == "University or CNAA first degree (e.g. BA, B.Sc, B.Ed)" ~ "Level 4/5",
      p_education == "University or CNAA higher degree (e.g. M.Sc, Ph.D)" ~ "Level 4/5",
      p_education == "Youth training certificate/skillseekers" ~ "Level 2",
      TRUE ~ NA_character_),
    age0 = cut(as.numeric(age), 
               breaks=c(-Inf, 19, 24, 29, 44, 59, 64, 74, Inf), 
               labels=c("16-19","20-24","25-29","30-44","45-59","60-64","65-74","75+")),
    vote_intention = case_when(
      generalElectionVote == "I would/did not vote" ~ "Wouldn't vote",
      generalElectionVote == "Conservative" ~ "Conservative",
      generalElectionVote == "Labour" ~ "Labour",
      generalElectionVote == "Liberal Democrat" ~ "Liberal Democrat",
      generalElectionVote == "Scottish National Party (SNP)" ~ "SNP",
      generalElectionVote == "Plaid Cymru" ~ "Plaid Cymru",
      generalElectionVote == "Green Party" ~ "Green Party",
      generalElectionVote == "Don't know" ~ NA_character_, # remove don't know
      TRUE ~ "Other")
    ) %>%
  select(-age,-p_housing,-p_education,-p_socgrade,-generalElectionVote) 

# merge with aux data 
df <- bes_clean %>%
  merge(aux, by="pano")

# build models -----------------------------------------------------------------
options(mc.cores = 4)

# Like Starmer
voting_intention_model <- brm(
  'vote_intention ~ 
  (1|pcon) + 
  (1|gor) +
  (1|age0) + 
  (1|education) + 
  (1|hrsocgrd) + 
  sex +
  housing +
  Lab19 + 
  LD19 +
  Con19 +
  Green19 +
  SNP19 +
  PC19 +
  leaveHanretty',
  family = categorical(),
  data = df,
  chains = 2,
  refresh = 1,
  iter = 500,
)
summary(voting_intention_model)

# poststratification -----------------------------------------------------------

# poststratification function
postsratify <- function(i, psf, starmer_model, labour_model){
  aoi <- levels(as.factor(psf$pcon))[i]
  psf_area <- psf[psf$pcon == aoi, ]
  # get like starmer prediction
  posterior_prob_starmer <- posterior_epred(
    starmer_model,
    draws = 500,
    newdata = as.data.frame(psf_area))
  poststrat_prob_starmer <- posterior_prob_starmer %*% psf_area$weight
  # get like labour prediction
  posterior_prob_labour <- posterior_epred(
    labour_model,
    draws = 500,
    newdata = as.data.frame(psf_area))
  poststrat_prob_labour <- posterior_prob_labour %*% psf_area$weight
  # starmer_v_labour
  poststrat_prob_net <- poststrat_prob_starmer - poststrat_prob_labour
  return(data.frame(
    aoi, 
    mean(poststrat_prob_starmer), 
    sd(poststrat_prob_starmer),
    mean(poststrat_prob_labour),
    sd(poststrat_prob_labour),
    mean(poststrat_prob_net),
    sd(poststrat_prob_net),
    ))
}

# match psf to model
psf <- psf %>%
  merge(aux, by.x="GSSCode", by.y="ONSConstID") %>%
  rename(c(country = Country, pcon = GSSCode, gor = Region))

# run poststratification function using multi core 
doParallel::registerDoParallel(cores = 4)
results <- foreach::foreach(
  i = 1:length(levels(as.factor(psf$area))), 
  .combine=rbind,
  .inorder = FALSE,
  .packages = c("rstanarm", "dplyr")) %dopar%
  postsratify(i, psf, starmer_model, labour_model)

# rename cols
colnames(results) <- c(
  "area", 
  "starmer_estimate", 
  "starmer_SD",
  "labour_estimate",
  "labour_SD",
  "net_estimate",
  "net_SD"
  )