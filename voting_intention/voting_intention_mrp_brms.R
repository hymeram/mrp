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
    c11DeprivedNone,
    Electorate19,
    Country,
    Region,
    Con19,
    Lab19,
    LD19,
    Green19,
    SNP19,
    PC19,
    Brexit19,
    Winner19,
    leaveHanretty,
    c11PopulationDensity,
    c11LongTermUnemployed
    ) %>%
  replace(is.na(.), 0)

# get runner up in 2019 election
maxn <- function(n) function(x) order(x, decreasing = TRUE)[n]
party_names <- aux[,8:14]
aux$Second19 <- colnames(party_names)[apply(party_names, 1, maxn(2))]
aux$Second19 <- str_remove_all(aux$Second19, "19")

# clean data to match psf ------------------------------------------------------

bes_clean <- bes %>%
  select(generalElectionVote, gor,pano,pcon,gender,age,p_housing,p_education,p_socgrade,wt) %>%
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
    age0 = cut(as.numeric(as.character(age)), 
               breaks=c(-Inf, 19, 24, 29, 44, 59, 64, 74, Inf), 
               labels=c("16-19","20-24","25-29","30-44","45-59","60-64","65-74","75+")),
    vote_intention = case_when(
      generalElectionVote == "I would/did not vote" ~ NA_character_,
      generalElectionVote == "Conservative" ~ "Conservative",
      generalElectionVote == "Labour" ~ "Labour",
      generalElectionVote == "Liberal Democrat" ~ "Liberal Democrat",
      generalElectionVote == "Scottish National Party (SNP)" ~ "SNP",
      generalElectionVote == "Plaid Cymru" ~ "Plaid Cymru",
      generalElectionVote == "Green Party" ~ "Green Party",
      generalElectionVote == "Don't know" ~ NA_character_,
      generalElectionVote == "Brexit Party/Reform UK" ~ "Reform UK",
      TRUE ~ "Other")
    ) %>%
  select(-age,-p_housing,-p_education,-p_socgrade,-generalElectionVote) 

# merge with aux data 
df <- bes_clean %>%
  merge(aux, by="pano") %>%
  drop_na() %>%
  slice_sample(n=15000)

# voting intention model -------------------------------------------------------

priors <- c(
  prior(normal(0,1), class = b, dpar=muGreenParty),
  prior(normal(0,1), class = b, dpar=muLabour),
  prior(normal(0,1), class = b, dpar=muLiberalDemocrat),
  prior(normal(0,1), class = b, dpar=muOther),
  prior(normal(0,1), class = b, dpar=muSNP),
  prior(normal(0,1), class = b, dpar=muReformUK),
  prior(normal(0,1), class = b, dpar=muPlaidCymru),
  prior(normal(0,5), class = Intercept),
  prior(exponential(0.5), class = sd, dpar = muLabour) ,
  prior(exponential(0.5), class = sd, dpar = muGreenParty) ,
  prior(exponential(0.5), class = sd, dpar = muOther) ,
  prior(exponential(0.5), class = sd, dpar = muSNP) ,
  prior(exponential(0.5), class = sd, dpar = muPlaidCymru) ,
  prior(exponential(0.5), class = sd, dpar = muLiberalDemocrat),
  prior(exponential(0.5), class = sd, dpar = muReformUK)
)

voting_intention_model <- brm(
  'vote_intention ~ 
  (1|ONSConstID) + 
  (1|age0) + 
  (1|education) + 
  (1|hrsocgrd) +
  (1|gor) +
  sex +
  housing +
  c11PopulationDensity +
  c11LongTermUnemployed +
  Lab19 +
  LD19 +
  Green19 +
  SNP19 +
  PC19 +
  Con19 +
  Winner19 + 
  Second19 +
  leaveHanretty',
  family = categorical(),
  data = df,
  prior = priors,
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
#pp_check(voting_intention_model)

# poststratification -----------------------------------------------------------
voting_intention_model <- readRDS("Models/voting_intention_model.RDS")

# import poststratification frame
# this frame is by Professor Chris Hanretty the original is available here: 
# predicted turnout has then been modeled by me using 2015 and 2017 BES data
# "https://journals.sagepub.com/doi/suppl/10.1177/1478929919864773/suppl_file/hlv_psw.csv"

psf_location <- "psf_turnout.csv"
psf <- read.csv(psf_location, stringsAsFactors = FALSE)
psf <- merge(psf, aux, by.x="Constit_Code", by.y="ONSConstID") %>%
  rename(gor = Region)

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
  write.csv(psf_area, paste0("~/Data/psf/Vote intention/",i,".csv"))
}
#rbind chunks
filenames=list.files(path="~/Data/psf/Vote intention/",pattern = ".csv",full.names=TRUE)
combined_pred <- do.call(rbind,lapply(filenames, read.csv))

# summarise
final_pred <- combined_pred %>%
  group_by(Constit_Code, ConstituencyName.x, Winner19) %>%
  summarise(
    Conservative = sum(vote_intention.P.Y...Conservative. * (weight*turnout)),
    Labour = sum(vote_intention.P.Y...Labour. * (weight*turnout)),
    `Liberal Democrat` = sum(vote_intention.P.Y...Liberal.Democrat. * (weight*turnout)),
    `Scottish National Party` = sum(vote_intention.P.Y...SNP. * (weight*turnout)),
    `Plaid Cymru` = sum(vote_intention.P.Y...Plaid.Cymru. * (weight*turnout)),
    Green = sum(vote_intention.P.Y...Green.Party. * (weight*turnout)),
    `Reform UK` = sum(vote_intention.P.Y...Reform.UK. * (weight*turnout)),
    Other = sum(vote_intention.P.Y...Other. * (weight*turnout))
  )

# winner
party_names <- final_pred[,4:10]
final_pred$Winner <- colnames(party_names)[max.col(party_names, ties.method = "first")]

# seat flips
final_pred <- final_pred %>%
  mutate(
    Winner = ifelse(ConstituencyName.x == "Chorley","Speaker",Winner),
    results = case_when(
      Winner == Winner19 ~ paste(Winner19, "Hold"),
      Winner == "Labour" & Winner19 != "Labour" ~ "Labour Gain",
      Winner == "Conservative" & Winner19 != "Conservative" ~ "Conservative Gain",
      Winner == "Liberal Democrat" & Winner19 != "Liberal Democrat" ~ "Liberal Democrat Gain",
      Winner == "Scottish National Party" & Winner19 != "Scottish National Party" ~ "SNP Gain",
      Winner == "Green" & Winner19 != "Green" ~ "Green Gain"
  ))

write.csv(final_pred, "BES_MRP_Voting_Intention.csv")

# n seats
final_pred %>%
  group_by(Winner) %>%
  summarise(Seats = n())

# results
final_pred %>%
  group_by(results) %>%
  summarise(Seats = n())

# vote share results -----------------------------------------------------------

# vote share weighted survey estimate (Fieldwork May 2022)
vote_share <- bes_clean %>%
  as_survey_design(weights = wt)

svymean(~vote_intention, vote_share, na.rm=T) %>%
  as.data.frame() %>%
  filter(mean > 0) %>%
  mutate(low = mean-(1.96*SE),
         upp = mean+(1.96*SE))

# vote share MRP
combined_pred %>%
  mutate(weight_national = (Electorate19*weight)/sum(aux$Electorate19)) %>%
  summarise(
    Conservative = sum(vote_intention.P.Y...Conservative. * weight_national),
    Labour = sum(vote_intention.P.Y...Labour. * weight_national),
    `Liberal Democrat` = sum(vote_intention.P.Y...Liberal.Democrat. * weight_national),
    `Scottish National Party` = sum(vote_intention.P.Y...SNP. * weight_national),
    `Plaid Cymru` = sum(vote_intention.P.Y...Plaid.Cymru. * weight_national),
    `Reform UK` = sum(vote_intention.P.Y...Reform.UK. * weight_national),
    Green = sum(vote_intention.P.Y...Green.Party. * weight_national),
    Other = sum(vote_intention.P.Y...Other. * weight_national)
  )

# vote share MRP with modeled turnout
combined_pred %>%
  mutate(group_pop = (Electorate19*(weight*turnout))) %>%
  summarise(
    Conservative = sum(vote_intention.P.Y...Conservative. * (group_pop/sum(group_pop))),
    Labour = sum(vote_intention.P.Y...Labour. * (group_pop/sum(group_pop))),
    `Liberal Democrat` = sum(vote_intention.P.Y...Liberal.Democrat. * (group_pop/sum(group_pop))),
    `Scottish National Party` = sum(vote_intention.P.Y...SNP. * (group_pop/sum(group_pop))),
    `Plaid Cymru` = sum(vote_intention.P.Y...Plaid.Cymru. * (group_pop/sum(group_pop))),
    `Reform UK` = sum(vote_intention.P.Y...Reform.UK. * (group_pop/sum(group_pop))),
    Green = sum(vote_intention.P.Y...Green.Party. * (group_pop/sum(group_pop))),
    Other = sum(vote_intention.P.Y...Other. * (group_pop/sum(group_pop)))
  )



# visualisation ----------------------------------------------------------------
west_hex_map$GSSCode<- west_hex_map$gss_code
map.data <- merge(west_hex_map, final_pred, by.x="GSSCode", by.y="Constit_Code")

# plot
p1 <- ggplot(data=map.data) +
  geom_sf(aes(fill=results),colour=NA) + 
  theme_void() + 
  labs(title = "MRP Estimates of Constituency Voting Intention",
       subtitle = "British Election Study Wave 23\nFieldwork: May 2022\n") +
  scale_fill_manual(name = "Predicted change from 2019",
    values = c(
    "Conservative Gain" = "dodgerblue3",
    "Conservative Hold" = "deepskyblue",
    "Labour Gain" = "#CC0024",
    "Labour Hold" = "#FF2F54",
    "SNP Gain" = "darkgoldenrod2",
    "Scottish National Party Hold" = "gold",
    "Liberal Democrat Gain" = "#E77301",
    "Liberal Democrat Hold" = "orange",
    "Green Hold" = "darkgreen",
    "Plaid Cymru Hold" = "lightgreen",
    "Speaker Hold" = "grey"
  ))

ggsave("Maps/MPR_result_map.png",p1,dpi=300, height=8, width=8,bg="white")

# results by subgroup ----------------------------------------------------------
education_pred <- combined_pred %>%
  group_by(Constit_Code, ConstituencyName.x, education) %>%
  mutate(weight = weight/sum(weight)) %>%
  summarise(
    Conservative = sum(vote_intention.P.Y...Conservative. * (weight*turnout)),
    Labour = sum(vote_intention.P.Y...Labour. * (weight*turnout)),
    `Liberal Democrat` = sum(vote_intention.P.Y...Liberal.Democrat. * (weight*turnout)),
    `Scottish National Party` = sum(vote_intention.P.Y...SNP. * (weight*turnout)),
    `Plaid Cymru` = sum(vote_intention.P.Y...Plaid.Cymru. * (weight*turnout)),
    Green = sum(vote_intention.P.Y...Green.Party. * (weight*turnout)),
    Other = sum(vote_intention.P.Y...Other. * (weight*turnout))) %>%
  ungroup()

# winner
party_names <- education_pred[,4:9]
education_pred$Winner <- colnames(party_names)[max.col(party_names, ties.method = "first")]

subgroup.map.data <- merge(west_hex_map, education_pred, by.x="GSSCode", by.y="Constit_Code")
subgroup.map.data$education = factor(
  subgroup.map.data$education, 
  levels=c('No qualifications','Level 1','Level 2','Level 3','Level 4/5','Other'))

# plot
p2 <- ggplot(data=subgroup.map.data %>% filter(education != "Other")) +
  geom_sf(aes(fill=Winner),colour=NA) + 
  theme_void() + 
  labs(title = "MRP Estimates of Constituency Voting Intention by Education",
       subtitle = "British Election Study Wave 23\nFieldwork: May 2022\n") +
  facet_wrap(~education) +
  scale_fill_manual(
    name = "Largest Party",
    values = c(
      "Conservative" = "deepskyblue",
      "Labour" = "#FF2F54",
      "Scottish National Party" = "gold",
      "Liberal Democrat" = "orange",
      "Green" = "darkgreen",
      "Plaid Cymru" = "lightgreen",
      "Speaker" = "grey"
    ))

ggsave("Maps/MPR_result_map_by_edu.png",p2,dpi=300, height=8, width=9,bg="white")
