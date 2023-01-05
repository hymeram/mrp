# libraries --------------------------------------------------------------------
library(haven)
library(curl)
library(tidyverse)
library(brms)
library(bayesplot)
library(doParallel)
library(survey)
library(srvyr)
options(scipen = 999)
setwd("voting_intention")

# import british election study data -------------------------------------------

# this is Post-Election British Election Study data available to download here: 
# https://www.britishelectionstudy.com/data-objects/cross-sectional-data/

# 2017 post-election data
location_2017 <- "~/Data/bes_f2f_2017_v1.5.dta"
bes_2017 <- haven::read_dta(location_2017)

bes_2017_clean <- bes_2017 %>%
  select(Constit_Code, Constit_Name, validatedTurnoutBinary, region, y09, Age, education) %>%
  as_factor() %>%
  mutate(
    education = case_when(
      education == "City&Guilds level 1, NVQ/SVQ 1 and equivalent" ~ "Level 1",
      education == "City&Guilds level 2, NVQ/SVQ 2 and equivalent" ~ "Level 2",
      education == "ONC/OND, City&Guilds level 3, NVQ/SVQ 3" ~ "Level 2",
      education == "HNC/HND, City&Guilds level 4, NVQ/SVQ 4/5" ~ "Level 2",
      education == "Clerical and commercial qualifications" ~ "Level 1",
      education == "GCSE A*-C, CSE grade 1, O level grade A-C" ~ "Level 2",
      education == "GCSE D-G, CSE grades 2-5, O level D-E" ~ "Level 1",
      education == "A level or equivalent" ~ "Level 3",
      education == "No qualification" ~ "No qualifications",
      education == "Nursing qualification" ~ "Level 4/5",
      education == "ONC" ~ "Level 2",
      education == "Other technical, professional or higher qualification" ~ "Other",
      education == "Recognised trade apprenticeship" ~ "Level 2",
      education == "Scottish Higher or equivalent" ~ "Level 3",
      education == "Scottish Standard grades, Ordinary bands" ~ "Level 2",
      education == "Teaching qualification" ~ "Level 4/5",
      education == "Univ/poly diploma" ~ "Level 4/5",
      education == "First degree" ~ "Level 4/5",
      education == "Postgraduate degree" ~ "Level 4/5",
      education == "Youth training certificate, skill seekers" ~ "Level 2",
      TRUE ~ NA_character_),
    sex = y09, 
    year = "2017",
    gor = region,
    age0 = cut(
      as.numeric(as.character(Age)), 
      breaks=c(-Inf, 19, 24, 29, 44, 59, 64, 74, Inf), 
      labels=c("16-19","20-24","25-29","30-44","45-59","60-64","65-74","75+"))) %>%
  select(-region)


# 2015 post-election data
location_2015 <- "~/Data/bes_f2f_2015_v4.0.dta"
bes_2015 <- haven::read_dta(location_2015)

bes_2015_clean <- bes_2015 %>%
  select(Constit_Code, Constit_Name, validatedTurnoutBinary, gor, y09, Age, education) %>%
  as_factor() %>%
  mutate(
    education = case_when(
      education == "City&Guilds level 1, NVQ/SVQ 1 and equivalent" ~ "Level 1",
      education == "City&Guilds level 2, NVQ/SVQ 2 and equivalent" ~ "Level 2",
      education == "ONC/OND, City&Guilds level 3, NVQ/SVQ 3" ~ "Level 2",
      education == "HNC/HND, City&Guilds level 4, NVQ/SVQ 4/5" ~ "Level 2",
      education == "Clerical and commercial qualifications" ~ "Level 1",
      education == "GCSE A*-C, CSE grade 1, O level grade A-C" ~ "Level 2",
      education == "GCSE D-G, CSE grades 2-5, O level D-E" ~ "Level 1",
      education == "A level or equivalent" ~ "Level 3",
      education == "No qualification" ~ "No qualifications",
      education == "Nursing qualification" ~ "Level 4/5",
      education == "ONC" ~ "Level 2",
      education == "Other technical, professional or higher qualification" ~ "Other",
      education == "Recognised trade apprenticeship" ~ "Level 2",
      education == "Scottish Higher or equivalent" ~ "Level 3",
      education == "Scottish Standard grades, Ordinary bands" ~ "Level 2",
      education == "Teaching qualification" ~ "Level 4/5",
      education == "Univ/poly diploma" ~ "Level 4/5",
      education == "First degree" ~ "Level 4/5",
      education == "Postgraduate degree" ~ "Level 4/5",
      education == "Youth training certificate, skill seekers" ~ "Level 2",
      TRUE ~ NA_character_),
    sex = y09, 
    year = "2015",
    age0 = cut(
      as.numeric(as.character(Age)), 
      breaks=c(-Inf, 19, 24, 29, 44, 59, 64, 74, Inf), 
      labels=c("16-19","20-24","25-29","30-44","45-59","60-64","65-74","75+")))


# aux data ---------------------------------------------------------------------
# import constituency level predictors from BES
temp <- tempfile()
source <- "https://www.britishelectionstudy.com/wp-content/uploads/2022/01/BES-2019-General-Election-results-file-v1.1.xlsx"
temp <- curl::curl_download(url=source, destfile=temp, quiet=FALSE, mode="wb")
aux <- readxl::read_excel(temp) %>%
  select(
    ConstituencyName,
    ONSConstID,
    c11DeprivedNone,
    Turnout19,
    c11PopulationDensity,
    Region
  ) %>%
  replace(is.na(.), 0) %>%
  mutate_at(c("c11DeprivedNone", "Turnout19", "c11PopulationDensity"), ~(scale(.) %>% as.vector))

# combine
turnout_df <- rbind(bes_2015_clean, bes_2017_clean) %>%
  drop_na() %>%
  mutate(Turnout = as.numeric(validatedTurnoutBinary)-1) %>%
  merge(aux, by.x="Constit_Code", by.y="ONSConstID")

# turnout model ---------------------------------------------------------------

priors <- c(
  prior(normal(0,1), class = b),
  prior(normal(0,5), class = Intercept),
  prior(exponential(0.5), class = sd))

turnout_model <- brm(
  'Turnout ~ 
  (1|Constit_Code) + 
  (1|age0) + 
  (1|age0:year) +
  (1|education) + 
  (1|education:age0) + 
  (1|education:year) + 
  (1|gor:year) +
  (1|gor:education) +
  (1|gor:sex) +
  (1|gor:age0) +
  sex + 
  year +
  c11DeprivedNone +
  Turnout19 +
  c11PopulationDensity',
  family = bernoulli(),
  data = turnout_df,
  prior = priors,
  chains = 2,
  cores = 2,
  threads = threading(2),
  refresh = 1,
  backend = "cmdstanr",
  iter = 1000,
  control = list(adapt_delta = 0.9, max_treedepth = 10)
)

saveRDS(turnout_model, "Models/turnout_model.RDS")

summary(turnout_model)


# poststratify -----------------------------------------------------------------

# this population frame is by Professor Chris Hanretty the original is available here: 
# "https://journals.sagepub.com/doi/suppl/10.1177/1478929919864773/suppl_file/hlv_psw.csv"

turnout_model <- readRDS("Models/turnout_model.RDS")

psf_location <- "~/Data/hlv_psw.csv"
psf <- read.csv(psf_location, stringsAsFactors = FALSE) %>%
  merge(aux, by.x="GSSCode", by.y="ONSConstID") %>%
  rename(gor = Region, Constit_Code = GSSCode) %>%
  mutate(year = "2017")

for (i in unique(psf$gor)){
  print(i)
  psf_area <- psf[psf$gor == i,]
  psf_area$turnout_prob <- predict(
    object = turnout_model,
    newdata = psf_area,
    ndraws = 500,
    cores = 4,
    allow_new_levels = TRUE,
    summary = TRUE,
    robust = FALSE)
  write.csv(psf_area, paste0("~/Data/psf/Turnout/",i,".csv"))
}

#rbind chunks
filenames=list.files(path="~/Data/psf/Turnout/",pattern = ".csv",full.names=TRUE)
combined_pred <- do.call(rbind,lapply(filenames, read.csv))

# see turnout by constituency
constit_pred <- combined_pred %>%
  group_by(Constit_Code,ConstituencyName) %>%
  summarise(turnout_perc = sum(turnout_prob.Estimate * weight))

# save psf 
combined_pred <- combined_pred %>%
  select(Constit_Code, ConstituencyName, sex, age0, housing, hrsocgrd,
         education, weight, turnout_prob.Estimate) %>%
  rename(turnout = turnout_prob.Estimate)

write.csv(combined_pred,"psf_turnout.csv",row.names=F)
  


