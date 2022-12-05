##################### Voting intention MRP #####################################

# libraries --------------------------------------------------------------------
library(haven)
library(sf)
library(curl)
library(tidyverse)
library(brms)
library(bayesplot)
library(doParallel)
library(parlitools)
library(survey)
library(srvyr)
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
  select(generalElectionVote, gor,pano,pcon,gender,age,p_housing,p_education,p_socgrade) %>%
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
      generalElectionVote == "Don't know" ~ "Don't know",
      TRUE ~ "Other")
    ) %>%
  select(-age,-p_housing,-p_education,-p_socgrade,-generalElectionVote) 

# merge with aux data 
df <- bes_clean %>%
  merge(aux, by="pano")

# voting intention model -------------------------------------------------------

# constituency level predictors include the constituency's region, its previous 
# GE results as well as prior turnout and the result of the 2016 referendum

voting_intention_model <- brm(
  'vote_intention ~ 
  (1|pcon) + 
  (1|gor) +
  (1|age0) + 
  (1|education) + 
  (1|age0:education) + 
  (1|hrsocgrd) + 
  sex +
  housing +
  Lab19 +
  LD19 +
  Con19 +
  Green19 +
  SNP19 +
  PC19 +
  Turnout19 +
  leaveHanretty',
  family = categorical(),
  data = df,
  prior = 
    prior(normal(0, 5), class = "b") +
    prior(normal(0,5), class = "Intercept"),
  chains = 2,
  cores = 2,
  threads = threading(2),
  refresh = 1,
  backend = "cmdstanr",
  iter = 700,
  control = list(adapt_delta = 0.9, max_treedepth = 10)
)

saveRDS(voting_intention_model, "Models/voting_intention_model.RDS")

# model diagnostics ------------------------------------------------------------
summary(voting_intention_model)
plot(voting_intention_model)
pp_check(voting_intention_model)

# poststratification -----------------------------------------------------------

#voting_intention_model <- readRDS("Models/voting_intention_model.RDS")

# match psf variables to model for prediction
post_vars <- bes_clean %>%
  select(pano, pcon, gor) %>%
  distinct(.keep_all = TRUE)

psf <- merge(psf, aux, by.x="GSSCode", by.y="ONSConstID") %>%
  merge(post_vars, by = "pano")

# poststratification
# due to RAM limits this has to be done in chunks and then combined
for (i in unique(psf$gor)){
  print(i)
  psf_area <- psf[psf$gor == i,]
  psf_area$vote_intention <- predict(
    object = voting_intention_model,
    newdata = psf_area,
    ndraws = 500,
    cores = 4,
    allow_new_levels = TRUE,
    summary = TRUE,
    robust = TRUE)
  write.csv(psf_area, paste0("Predictions/",i,".csv"))
}
#rbind chunks
filenames=list.files(path="Predictions",pattern = ".csv",full.names=TRUE)
combined_pred <- do.call(rbind,lapply(filenames, read.csv))

# summarise
final_pred <- combined_pred %>%
  group_by(GSSCode, pcon, Winner19) %>%
  summarise(
    Conservative = sum(vote_intention.P.Y...Conservative. * weight),
    Labour = sum(vote_intention.P.Y...Labour. * weight),
    `Liberal Democrat` = sum(vote_intention.P.Y...Liberal.Democrat. * weight),
    `Scottish National Party` = sum(vote_intention.P.Y...SNP. * weight),
    `Plaid Cymru` = sum(vote_intention.P.Y...Plaid.Cymru. * weight),
    Green = sum(vote_intention.P.Y...Green.Party. * weight),
    DK = sum(vote_intention.P.Y...Don.t.know. * weight),
    No_Vote = sum(vote_intention.P.Y...Wouldn.t.vote. * weight),
    Other = sum(vote_intention.P.Y...Other. * weight)
  )

# winner
party_names <- final_pred[,4:9]
final_pred$Winner <- colnames(party_names)[max.col(party_names, ties.method = "first")]

# seat flips
final_pred <- final_pred %>%
  mutate(
    Winner = ifelse(pcon == "Chorley","Speaker",Winner),
    results = case_when(
      Winner == Winner19 ~ paste(Winner19, "Hold"),
      Winner == "Labour" & Winner19 != "Labour" ~ "Labour Gain",
      Winner == "Conservative" & Winner19 != "Conservative" ~ "Conservative Gain",
      Winner == "Liberal Democrat" & Winner19 != "Liberal Democrat" ~ "Liberal Democrat Gain",
      Winner == "Scottish National Party" & Winner19 != "Scottish National Party" ~ "SNP Gain",
      Winner == "Green" & Winner19 != "Green" ~ "Green Gain"
  ))

write.csv(final_pred, "BES_MRP_Voting_Intention.csv")

# results ----------------------------------------------------------------------

# vote share (Fieldwork May 2022)
vote_share <- bes %>%
  select(generalElectionVote,wt) %>%
  as_factor() %>%
  as_survey_design(weights = wt)

svymean(~generalElectionVote, vote_share, na.rm=T) %>%
  as.data.frame() %>%
  filter(mean > 0) %>%
  mutate(low = mean-(1.96*SE),
         upp = mean+(1.96*SE))

# n seats
final_pred %>%
  group_by(Winner) %>%
  summarise(Seats = n())

# results
final_pred %>%
  group_by(results) %>%
  summarise(Seats = n())

# visualisation ----------------------------------------------------------------
west_hex_map$GSSCode<- west_hex_map$gss_code
map.data <- merge(west_hex_map, final_pred, by="GSSCode")

# plot
p1 <- ggplot(data=map.data) +
  geom_sf(aes(fill=results),colour=NA) + 
  theme_void() + 
  labs(title = "MRP Estimates of Constituency Voting Intention",
       subtitle = "British Election Study Wave 23,\nFieldwork: May 2022") +
  scale_fill_manual(name = "Predicted Result",
    values = c(
    "Conservative Gain" = "dodgerblue3",
    "Conservative Hold" = "deepskyblue",
    "Labour Gain" = "firebrick1",
    "Labour Hold" = "coral",
    "SNP Gain" = "darkgoldenrod2",
    "Scottish National Party Hold" = "gold",
    "Liberal Democrat Hold" = "orange",
    "Green Hold" = "darkgreen",
    "Plaid Cymru Hold" = "lightgreen",
    "Speaker Hold" = "grey"
  ))

ggsave("Maps/MPR_result_map.png",p1,dpi=300, height=8, width=8,bg="white")