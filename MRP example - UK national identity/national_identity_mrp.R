# libraries --------------------------------------------------------------------
library(haven)
library(tidyverse)
library(brms)

setwd("MRP example - UK national identity")

# import british election study data -------------------------------------------

# this is Wave 23 of the British Election Study panel available to download here: 
# https://www.britishelectionstudy.com/data-objects/panel-study-data/ 

bes_location <- "C:/Users/Alex/Documents/Data/BES2019_W23_v23.0.dta"
bes <- haven::read_dta(bes_location)

# import constituency level predictors from BES
aux_location <- "C:/Users/Alex/Documents/Data/BES-2019-General-Election-results-file-v1.1.xlsx"
aux <- readxl::read_excel(aux_location) %>%
  select(pano,
         ONSConstID,
         Con19,
         Lab19,
         SNP19,
         PC19,
         UKIP19) %>%
  replace(is.na(.), 0)

# import poststratification frame ----------------------------------------------

# this frame was created by Professor Chris Hanretty and is available to download here: 
# https://journals.sagepub.com/doi/10.1177/1478929919864773#supplementary-materials 

psf_location <- "C:/Users/Alex/Documents/Data/hlv_psw.csv"
psf <- read.csv(psf_location)

# clean data to match psf ------------------------------------------------------

bes_clean <- bes %>%
  select(
    britishness,englishness,scottishness,welshness,
    country,gor,pano,pcon,gender,age,p_housing,p_education,p_socgrade) %>%
  na_if(9999) %>%
  mutate_at(vars("britishness","englishness","scottishness","welshness"), replace_na, 0) %>%
  mutate(
    primary_id = case_when(
      britishness > englishness & britishness > scottishness & britishness > welshness ~ "British",
      englishness > britishness & englishness > scottishness & englishness > welshness ~ "English",
      englishness == britishness & englishness > scottishness & englishness > welshness ~ "British & English equally",
      scottishness > britishness & scottishness > englishness & scottishness > welshness  ~ "Scottish",
      scottishness == britishness & scottishness > englishness & scottishness > welshness ~ "British & Scottish equally",
      welshness > britishness & welshness > englishness & welshness > scottishness  ~ "Welsh",
      welshness == britishness & welshness > englishness & welshness > scottishness ~ "British & Welsh equally",
      TRUE ~ NA_character_)) %>%
  as_factor() %>%
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
      labels=c("16-19","20-24","25-29","30-44","45-59","60-64","65-74","75+"))) %>%
  select(country,gor,pano,pcon,primary_id,housing,sex,hrsocgrd,education,age0)

# merge with aux data 
df <- bes_clean %>%
  drop_na()
  merge(aux, by="pano")

# build model


# model diagnostics

# predict psf categories

# compare estimates to direct estimates

# map estimates

