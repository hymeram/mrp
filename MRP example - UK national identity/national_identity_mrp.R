# libraries --------------------------------------------------------------------
library(haven)
library(tidyverse)
library(lme4)
options(scipen = 999)

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
         Country,
         Con19,
         Lab19,
         SNP19,
         PC19,
         Brexit19,
         leaveHanretty,
         c11PopulationDensity,
         c11BornUK,
         c11Retired,
         c11DeprivedNone) %>%
  replace(is.na(.), 0)

# import poststratification frame ----------------------------------------------

# this frame was created by Professor Chris Hanretty and is available to download here: 
# https://journals.sagepub.com/doi/10.1177/1478929919864773#supplementary-materials 

psf_location <- "C:/Users/Alex/Documents/Data/hlv_psw.csv"
psf <- read.csv(psf_location, stringsAsFactors = FALSE)

# clean data to match psf ------------------------------------------------------

bes_clean <- bes %>%
  select(
    britishness,englishness,scottishness,welshness,
    country,gor,pano,pcon,gender,age,p_housing,p_education,p_socgrade) %>%
  na_if(9999) %>%
  mutate_at(vars("britishness","englishness","scottishness","welshness"), replace_na, 1) %>%
  mutate_at(vars("britishness","englishness","scottishness","welshness"), as.numeric) %>%
  as_factor() %>%
  mutate(britishness = britishness-1)


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
      labels=c("16-19","20-24","25-29","30-44","45-59","60-64","65-74","75+"))) %>%
  select(-age,-p_housing,-p_education,-p_socgrade,-englishness,-scottishness,-welshness) 

# merge with aux data 
df <- bes_clean %>%
  merge(aux, by="pano")

# build model ------------------------------------------------------------------

model <-  lme4::lmer(
  'britishness ~ 
  (1|age0) + 
  (1|education) + 
  (1|pcon) + 
  (1|age0:country) + 
  (1|education:country) + 
  sex +
  housing +
  country +
  hrsocgrd +
  Con19 +
  SNP19 + 
  Brexit19 + 
  PC19 +
  leaveHanretty +
  c11BornUK +
  c11DeprivedNone',
  data = df
  )

summary(model)

# model diagnostics -----------------------------------------------------------
plot(model)
ranef(model)
sjPlot::plot_model(model, "re")
sjPlot::plot_model(model, "est")

# poststratification -----------------------------------------------------------

# match psf to model
psf <- psf %>%
  merge(aux, by.x="GSSCode", by.y="ONSConstID") %>%
  rename(c(country = Country, pcon = GSSCode))

# predict onto psf
psf$est <- predict(model, psf, allow.new.levels=T)

# combines estimates by constituency
mrp_estimates <- psf %>%
  group_by(country, pcon) %>%
  summarise(mrp_est = sum(est*weight, na.rm=T)) %>%
  ungroup()

# compare estimates to direct estimates
direct <- df %>%
  group_by(country, ONSConstID) %>%
  summarise(direct_est = mean(britishness, na.rm=T)) 

direct %>%
  merge(.,mrp_estimates, by.x="ONSConstID", by.y="pcon") %>%
  slice_sample(n = 100) %>%
  ggplot(aes(y=forcats::fct_reorder(ONSConstID, mrp_est+direct_est/2))) +
  geom_point(aes(x=direct_est), colour="red") +
  geom_point(aes(x=mrp_est), colour="blue")

# display data ---------------------------------------------------------------

# map estimates

